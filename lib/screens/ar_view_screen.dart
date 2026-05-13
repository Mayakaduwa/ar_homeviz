import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:arcore_flutter_plugin/arcore_flutter_plugin.dart';
import 'package:image_picker/image_picker.dart';
import '../services/ml_service.dart';

// Use the global cameras list from main.dart
import '../main.dart' show cameras;

class ARVisualizationScreen extends StatefulWidget {
  const ARVisualizationScreen({super.key});

  @override
  State<ARVisualizationScreen> createState() => _ARVisualizationScreenState();
}

class _ARVisualizationScreenState extends State<ARVisualizationScreen> {
  // -- Controllers --
  ArCoreController? _arCoreController;
  CameraController? _cameraController;
  final MLService _mlService = MLService();

  // -- Engine State --
  bool _isArSupported = false;
  bool _isCameraInitialized = false;
  bool _isLoading = true;
  bool _isProcessingML = false;

  // -- Design State --
  double _intensity = 0.35;
  Color _baseColor = Colors.blueAccent;
  File? _imageFile;
  List<Map<String, double>>? _segmentationMask;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _initializeHybridEngine();
  }

  Future<void> _initializeHybridEngine() async {
    // Start loading the ML model in the background
    _mlService.loadModel();
    
    try {
      bool arAvailable = await ArCoreController.checkArCoreAvailability();
      if (arAvailable) {
        setState(() {
          _isArSupported = true;
          _isLoading = false;
        });
        return;
      }
    } catch (_) {}
    await _startStandardCamera();
  }

  Future<void> _startStandardCamera() async {
    if (cameras.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }
    try {
      _cameraController = CameraController(
        cameras[0],
        ResolutionPreset.medium, // lower res avoids OOM crash on older devices
        enableAudio: false,
      );
      await _cameraController!.initialize();
      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _arCoreController?.dispose();
    _cameraController?.dispose();
    _mlService.dispose();
    super.dispose();
  }

  Future<void> _processImageWithML(File imageFile) async {
    setState(() => _isProcessingML = true);
    try {
      final bytes = await imageFile.readAsBytes();
      final mask = await _mlService.segmentWall(bytes);
      if (mounted) {
        setState(() {
          _segmentationMask = mask;
          _isProcessingML = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isProcessingML = false);
    }
  }

  Future<void> _capturePhoto() async {
    if (!_isCameraInitialized || _cameraController == null) return;
    try {
      final XFile photo = await _cameraController!.takePicture();
      if (mounted) {
        final file = File(photo.path);
        setState(() => _imageFile = file);
        _processImageWithML(file);
      }
    } catch (e) {}
  }

  Future<void> _pickFromGallery() async {
    final XFile? picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null && mounted) {
      final file = File(picked.path);
      setState(() => _imageFile = file);
      _processImageWithML(file);
    }
  }

  void _resetDesign() {
    setState(() {
      _intensity = 0.35;
      _baseColor = Colors.blueAccent;
    });
  }

  void _goBack() {
    if (_imageFile != null) {
      setState(() {
        _imageFile = null;
        _segmentationMask = null;
      });
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesignMode = _imageFile != null;
    final Color overlayColor = _baseColor.withOpacity(_intensity);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // --- LAYER 1: Background Content ---
          isDesignMode
              ? InteractiveViewer(
                  panEnabled: true,
                  minScale: 0.8,
                  maxScale: 5.0,
                  child: Center(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Image.file(_imageFile!, fit: BoxFit.contain),
                        // ALWAYS show color overlay — switches to smart mask when ML is ready
                        Positioned.fill(
                          child: IgnorePointer(
                            child: _segmentationMask != null
                                ? CustomPaint(
                                    painter: SegmentationPainter(
                                      mask: _segmentationMask!,
                                      color: overlayColor,
                                      maskSize: _mlService.maskSize,
                                    ),
                                  )
                                : CustomPaint(
                                    painter: FallbackOverlayPainter(
                                      color: overlayColor,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : _buildViewport(),

          // --- LAYER 2: ML Processing Overlay ---
          if (_isProcessingML)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.blueAccent),
                    SizedBox(height: 16),
                    Text('AI is analyzing the wall...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),

          // --- LAYER 3: TOP BAR ---
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black87, Colors.transparent],
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      _topIconButton(
                        icon: isDesignMode ? Icons.arrow_back_ios_new : Icons.close_rounded,
                        onTap: _goBack,
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Text(
                          isDesignMode ? 'PHOTO DESIGNER' : 'LIVE AI CAMERA',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                        ),
                      ),
                      const Spacer(),
                      isDesignMode
                          ? _topIconButton(icon: Icons.refresh_rounded, onTap: _resetDesign)
                          : const SizedBox(width: 40),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black87],
                ),
              ),
              padding: EdgeInsets.only(
                top: 24, left: 16, right: 16,
                bottom: MediaQuery.of(context).padding.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildSlider(overlayColor),
                  const SizedBox(height: 14),
                  _buildColorPicker(),
                  const SizedBox(height: 24),
                  _buildActionRow(isDesignMode),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewport() {
    if (_isLoading) return const Center(child: CircularProgressIndicator(color: Colors.blueAccent));
    if (_isArSupported) return ArCoreView(onArCoreViewCreated: (c) => _arCoreController = c, enablePlaneRenderer: true);
    if (_isCameraInitialized && _cameraController != null) return CameraPreview(_cameraController!);
    return const Center(child: Text('Camera not available', style: TextStyle(color: Colors.white38)));
  }

  Widget _buildSlider(Color overlayColor) {
    return Row(
      children: [
        const Icon(Icons.opacity_rounded, color: Colors.white54, size: 18),
        Expanded(
          child: Slider(
            value: _intensity,
            min: 0.0,
            max: 1.0,
            onChanged: (val) => setState(() => _intensity = val),
            activeColor: overlayColor.withOpacity(1.0),
          ),
        ),
        const Icon(Icons.format_paint_rounded, color: Colors.white54, size: 18),
      ],
    );
  }

  Widget _buildColorPicker() {
    return SizedBox(
      height: 52,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: Colors.primaries.length,
        itemBuilder: (_, i) {
          final color = Colors.primaries[i];
          final bool selected = _baseColor.value == color.value;
          return GestureDetector(
            onTap: () => setState(() => _baseColor = color),
            child: Container(
              width: 46, height: 46,
              margin: const EdgeInsets.symmetric(horizontal: 5),
              decoration: BoxDecoration(
                color: color, shape: BoxShape.circle,
                border: Border.all(color: selected ? Colors.white : Colors.transparent, width: 3),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildActionRow(bool isDesignMode) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        if (!isDesignMode)
          _actionButton(icon: Icons.photo_library_rounded, label: 'GALLERY', onTap: _pickFromGallery)
        else
          _actionButton(icon: Icons.save_alt_rounded, label: 'SAVE', onTap: () {}),
        GestureDetector(
          onTap: isDesignMode ? () {} : _capturePhoto,
          child: Container(
            width: 72, height: 72,
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3.5)),
            child: Icon(isDesignMode ? Icons.check : Icons.camera_alt_rounded, color: Colors.white),
          ),
        ),
        const SizedBox(width: 56),
      ],
    );
  }

  Widget _topIconButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  Widget _actionButton({required IconData icon, required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: Colors.white),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 10)),
        ],
      ),
    );
  }
}

/// Custom Painter to draw the wall segmentation mask
class SegmentationPainter extends CustomPainter {
  final List<Map<String, double>> mask;
  final Color color;
  final int maskSize;

  SegmentationPainter({required this.mask, required this.color, required this.maskSize});

  @override
  void paint(Canvas canvas, Size size) {
    // USE BlendMode.softLight for realistic painting
    final paint = Paint()
      ..color = color
      ..blendMode = BlendMode.softLight
      ..style = PaintingStyle.fill;

    final double scaleX = size.width / maskSize;
    final double scaleY = size.height / maskSize;

    // Drawing optimized segments instead of 66,000 pixels
    for (final segment in mask) {
      final double x = segment['x']! * scaleX;
      final double y = segment['y']! * scaleY;
      final double w = segment['w']! * scaleX;
      
      // Draw the horizontal segment
      // Use +1.0 height to avoid horizontal gaps between rows
      canvas.drawRect(
        Rect.fromLTWH(x, y, w + 0.5, scaleY + 0.5),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant SegmentationPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.mask != mask;
  }
}

/// Fallback painter that colors the whole screen with SoftLight blend
class FallbackOverlayPainter extends CustomPainter {
  final Color color;

  FallbackOverlayPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..blendMode = BlendMode.softLight
      ..style = PaintingStyle.fill;

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant FallbackOverlayPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
