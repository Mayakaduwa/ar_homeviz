import 'dart:math' as math;
import 'package:image/image.dart' as img;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
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

  // Scale down to maskSize×maskSize for fast processing
  final img.Image small = img.copyResize(
    decoded,
    width: maskSize,
    height: maskSize,
    interpolation: img.Interpolation.linear,
  );

  final int w = small.width;
  final int h = small.height;

  // ── Step 1: Sample "likely wall" zones ────────────────────────────────────
  // Walls appear in the top portion of interior photos, especially corners.
  // Zones: top-left strip, top-center strip, top-right strip (upper 20%)
  // ── Step 1: Sample "target" zones ─────────────────────────────────────────
  final List<_LabColor> samples = [];

  void sampleZone(int x0, int x1, int y0, int y1) {
    for (int y = y0; y < y1; y++) {
      for (int x = x0; x < x1; x++) {
        final p = small.getPixel(x, y);
        samples.add(_rgbToLab(p.r.toInt(), p.g.toInt(), p.b.toInt()));
      }
    }
  }

  // Floor sampling (bottom center) vs Wall sampling (top strips)
  if (isFloor) {
    sampleZone((w * 0.4).toInt(), (w * 0.6).toInt(), (h * 0.8).toInt(), h);
  } else {
    final int sampleH = (h * 0.20).toInt().clamp(4, h);
    sampleZone(0, (w * 0.12).toInt().clamp(2, w), 0, sampleH);               // top-left
    sampleZone((w * 0.35).toInt(), (w * 0.65).toInt(), 0, sampleH);          // top-center
    sampleZone((w * 0.88).toInt().clamp(0, w - 2), w, 0, sampleH);          // top-right
  }

  if (samples.isEmpty) return {'segments': null, 'coverage': 0.0, 'wallPixels': 0};

  // Median LAB = representative "wall" colour
  final double refL = _median(samples.map((s) => s.l).toList());
  final double refA = _median(samples.map((s) => s.a).toList());
  final double refB = _median(samples.map((s) => s.b).toList());
  final _LabColor refWall = _LabColor(refL, refA, refB);

  // ── Step 2: Classify pixels ───────────────────────────────────────────────
  // Delta-E threshold: 30 is better balanced for indoor lighting vs the original 38
  // (tighter = fewer false positives; wider = catches more wall pixels in dark rooms)
  const double kThreshold = 30.0;

  final List<bool> mask = List.filled(w * h, false);
  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      final p = small.getPixel(x, y);
      final lab = _rgbToLab(p.r.toInt(), p.g.toInt(), p.b.toInt());
      mask[y * w + x] = _deltaE(lab, refWall) < kThreshold;
    }
  }

  // ── Step 3: Erosion — remove noise (keep pixel only if ≥4 neighbours match)
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

  // ── Step 4: Merge into horizontal segments ────────────────────────────────
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

// ─────────────────────────────────────────────────────────────────────────────
// LAB colour helpers
// ─────────────────────────────────────────────────────────────────────────────

class _LabColor {
  final double l, a, b;
  const _LabColor(this.l, this.a, this.b);
}

_LabColor _rgbToLab(int r, int g, int b) {
  // sRGB → linear
  double rl = r / 255.0;
  double gl = g / 255.0;
  double bl = b / 255.0;
  rl = rl > 0.04045 ? math.pow((rl + 0.055) / 1.055, 2.4).toDouble() : rl / 12.92;
  gl = gl > 0.04045 ? math.pow((gl + 0.055) / 1.055, 2.4).toDouble() : gl / 12.92;
  bl = bl > 0.04045 ? math.pow((bl + 0.055) / 1.055, 2.4).toDouble() : bl / 12.92;

  // linear → XYZ D65
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

// ─────────────────────────────────────────────────────────────────────────────
// MLService public API (unchanged interface so ar_view_screen.dart works as-is)
// ─────────────────────────────────────────────────────────────────────────────

class MLService {
  bool _isReady = false;

  /// Public maskSize that the painter uses for coordinate scaling.
  static const int _kMaskSize = 128;
  
  /// YOUR NGROK URL FROM COLAB
  static const String _kRemoteApiUrl = "https://evacuate-contents-species.ngrok-free.dev";

  bool get isModelLoaded => _isReady;
  int get maskSize => _kMaskSize;

  /// No model file needed — just marks the service ready immediately.
  Future<void> loadModel() async {
    _isReady = true;
    print('✅ MLService ready — colour-based wall detector (maskSize=$_kMaskSize)');
  }

  Future<List<Map<String, double>>?> segmentWall(
    Uint8List imageBytes, {
    SegmentationTarget target = SegmentationTarget.wall,
  }) async {
    if (!_isReady) return null;

    // --- STEP A: TRY REMOTE AI (OBJECTIVE 1) ---
    try {
      print('🌐 Attempting Cloud AI (${target.name}) Segmentation...');
      var request = http.MultipartRequest('POST', Uri.parse('$_kRemoteApiUrl/segment'));
      request.fields['target'] = target.name;
      request.files.add(http.MultipartFile.fromBytes('file', imageBytes, filename: 'input.jpg'));
      
      var streamedResponse = await request.send().timeout(const Duration(seconds: 8));
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> rawMask = data['mask'];
        return _processRemoteMask(rawMask, target);
      }
    } catch (e) {
      print('⚠️ Cloud AI unavailable (using local fallback): $e');
    }

    // --- STEP B: LOCAL FALLBACK (COLOUR-BASED) ---
    try {
      final result = await compute(_colorSegmentIsolate, {
        'imageBytes': imageBytes,
        'maskSize': _kMaskSize,
        'isFloor': target == SegmentationTarget.floor,
      });

      final segments = result['segments'] as List<Map<String, double>>?;
      final double coverage = result['coverage'] as double? ?? 0.0;
      
      // BUG-005: Don't return null on high coverage (white/light walls score > 0.90)
      // Instead accept it and let FallbackOverlayPainter handle the coloring
      if (segments == null || coverage < 0.04) return null;
      // If coverage is impossibly high (> 0.95) return null — probably a blank/solid image
      if (coverage > 0.95) return null;
      return segments;
    } catch (e) {
      print('❌ Local detection error: $e');
      return null;
    }
  }

  /// Converts a 2D grid mask from the server into optimized horizontal segments
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
        
        // CLASS MAPPING:
        // DeepLabV3 usually: Class 0=Background/Wall, Class 3=Floor (PASCAL VOC)
        bool isTarget = false;
        if (target == SegmentationTarget.wall) {
          isTarget = (label == 0); // Background/Wall
        } else {
          isTarget = (label == 3); // Floor
        }

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

  void dispose() {
    _isReady = false;
  }
}
