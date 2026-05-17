import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'dart:convert';

enum SegmentationTarget { wall, floor }

// ─────────────────────────────────────────────────────────────────────────────
// Isolate worker — colour-based wall segmentation
// ─────────────────────────────────────────────────────────────────────────────

Map<String, dynamic> _colorSegmentIsolate(Map<String, dynamic> args) {
  final Uint8List imageBytes = args['imageBytes'];
  final int maskSize = args['maskSize'];
  final bool isFloor = args['isFloor'] ?? false;

  final img.Image? decoded = img.decodeImage(imageBytes);
  if (decoded == null) return {'segments': null, 'coverage': 0.0, 'wallPixels': 0};

  final img.Image small = img.copyResize(
    decoded,
    width: maskSize,
    height: maskSize,
    interpolation: img.Interpolation.linear,
  );

  final int w = small.width;
  final int h = small.height;

  final List<_LabColor> samples = [];

  void sampleZone(int x0, int x1, int y0, int y1) {
    for (int y = y0; y < y1; y++) {
      for (int x = x0; x < x1; x++) {
        final p = small.getPixel(x, y);
        samples.add(_rgbToLab(p.r.toInt(), p.g.toInt(), p.b.toInt()));
      }
    }
  }

  if (isFloor) {
    sampleZone((w * 0.4).toInt(), (w * 0.6).toInt(), (h * 0.8).toInt(), h);
  } else {
    final int sampleH = (h * 0.20).toInt().clamp(4, h);
    sampleZone(0, (w * 0.12).toInt().clamp(2, w), 0, sampleH);               
    sampleZone((w * 0.35).toInt(), (w * 0.65).toInt(), 0, sampleH);          
    sampleZone((w * 0.88).toInt().clamp(0, w - 2), w, 0, sampleH);          
  }

  if (samples.isEmpty) return {'segments': null, 'coverage': 0.0, 'wallPixels': 0};

  final double refL = _median(samples.map((s) => s.l).toList());
  final double refA = _median(samples.map((s) => s.a).toList());
  final double refB = _median(samples.map((s) => s.b).toList());
  final _LabColor refWall = _LabColor(refL, refA, refB);

  const double kThreshold = 30.0;

  final List<bool> mask = List.filled(w * h, false);
  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      final p = small.getPixel(x, y);
      final lab = _rgbToLab(p.r.toInt(), p.g.toInt(), p.b.toInt());
      mask[y * w + x] = _deltaE(lab, refWall) < kThreshold;
    }
  }

  final List<bool> clean = List.filled(w * h, false);
  for (int y = 1; y < h - 1; y++) {
    for (int x = 1; x < w - 1; x++) {
      if (!mask[y * w + x]) continue;
      int n = 0;
      for (int dy = -1; dy <= 1; dy++) {
        for (int dx = -1; dx <= 1; dx++) {
          if (dx == 0 && dy == 0) continue;
          if (mask[(y + dy) * w + (x + dx)]) n++;
        }
      }
      clean[y * w + x] = n >= 4;
    }
  }

  final List<Map<String, double>> segments = [];
  int wallPixels = 0;

  for (int y = 0; y < h; y++) {
    int? startX;
    for (int x = 0; x < w; x++) {
      final isWall = clean[y * w + x];
      if (isWall) wallPixels++;

      if (isWall && startX == null) {
        startX = x;
      } else if (!isWall && startX != null) {
        segments.add({'x': startX.toDouble(), 'y': y.toDouble(), 'w': (x - startX).toDouble()});
        startX = null;
      }
    }
    if (startX != null) {
      segments.add({'x': startX.toDouble(), 'y': y.toDouble(), 'w': (w - startX).toDouble()});
    }
  }

  final double coverage = wallPixels / (w * h);
  return {'segments': segments, 'coverage': coverage, 'wallPixels': wallPixels};
}

class _LabColor {
  final double l, a, b;
  const _LabColor(this.l, this.a, this.b);
}

_LabColor _rgbToLab(int r, int g, int b) {
  double rl = r / 255.0;
  double gl = g / 255.0;
  double bl = b / 255.0;
  rl = rl > 0.04045 ? math.pow((rl + 0.055) / 1.055, 2.4).toDouble() : rl / 12.92;
  gl = gl > 0.04045 ? math.pow((gl + 0.055) / 1.055, 2.4).toDouble() : gl / 12.92;
  bl = bl > 0.04045 ? math.pow((bl + 0.055) / 1.055, 2.4).toDouble() : bl / 12.92;

  double x = (rl * 0.4124 + gl * 0.3576 + bl * 0.1805) / 0.95047;
  double y = (rl * 0.2126 + gl * 0.7152 + bl * 0.0722) / 1.00000;
  double z = (rl * 0.0193 + gl * 0.1192 + bl * 0.9505) / 1.08883;

  double f(double t) => t > 0.008856 ? math.pow(t, 1.0 / 3.0).toDouble() : (7.787 * t + 16.0 / 116.0);

  return _LabColor(
    116.0 * f(y) - 16.0,
    500.0 * (f(x) - f(y)),
    200.0 * (f(y) - f(z)),
  );
}

double _deltaE(_LabColor a, _LabColor b) {
  final dl = a.l - b.l;
  final da = a.a - b.a;
  final db = a.b - b.b;
  return math.sqrt(dl * dl + da * da + db * db);
}

double _median(List<double> v) {
  if (v.isEmpty) return 0;
  v.sort();
  final m = v.length ~/ 2;
  return v.length.isOdd ? v[m] : (v[m - 1] + v[m]) / 2.0;
}

class MLService {
  static final MLService _instance = MLService._internal();
  factory MLService() => _instance;
  MLService._internal();

  bool _isReady = false;
  Interpreter? _segmentationInterpreter;
  Interpreter? _recommendationInterpreter;
  int _currentModelVersion = 2; 

  void setModelVersion(int version) {
    if (version == _currentModelVersion) return;
    _currentModelVersion = version;
    _isReady = false;
    loadModel(); 
  }

  int get currentModelVersion => _currentModelVersion;

  static const int _kMaskSize = 128;
  
  static const String _kRemoteApiUrl = "https://evacuate-contents-species.ngrok-free.dev";
  static const String _kChatApiUrl = "https://transfer-certainty-wick.ngrok-free.dev/chat";

  bool get isModelLoaded => _isReady;
  int get maskSize => _kMaskSize;

  Future<void> _loadModel() async {
    try {
      String modelFile = _currentModelVersion == 1 
          ? 'assets/models/deeplabv3_plus_wall_v1.tflite'
          : 'assets/models/deeplabv3_plus_wall_v2.tflite';
          
      _segmentationInterpreter = await Interpreter.fromAsset(modelFile);
      _recommendationInterpreter = await Interpreter.fromAsset('assets/models/color_reco_model.tflite');
      
      _isReady = true;
      debugPrint('✅ MLService: Model v$_currentModelVersion Loaded Successfully.');
    } catch (e) {
      debugPrint('⚠️ MLService: Error loading Model v$_currentModelVersion: $e');
      _isReady = true;
    }
  }

  Future<void> loadModel() => _loadModel();

  Future<List<Map<String, double>>?> segmentWall(
    Uint8List imageBytes, {
    SegmentationTarget target = SegmentationTarget.wall,
  }) async {
    if (!_isReady) return null;
    if (_segmentationInterpreter != null) {
      try {
        final img.Image? decoded = img.decodeImage(imageBytes);
        if (decoded != null) {
          final img.Image resized = img.copyResize(decoded, width: 512, height: 512);
          var input = List.filled(1 * 512 * 512 * 3, 0.0).reshape([1, 512, 512, 3]);
          for (int y = 0; y < 512; y++) {
            for (int x = 0; x < 512; x++) {
              final pixel = resized.getPixel(x, y);
              input[0][y][x][0] = pixel.r / 255.0;
              input[0][y][x][1] = pixel.g / 255.0;
              input[0][y][x][2] = pixel.b / 255.0;
            }
          }
          var output = List.filled(1 * 512 * 512 * 3, 0.0).reshape([1, 512, 512, 3]);
          _segmentationInterpreter!.run(input, output);
          return _processTFLiteOutput(output, target);
        }
      } catch (e) {
        print('Local TFLite failed: $e');
      }
    }

    try {
      final result = await compute(_colorSegmentIsolate, {
        'imageBytes': imageBytes,
        'maskSize': _kMaskSize,
        'isFloor': target == SegmentationTarget.floor,
      });
      final segments = result['segments'] as List<Map<String, double>>?;
      final double coverage = result['coverage'] as double? ?? 0.0;
      if (segments == null || coverage < 0.04 || coverage > 0.95) return null;
      return segments;
    } catch (e) {
      return null;
    }
  }

  List<Map<String, double>> _processTFLiteOutput(List<dynamic> output, SegmentationTarget target) {
    final List<Map<String, double>> segments = [];
    const int modelRes = 512;
    const int displayRes = _kMaskSize; 
    final double step = modelRes / displayRes;
    int targetClass = (target == SegmentationTarget.wall) ? 1 : 2;

    for (int y = 0; y < displayRes; y++) {
      int? startX;
      for (int x = 0; x < displayRes; x++) {
        final int py = (y * step).toInt().clamp(0, modelRes - 1);
        final int px = (x * step).toInt().clamp(0, modelRes - 1);
        double maxProb = -1.0;
        int maxClass = 0;
        for (int c = 0; c < 3; c++) {
          double prob = output[0][py][px][c];
          if (prob > maxProb) {
            maxProb = prob;
            maxClass = c;
          }
        }
        bool isTarget = (maxClass == targetClass);
        if (isTarget && startX == null) {
          startX = x;
        } else if (!isTarget && startX != null) {
          segments.add({'x': startX.toDouble(), 'y': y.toDouble(), 'w': (x - startX).toDouble()});
          startX = null;
        }
      }
      if (startX != null) {
        segments.add({'x': startX.toDouble(), 'y': y.toDouble(), 'w': (displayRes - startX).toDouble()});
      }
    }
    return segments;
  }

  List<Map<String, double>> _processRemoteMask(List<dynamic> rawMask, SegmentationTarget target) {
    final List<Map<String, double>> segments = [];
    final int h = rawMask.length;
    final int w = rawMask[0].length;
    final double stepY = h / _kMaskSize;
    final double stepX = w / _kMaskSize;

    for (int y = 0; y < _kMaskSize; y++) {
      int? startX;
      for (int x = 0; x < _kMaskSize; x++) {
        final int py = (y * stepY).toInt().clamp(0, h - 1);
        final int px = (x * stepX).toInt().clamp(0, w - 1);
        final int label = rawMask[py][px];
        bool isTarget = (target == SegmentationTarget.wall) ? (label == 0) : (label == 3);
        if (isTarget && startX == null) {
          startX = x;
        } else if (!isTarget && startX != null) {
          segments.add({'x': startX.toDouble(), 'y': y.toDouble(), 'w': (x - startX).toDouble()});
          startX = null;
        }
      }
      if (startX != null) {
        segments.add({'x': startX.toDouble(), 'y': y.toDouble(), 'w': (_kMaskSize - startX).toDouble()});
      }
    }
    return segments;
  }

  Future<int?> predictMood(Color color) async {
    if (_isReady && _recommendationInterpreter != null) {
      try {
        var input = [[color.red / 255.0, color.green / 255.0, color.blue / 255.0]];
        var output = List.filled(1 * 3, 0.0).reshape([1, 3]);
        _recommendationInterpreter!.run(input, output);
        List<double> scores = List<double>.from(output[0]);
        int bestIdx = 0;
        for (int i = 1; i < scores.length; i++) {
          if (scores[i] > scores[bestIdx]) bestIdx = i;
        }
        if (scores[bestIdx] > 0.45) return bestIdx;
      } catch (e) {
        debugPrint("Local Mood Error: $e");
      }
    }

    try {
      final hex = '#${color.value.toRadixString(16).substring(2).toUpperCase()}';
      final response = await http.post(
        Uri.parse(_kChatApiUrl),
        headers: {'Content-Type': 'application/json', 'ngrok-skip-browser-warning': 'true'},
        body: jsonEncode({
          'message': "Classify this color hex $hex into one mood: MODERN, WARM, or CALM. Respond with only ONE WORD.",
          'system_prompt': "You are a color expert. Return ONLY the word: MODERN, WARM, or CALM.",
        }),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String moodStr = (data['response'] ?? data['generated_text'] ?? "").toString().toUpperCase();
        if (moodStr.contains('MODERN')) return 0;
        if (moodStr.contains('WARM')) return 1;
        if (moodStr.contains('CALM')) return 2;
      }
    } catch (e) {
      debugPrint("Kaggle Fallback Error: $e");
    }
    return null;
  }

  void dispose() {
    _segmentationInterpreter?.close();
    _recommendationInterpreter?.close();
    _isReady = false;
  }
}
