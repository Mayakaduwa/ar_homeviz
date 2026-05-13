import 'dart:typed_data';
import 'dart:isolate';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

/// Runs in a separate isolate to avoid blocking the UI thread.
Future<Float32List?> _runInferenceIsolate(Map<String, dynamic> args) async {
  final Uint8List imageBytes = args['imageBytes'];
  final int inputSize = args['inputSize'];

  try {
    img.Image? image = img.decodeImage(imageBytes);
    if (image == null) return null;

    img.Image resized = img.copyResize(image,
        width: inputSize, height: inputSize,
        interpolation: img.Interpolation.linear);

    final input = Float32List(1 * inputSize * inputSize * 3);
    int idx = 0;
    for (int y = 0; y < inputSize; y++) {
      for (int x = 0; x < inputSize; x++) {
        final pixel = resized.getPixel(x, y);
        input[idx++] = pixel.r / 255.0;
        input[idx++] = pixel.g / 255.0;
        input[idx++] = pixel.b / 255.0;
      }
    }
    return input;
  } catch (e) {
    return null;
  }
}

class MLService {
  Interpreter? _interpreter;
  bool _isModelLoaded = false;
  int _inputSize = 257;
  int _numClasses = 21; // DeepLabV3 PASCAL VOC has 21 classes

  // 'wall' is class 9 in PASCAL VOC (indoor scenes)
  // For general scenes we treat 'background' class as the wall-ish region
  static const String modelPath = 'assets/models/deeplabv3.tflite';

  bool get isModelLoaded => _isModelLoaded;

  Future<void> loadModel() async {
    try {
      final options = InterpreterOptions()..threads = 2;
      _interpreter = await Interpreter.fromAsset(modelPath, options: options);

      // Read actual input/output shapes from the model
      final inputShape = _interpreter!.getInputTensor(0).shape;
      final outputShape = _interpreter!.getOutputTensor(0).shape;

      // inputShape: [1, H, W, 3]
      _inputSize = inputShape[1];
      // outputShape: [1, H, W, numClasses]
      _numClasses = outputShape[3];

      _isModelLoaded = true;
      print('✅ ML Model loaded. Input: $inputShape  Output: $outputShape  InputSize: $_inputSize  Classes: $_numClasses');
    } catch (e) {
      _isModelLoaded = false;
      print('❌ Failed to load ML model: $e');
    }
  }

  /// Returns a flat mask [inputSize * inputSize]:
  ///   1 = detected non-person region (wall/background), 0 = person/object
  Future<Uint8List?> segmentWall(Uint8List imageBytes) async {
    if (!_isModelLoaded || _interpreter == null) {
      print('⚠️ Model not loaded — using full-screen color fallback.');
      return null;
    }

    try {
      // Pre-process image in isolate to avoid blocking UI
      final preprocessed = await compute(_runInferenceIsolate, {
        'imageBytes': imageBytes,
        'inputSize': _inputSize,
      });
      if (preprocessed == null) return null;

      // Reshape to [1, H, W, 3]
      final inputTensor =
          preprocessed.reshape([1, _inputSize, _inputSize, 3]);

      // Output: [1, H, W, numClasses]
      final outputTensor = List.generate(
        1,
        (_) => List.generate(
          _inputSize,
          (_) => List.generate(
            _inputSize,
            (_) => List.filled(_numClasses, 0.0),
          ),
        ),
      );

      _interpreter!.run(inputTensor, outputTensor);

      // Post-process: argmax over classes
      // In PASCAL VOC: 0=background, 9=chair, 11=diningtable, 15=person, 18=sofa, 20=tvmonitor
      // We want ONLY the background (0) but we MUST ensure we don't paint over objects.
      final mask = Uint8List(_inputSize * _inputSize);
      for (int y = 0; y < _inputSize; y++) {
        for (int x = 0; x < _inputSize; x++) {
          final scores = outputTensor[0][y][x] as List;
          int maxClass = 0;
          double maxScore = scores[0] as double;
          
          for (int c = 1; c < _numClasses; c++) {
            final s = scores[c] as double;
            if (s > maxScore) {
              maxScore = s;
              maxClass = c;
            }
          }

          // IMPROVEMENT: Strictly exclude common indoor objects
          // If the model thinks it's a chair (9), table (11), person (15), sofa (18), or TV (20),
          // we force the mask to 0 (don't paint).
          const ignoredClasses = {9, 11, 15, 18, 20};
          if (ignoredClasses.contains(maxClass)) {
            mask[y * _inputSize + x] = 0;
          } else {
            // Otherwise, if it's background (0), it's likely our wall.
            mask[y * _inputSize + x] = (maxClass == 0) ? 1 : 0;
          }
        }
      }

      print('✅ Segmentation complete. Mask size: ${_inputSize}x${_inputSize}');
      return mask;
    } catch (e) {
      print('❌ ML inference error: $e');
      return null;
    }
  }

  int get maskSize => _inputSize;

  void dispose() {
    _interpreter?.close();
    _isModelLoaded = false;
  }
}
