import 'dart:math' as math;
import 'package:image/image.dart' as img;
import 'package:flutter/foundation.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Isolate worker — colour-based wall segmentation
// ─────────────────────────────────────────────────────────────────────────────

Map<String, dynamic> _colorSegmentIsolate(Map<String, dynamic> args) {
  final Uint8List imageBytes = args['imageBytes'];
  final int maskSize = args['maskSize'];

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
  final List<_LabColor> samples = [];

  void sampleZone(int x0, int x1, int y0, int y1) {
    for (int y = y0; y < y1; y++) {
      for (int x = x0; x < x1; x++) {
        final p = small.getPixel(x, y);
        samples.add(_rgbToLab(p.r.toInt(), p.g.toInt(), p.b.toInt()));
      }
    }
  }

  final int sampleH = (h * 0.20).toInt().clamp(4, h);
  sampleZone(0, (w * 0.12).toInt().clamp(2, w), 0, sampleH);               // top-left
  sampleZone((w * 0.35).toInt(), (w * 0.65).toInt(), 0, sampleH);          // top-center
  sampleZone((w * 0.88).toInt().clamp(0, w - 2), w, 0, sampleH);          // top-right

  if (samples.isEmpty) return {'segments': null, 'coverage': 0.0, 'wallPixels': 0};

  // Median LAB = representative "wall" colour
  final double refL = _median(samples.map((s) => s.l).toList());
  final double refA = _median(samples.map((s) => s.a).toList());
  final double refB = _median(samples.map((s) => s.b).toList());
  final _LabColor refWall = _LabColor(refL, refA, refB);

  // ── Step 2: Classify pixels ───────────────────────────────────────────────
  // Delta-E threshold: 38 is generous for unlit rooms; tighten to 28 if too noisy.
  const double kThreshold = 38.0;

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

  bool get isModelLoaded => _isReady;
  int get maskSize => _kMaskSize;

  /// No model file needed — just marks the service ready immediately.
  Future<void> loadModel() async {
    _isReady = true;
    print('✅ MLService ready — colour-based wall detector (maskSize=$_kMaskSize)');
  }

  /// Returns optimised horizontal-segment list, or null for fallback overlay.
  Future<List<Map<String, double>>?> segmentWall(Uint8List imageBytes) async {
    if (!_isReady) return null;

    try {
      final result = await compute(_colorSegmentIsolate, {
        'imageBytes': imageBytes,
        'maskSize': _kMaskSize,
      });

      final segments = result['segments'] as List<Map<String, double>>?;
      final double coverage = result['coverage'] as double? ?? 0.0;
      final int wallPixels = result['wallPixels'] as int? ?? 0;

      print('✅ Wall detection: $wallPixels px '
          '(${(coverage * 100).toStringAsFixed(1)}%), '
          '${segments?.length ?? 0} segments');

      // If coverage is extremely low (<5%) or suspiciously high (>90%),
      // the sampling zone wasn't ideal — use full-screen fallback overlay.
      if (segments == null || coverage < 0.05 || coverage > 0.90) {
        print('⚠️ Coverage out of range — using fallback overlay.');
        return null;
      }

      return segments;
    } catch (e) {
      print('❌ Wall detection error: $e');
      return null;
    }
  }

  void dispose() {
    _isReady = false;
  }
}
