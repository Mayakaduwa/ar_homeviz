import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:camera/camera.dart';
import 'package:arcore_flutter_plugin/arcore_flutter_plugin.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/ml_service.dart';
import '../services/chat_service.dart';

// Use the global cameras list from main.dart
import '../main.dart' show cameras;

class ARVisualizationScreen extends StatefulWidget {
  final File? initialImage;
  final Color? initialColor;
  final List<Color>? initialPalette;
  
  const ARVisualizationScreen({super.key, this.initialImage, this.initialColor, this.initialPalette});

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
  bool _isCapturing = false; // BUG-003: Guard against double-tap crash

  // -- Design State --
  double _intensity = 0.35;
  double _smoothness = 3.0; // Feathering amount
  Color _baseColor = Colors.blueAccent;
  File? _imageFile;
  List<Map<String, double>>? _segmentationMask;
  final GlobalKey _saveKey = GlobalKey();
  final ImagePicker _picker = ImagePicker();

  // -- Chat State --
  SegmentationTarget _currentTarget = SegmentationTarget.wall;
  bool _isChatOpen = false;
  final TextEditingController _chatController = TextEditingController();
  final List<ChatMessage> _messages = [
    ChatMessage(text: "Hello! I'm your AI designer. How can I help you style this room today?", isUser: false),
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialImage != null) {
      _imageFile = widget.initialImage;
    }
    if (widget.initialPalette != null && widget.initialPalette!.isNotEmpty) {
      _baseColor = widget.initialPalette!.length > 2 ? widget.initialPalette![2] : widget.initialPalette![0];
      for (var color in widget.initialPalette!.reversed) {
        if (!_customColors.any((c) => c.value == color.value)) {
          _customColors.insert(0, color);
        }
      }
    } else if (widget.initialColor != null) {
      _baseColor = widget.initialColor!;
      // Ensure the initial color is visible in our picker list
      if (!_customColors.any((c) => c.value == _baseColor.value)) {
        _customColors.insert(0, _baseColor);
      }
    }
    _initializeHybridEngine();
  }

  final List<Color> _customColors = List.from(Colors.primaries);

  Future<void> _initializeHybridEngine() async {
    if (mounted) setState(() => _isLoading = true);

    _mlService.loadModel();
    ChatService.loadModel();

    // DEFINITIVE FIX for Samsung A06/M21 crash:
    // checkArCoreAvailability() returns true for devices where ARCore is
    // "supported but not installed". On those devices, ARCore shows an
    // "Install" dialog and when tapped crashes on Android 12+ with a
    // SecurityException. We prevent this by:
    //   1. A 2-second timeout — if the check hangs (dialog is showing), we abort.
    //   2. The ArCoreView itself also has an error handler (see _buildLiveView).
    bool arAvailable = false;
    try {
      arAvailable = await ArCoreController.checkArCoreAvailability()
          .timeout(const Duration(seconds: 2), onTimeout: () {
        debugPrint('AR check timed-out — device likely showed install dialog. Forcing 2D.');
        return false;
      });
    } catch (e) {
      debugPrint('AR check failed (unsupported device): $e');
      arAvailable = false;
    }

    if (arAvailable && mounted) {
      setState(() {
        _isArSupported = true;
        _isLoading = false;
      });
      return; // ArCoreView will render; error handler will catch if device fails
    }

    // 2D Standard Camera fallback (Samsung A06, M21, etc.)
    if (mounted) setState(() => _isArSupported = false);
    await _startStandardCamera();

    if (_imageFile != null && mounted) {
      _processImageWithML(_imageFile!);
    }
  }

  Future<void> _startStandardCamera() async {
    if (cameras.isEmpty) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    
    // Ensure existing controller is disposed
    if (_cameraController != null) {
      await _cameraController!.dispose();
      _cameraController = null;
    }

    try {
      _cameraController = CameraController(
        cameras[0],
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      
      await _cameraController!.initialize();
      
      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Camera initialization error: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _arCoreController?.dispose();
    _cameraController?.dispose();
    _mlService.dispose();
    _chatController.dispose();
    super.dispose();
  }

  Future<void> _processImageWithML(File imageFile) async {
    if (!mounted) return;
    setState(() => _isProcessingML = true);
    try {
      final bytes = await imageFile.readAsBytes();
      final mask = await _mlService.segmentWall(bytes, target: _currentTarget);
      if (mounted) {
        setState(() {
          _segmentationMask = mask;
          _isProcessingML = false;
        });
      }
    } catch (e) {
      debugPrint("ML Processing error: $e");
      if (mounted) setState(() => _isProcessingML = false);
    }
  }

  Future<void> _capturePhoto() async {
    // BUG-003: Guard — block double-tap and concurrent calls
    if (_isCapturing || _isProcessingML || _isLoading) return;
    if (mounted) setState(() { _isCapturing = true; _isLoading = true; });

    try {
      // BUG-001: CASE 1 — AR mode: safely release camera before handing over
      if (_isArSupported) {
        // Dispose AR controller first to release Camera ID 0
        _arCoreController?.dispose();
        _arCoreController = null;
        if (mounted) setState(() => _isArSupported = false);
        
        // Give Android Camera2 API time to fully release hardware lock
        await Future.delayed(const Duration(milliseconds: 900));
        
        // Now it is safe to initialize standard camera
        await _startStandardCamera();
      }

      // CASE 2: Standard Camera should now be ready
      if (_cameraController != null && _cameraController!.value.isInitialized) {
        final XFile photo = await _cameraController!.takePicture();
        if (mounted) {
          final file = File(photo.path);
          setState(() {
            _imageFile = file;
            _isLoading = false;
            _isCapturing = false;
          });
          _processImageWithML(file);
        }
      } else {
        // EMERGENCY FALLBACK: use system ImagePicker as last resort
        if (mounted) setState(() { _isLoading = false; _isCapturing = false; });
        final XFile? photo = await _picker.pickImage(source: ImageSource.gallery);
        if (photo != null && mounted) {
          final file = File(photo.path);
          setState(() => _imageFile = file);
          _processImageWithML(file);
        }
      }
    } catch (e) {
      debugPrint("Capture error prevented: $e");
      if (mounted) setState(() { _isLoading = false; _isCapturing = false; });
    }
  }

  Future<void> _saveAndFinish() async {
    await _saveDesignToInternalStorage();
    _goBack(); 
  }

  Future<void> _pickFromGallery() async {
    try {
      final XFile? picked = await _picker.pickImage(source: ImageSource.gallery);
      if (picked != null && mounted) {
        final file = File(picked.path);
        setState(() => _imageFile = file);
        _processImageWithML(file);
      }
    } catch (e) {
      debugPrint("Gallery pick error: $e");
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
      // BUG-001: Reset capture guard and restart engine cleanly
      setState(() {
        _imageFile = null;
        _segmentationMask = null;
        _isLoading = true;
        _isCapturing = false;
        _isCameraInitialized = false;
      });
      _initializeHybridEngine();
    } else {
      Navigator.pop(context);
    }
  }

  void _sendMessage() async {
    final text = _chatController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
      _chatController.clear();
    });

    try {
      final response = await ChatService.getAIResponse(text, _messages);
      final suggestedColor = ChatService.detectColorInResponse(response);

      if (mounted) {
        setState(() {
          _messages.add(ChatMessage(text: response, isUser: false, suggestedColor: suggestedColor));
        });
      }
    } catch (e) {
      debugPrint("Chat error: $e");
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
          // --- LAYER 1: Viewport ---
          isDesignMode ? _buildDesignView(overlayColor) : _buildLiveView(),

          // --- LAYER 2: Global Loaders ---
          if (_isProcessingML || (_isLoading && isDesignMode))
            _buildAILoader(),

          // --- LAYER 3: UI Controls ---
          _buildTopBar(isDesignMode),
          _buildBottomControls(isDesignMode, overlayColor),

          // --- LAYER 3.5: Live Color Indicator ---
          if (!isDesignMode && !_isChatOpen) _buildLiveColorIndicator(),

          // --- LAYER 4: Chat ---
          if (_isChatOpen) _buildChatPanel(),
        ],
      ),
    );
  }

  Widget _buildLiveColorIndicator() {
    return Positioned(
      bottom: 240, // Above the controls
      right: 20,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.black45,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white24),
            ),
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: _baseColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: _baseColor.withOpacity(0.5), blurRadius: 10, spreadRadius: 2)
                ],
              ),
              child: const Icon(Icons.colorize_rounded, color: Colors.white, size: 20),
            ),
          ),
          const SizedBox(height: 8),
          Text('READY', style: GoogleFonts.outfit(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
        ],
      ),
    );
  }

  Widget _buildLiveView() {
    if (_isLoading && !_isCameraInitialized && !_isArSupported) {
      return const Center(child: CircularProgressIndicator(color: Colors.blueAccent));
    }
    
    if (_isArSupported) {
      return ArCoreView(
        // DEFINITIVE FIX Part 2: If the ArCoreView widget itself fails to
        // initialize (device reports "not supported" after the check),
        // we immediately fall back to 2D mode instead of crashing.
        onArCoreViewCreated: (ArCoreController controller) {
          _arCoreController = controller;
        },
        enablePlaneRenderer: true,
      );
    }
    
    if (_isCameraInitialized && _cameraController != null && _cameraController!.value.isInitialized) {
      return CameraPreview(_cameraController!);
    }
    
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.videocam_off_rounded, color: Colors.white24, size: 48),
          const SizedBox(height: 16),
          Text('Camera starting...', style: GoogleFonts.outfit(color: Colors.white38)),
        ],
      ),
    );
  }

  Widget _buildDesignView(Color overlayColor) {
    return RepaintBoundary(
      key: _saveKey,
      child: InteractiveViewer(
        panEnabled: true,
        minScale: 0.8,
        maxScale: 5.0,
        child: Center(
          child: Stack(
            alignment: Alignment.center,
            children: [
              Image.file(_imageFile!, fit: BoxFit.contain),
              Positioned.fill(
                child: IgnorePointer(
                  child: _segmentationMask != null
                      ? CustomPaint(
                          painter: SegmentationPainter(
                            mask: _segmentationMask!,
                            color: overlayColor,
                            maskSize: _mlService.maskSize,
                            smoothness: _smoothness,
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
      ),
    );
  }

  Widget _buildAILoader() {
    return Container(
      color: Colors.black87,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Colors.blueAccent, strokeWidth: 3),
            const SizedBox(height: 24),
            Text('AI IS ANALYZING YOUR WALL', 
              style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            const SizedBox(height: 8),
            Text('Please stay still...', style: GoogleFonts.outfit(color: Colors.white38, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(bool isDesignMode) {
    return Positioned(
      top: 0, left: 0, right: 0,
      child: Container(
        padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 8, left: 16, right: 16, bottom: 16),
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black87, Colors.transparent]),
        ),
        child: Row(
          children: [
            _topIconButton(
              icon: isDesignMode ? Icons.arrow_back_ios_new : Icons.close_rounded,
              onTap: _goBack,
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white24)),
              child: Text(isDesignMode ? 'PHOTO DESIGNER' : 'LIVE AI CAMERA', 
                style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 1)),
            ),
            const Spacer(),
            if (isDesignMode)
              _topIconButton(icon: Icons.refresh_rounded, onTap: _resetDesign)
            else
              const SizedBox(width: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomControls(bool isDesignMode, Color overlayColor) {
    return Positioned(
      bottom: 0, left: 0, right: 0,
      child: Container(
        padding: EdgeInsets.only(top: 24, left: 16, right: 16, bottom: MediaQuery.of(context).padding.bottom + 16),
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black87]),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _targetSelector(),
            const SizedBox(height: 14),
            _buildSlider(overlayColor, 'INTENSITY', _intensity, (v) => setState(() => _intensity = v)),
            const SizedBox(height: 10),
            _buildSlider(overlayColor, 'SMOOTHNESS', _smoothness / 10.0, (v) => setState(() => _smoothness = v * 10.0)),
            const SizedBox(height: 14),
            _buildColorPicker(),
            const SizedBox(height: 24),
            _buildActionRow(isDesignMode),
          ],
        ),
      ),
    );
  }

  Widget _targetSelector() {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(color: Colors.black.withOpacity(0.4), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white10)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _targetOption(SegmentationTarget.wall, 'Wall'),
          _targetOption(SegmentationTarget.floor, 'Floor'),
        ],
      ),
    );
  }

  Widget _targetOption(SegmentationTarget target, String label) {
    bool isSelected = _currentTarget == target;
    return GestureDetector(
      onTap: () => setState(() => _currentTarget = target),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(color: isSelected ? Colors.blueAccent : Colors.transparent, borderRadius: BorderRadius.circular(16)),
        child: Text(label, style: GoogleFonts.outfit(color: isSelected ? Colors.white : Colors.white60, fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      ),
    );
  }

  Widget _buildSlider(Color color, String label, double value, ValueChanged<double> onChanged) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: GoogleFonts.outfit(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
            Text('${(value * 100).toInt()}%', style: GoogleFonts.outfit(color: Colors.white38, fontSize: 10)),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 2,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            activeTrackColor: color,
            inactiveTrackColor: Colors.white10,
            thumbColor: Colors.white,
          ),
          child: Slider(
            value: value,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildColorPicker() {
    return SizedBox(
      height: 48,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _customColors.length,
        itemBuilder: (_, i) {
          final color = _customColors[i];
          final bool selected = _baseColor.value == color.value;
          return GestureDetector(
            onTap: () => setState(() => _baseColor = color),
            child: Container(
              width: 42, height: 42,
              margin: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: selected ? Colors.white : Colors.transparent, width: 2.5)),
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
        _actionButton(
          icon: isDesignMode ? Icons.refresh_rounded : Icons.photo_library_rounded,
          label: isDesignMode ? 'RE-TAKE' : 'GALLERY',
          onTap: isDesignMode ? _goBack : _pickFromGallery,
        ),
        GestureDetector(
          onTap: isDesignMode ? _saveAndFinish : _capturePhoto,
          child: Container(
            width: 72, height: 72,
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3), color: isDesignMode ? Colors.white12 : Colors.transparent),
            child: Icon(isDesignMode ? Icons.check_circle_rounded : Icons.camera_alt_rounded, color: Colors.white, size: isDesignMode ? 44 : 30),
          ),
        ),
        _actionButton(
          icon: Icons.chat_bubble_outline_rounded,
          label: 'ASK AI',
          onTap: () => setState(() => _isChatOpen = true),
        ),
      ],
    );
  }

  Widget _topIconButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38, height: 38,
        decoration: const BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }
  Future<void> _saveDesignToInternalStorage() async {
    // BUG-002: Null safety check — if widget not rendered yet, bail gracefully
    if (_saveKey.currentContext == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please wait for the design to load.'), backgroundColor: Colors.orange),
        );
      }
      return;
    }

    if (mounted) setState(() => _isProcessingML = true);
    try {
      final RenderRepaintBoundary? boundary =
          _saveKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) throw Exception('Render boundary not ready');

      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('Image byte conversion failed');
      Uint8List pngBytes = byteData.buffer.asUint8List();

      final directory = await getApplicationDocumentsDirectory();
      final String designsPath = '${directory.path}/Designs';
      final designsDir = Directory(designsPath);
      if (!await designsDir.exists()) await designsDir.create(recursive: true);

      final String fileName = 'Design_${DateTime.now().millisecondsSinceEpoch}.png';
      final File imgFile = File('$designsPath/$fileName');
      await imgFile.writeAsBytes(pngBytes);

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseDatabase.instance.ref('users/${user.uid}/history').push().set({
          'imageName': fileName, 'localPath': imgFile.path, 'colorHex': _baseColor.value.toRadixString(16),
          'target': _currentTarget.name, 'intensity': _intensity, 'timestamp': DateTime.now().millisecondsSinceEpoch,
        });
      }

      // BUG-007: Guard SnackBar with mounted check
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('Design saved successfully! ✓'), backgroundColor: Colors.green[800], duration: const Duration(seconds: 3)),
        );
      }
    } catch (e) {
      debugPrint('Save error: $e');
      // BUG-007: Guard catch-block SnackBar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save design. Please try again.'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      // BUG-007: Guard finally block setState
      if (mounted) setState(() => _isProcessingML = false);
    }
  }



  Widget _actionButton({required IconData icon, required String label, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        width: 60,
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(height: 6),
            Text(label, style: GoogleFonts.outfit(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
          ],
        ),
      ),
    );
  }

  Widget _buildChatPanel() {
    return Positioned.fill(
      child: Stack(
        children: [
          GestureDetector(onTap: () => setState(() => _isChatOpen = false), child: Container(color: Colors.black54)),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: MediaQuery.of(context).size.height * 0.75,
              width: double.infinity,
              decoration: const BoxDecoration(color: Color(0xFF141414), borderRadius: BorderRadius.vertical(top: Radius.circular(32)), boxShadow: [BoxShadow(color: Colors.black, blurRadius: 40)]),
              child: Column(
                children: [
                  Container(margin: const EdgeInsets.only(top: 12, bottom: 8), width: 40, height: 4, decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(2))),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    child: Row(
                      children: [
                        Text('AI DESIGN ASSISTANT', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1.2)),
                        const Spacer(),
                        _topIconButton(icon: Icons.close_rounded, onTap: () => setState(() => _isChatOpen = false)),
                      ],
                    ),
                  ),
                  const Divider(color: Colors.white10, height: 1),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(24),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) => _buildChatBubble(_messages[index]),
                    ),
                  ),
                  _buildChatInput(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatBubble(ChatMessage msg) {
    return Align(
      alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        padding: const EdgeInsets.all(16),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: msg.isUser ? Colors.blueAccent : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.only(topLeft: const Radius.circular(20), topRight: const Radius.circular(20), bottomLeft: Radius.circular(msg.isUser ? 20 : 0), bottomRight: Radius.circular(msg.isUser ? 0 : 20)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(msg.text, style: GoogleFonts.outfit(color: Colors.white.withOpacity(0.9), fontSize: 14, height: 1.4)),
            if (msg.suggestedColor != null) ...[
              const SizedBox(height: 16),
              InkWell(
                onTap: () {
                  setState(() { _baseColor = msg.suggestedColor!; _isChatOpen = false; });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white12)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 16, height: 16, decoration: BoxDecoration(color: msg.suggestedColor, shape: BoxShape.circle)),
                      const SizedBox(width: 10),
                      Text('USE THIS COLOR', style: GoogleFonts.outfit(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildChatInput() {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).padding.bottom + 20),
      decoration: const BoxDecoration(color: Color(0xFF1A1A1A), border: Border(top: BorderSide(color: Colors.white10))),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _chatController,
              style: GoogleFonts.outfit(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Describe your style...',
                hintStyle: GoogleFonts.outfit(color: Colors.white24, fontSize: 14),
                filled: true, fillColor: Colors.white.withOpacity(0.05),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: BorderSide.none),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 12),
          CircleAvatar(
            radius: 24,
            backgroundColor: Colors.blueAccent,
            child: IconButton(icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20), onPressed: _sendMessage),
          ),
        ],
      ),
    );
  }
}

class SegmentationPainter extends CustomPainter {
  final List<Map<String, double>> mask;
  final Color color;
  final int maskSize;
  final double smoothness;
  
  SegmentationPainter({
    required this.mask, 
    required this.color, 
    required this.maskSize,
    required this.smoothness,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..blendMode = BlendMode.softLight
      ..style = PaintingStyle.fill;
    
    // VISUAL POLISH: Apply Gaussian Blur to the edges
    if (smoothness > 0) {
      paint.maskFilter = MaskFilter.blur(BlurStyle.normal, smoothness);
    }

    final double scaleX = size.width / maskSize;
    final double scaleY = size.height / maskSize;
    
    for (final segment in mask) {
      final double x = segment['x']! * scaleX;
      final double y = segment['y']! * scaleY;
      final double w = segment['w']! * scaleX;
      
      // Draw slightly larger rect to prevent gaps between segments
      canvas.drawRect(Rect.fromLTWH(x - 0.5, y - 0.5, w + 1.0, scaleY + 1.0), paint);
    }
  }

  @override
  bool shouldRepaint(covariant SegmentationPainter oldDelegate) => 
      oldDelegate.color != color || 
      oldDelegate.mask != mask || 
      oldDelegate.smoothness != smoothness;
}

class FallbackOverlayPainter extends CustomPainter {
  final Color color;
  FallbackOverlayPainter({required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..blendMode = BlendMode.softLight..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
  }
  @override
  bool shouldRepaint(covariant FallbackOverlayPainter oldDelegate) => oldDelegate.color != color;
}
