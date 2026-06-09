import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'scan_template.dart';

/// Result of scanning a printed rhythm sheet.
///
/// Carries both the decoded data and PNG previews of each processing stage so
/// the UI can show the pipeline at work (and so they double as report figures).
class ScanResult {
  /// Working image size after downscaling (the size all coordinates refer to).
  final int width;
  final int height;

  /// Coarse global threshold from Otsu's method (0–255), used to find markers.
  final int otsuThreshold;

  /// Refined threshold from re-running Otsu over only the pixels inside the
  /// detected grid quad (0–255). This is the cut the cells are classified with.
  final int gridThreshold;

  /// Detected marker centroids, in order: top-left, top-right, bottom-right,
  /// bottom-left.
  final List<math.Point<double>> corners;

  /// Per-cell bit (1 = stroke, 0 = rest), indexed [row][col].
  final List<List<int>> cells;

  /// Per-cell fill ratio (0–1) used for the decision, indexed [row][col].
  final List<List<double>> fillRatios;

  /// Stage previews, PNG-encoded.
  final Uint8List grayscalePng;
  final Uint8List binaryPng;
  final Uint8List overlayPng;

  ScanResult({
    required this.width,
    required this.height,
    required this.otsuThreshold,
    required this.gridThreshold,
    required this.corners,
    required this.cells,
    required this.fillRatios,
    required this.grayscalePng,
    required this.binaryPng,
    required this.overlayPng,
  });

  /// Every row decoded into its [ScanTemplate.beatsPerRow] beat patterns
  /// (each 0–15), MSB-first per beat. Includes empty rows.
  List<List<int>> get rawMeasures =>
      cells.map(_packRow).toList(growable: false);

  /// Rows that contain at least one stroke — each a ready-to-play measure of
  /// beat patterns. Fully empty rows are dropped (unused lines on the sheet).
  List<List<int>> get measures => rawMeasures
      .where((m) => m.any((p) => p != 0))
      .toList(growable: false);

  /// Splits one row's cells into beats and packs each beat into a pattern.
  static List<int> _packRow(List<int> row) {
    final out = <int>[];
    for (var b = 0; b < ScanTemplate.beatsPerRow; b++) {
      var value = 0;
      for (var i = 0; i < ScanTemplate.cellsPerBeat; i++) {
        final bit = row[b * ScanTemplate.cellsPerBeat + i] & 1;
        value |= bit << (ScanTemplate.cellsPerBeat - 1 - i);
      }
      out.add(value);
    }
    return out;
  }
}

/// Reads a hand-coloured [ScanTemplate] sheet into rhythm patterns.
///
/// The pipeline is deliberately classic, stage by stage:
///   1. decode + downscale       — bounded work, consistent coordinates
///   2. grayscale (luma)         — drop colour, keep light/dark
///   3. Otsu threshold (coarse)  — global histogram split, enough to binarise
///   4. finder detection         — locate the four 1:1:3:1:1 corner patterns
///   5. Otsu threshold (refined) — re-run on just the pixels inside the grid,
///                                 so background/shadows can't skew the cut
///   6. segmentation             — bilinear grid mapping inside the markers
///   7. fill ratio + classify    — dark-pixel density per cell -> bit
///   8. pack                     — four bits per row -> pattern 1–15
///
/// [scanRhythmBytes] is a top-level function with no Flutter dependencies, so
/// it can run inside `compute()` off the UI thread (and in plain-Dart tests).
class RhythmScannerService {
  /// Decode and scan [bytes] (PNG/JPEG). Throws [ScanException] on failure.
  Future<ScanResult> scan(Uint8List bytes) async => scanRhythmBytes(bytes);
}

class ScanException implements Exception {
  final String message;
  ScanException(this.message);
  @override
  String toString() => 'ScanException: $message';
}

/// Longest side of the working image after downscaling. Bounds the cost of the
/// pixel loops and makes timing independent of camera resolution.
const int _maxWorkingDimension = 1200;

ScanResult scanRhythmBytes(Uint8List bytes) {
  // --- 1. Decode + downscale -------------------------------------------------
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    throw ScanException('Could not decode the image.');
  }
  final image = (decoded.width > _maxWorkingDimension ||
          decoded.height > _maxWorkingDimension)
      ? img.copyResize(
          decoded,
          width: decoded.width >= decoded.height ? _maxWorkingDimension : null,
          height: decoded.height > decoded.width ? _maxWorkingDimension : null,
        )
      : decoded;

  final w = image.width;
  final h = image.height;

  // --- 2. Grayscale (luma) ---------------------------------------------------
  final gray = Uint8List(w * h);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final p = image.getPixel(x, y);
      // Rec. 601 luma.
      final l = 0.299 * p.r + 0.587 * p.g + 0.114 * p.b;
      gray[y * w + x] = l.round().clamp(0, 255);
    }
  }

  // --- 3. Otsu threshold (coarse, global) ------------------------------------
  // Good enough to binarise for marker detection: the high-contrast finder
  // patterns survive almost any reasonable cut.
  final threshold = _otsuThreshold(gray);
  final coarse = Uint8List(w * h);
  for (var i = 0; i < gray.length; i++) {
    coarse[i] = gray[i] <= threshold ? 1 : 0;
  }

  // --- 4. Marker detection ---------------------------------------------------
  final corners = _detectCorners(coarse, w, h);

  // --- 5. Otsu threshold (refined, inside the grid) --------------------------
  // Re-run Otsu over only the pixels inside the detected grid quad, so a dark
  // background, shadows or paper edges *outside* the sheet can't skew the cut.
  // This is the ink-vs-paper threshold the cells are actually classified with.
  // Binary mask: 1 where dark (ink), 0 where light (paper); inclusive because
  // Otsu's threshold is the upper bound of the dark class.
  final gridThreshold = _otsuInsideQuad(gray, w, h, corners) ?? threshold;
  final dark = Uint8List(w * h);
  for (var i = 0; i < gray.length; i++) {
    dark[i] = gray[i] <= gridThreshold ? 1 : 0;
  }

  // --- 6. Segmentation, fill ratio, classify ---------------------------------
  final tl = corners[0], tr = corners[1], br = corners[2], bl = corners[3];

  math.Point<double> bilerp(double u, double v) {
    final topX = tl.x + (tr.x - tl.x) * u;
    final topY = tl.y + (tr.y - tl.y) * u;
    final botX = bl.x + (br.x - bl.x) * u;
    final botY = bl.y + (br.y - bl.y) * u;
    return math.Point(topX + (botX - topX) * v, topY + (botY - topY) * v);
  }

  const samples = 18; // NxN sample grid per cell
  final pad = (1 - ScanTemplate.cellInnerFraction) / 2;
  final cells = <List<int>>[];
  final fills = <List<double>>[];

  for (var r = 0; r < ScanTemplate.rows; r++) {
    final rowBits = <int>[];
    final rowFill = <double>[];
    for (var c = 0; c < ScanTemplate.cols; c++) {
      // Cell's normalised span, shrunk to its inner region.
      final u0 = (c + pad) / ScanTemplate.cols;
      final u1 = (c + 1 - pad) / ScanTemplate.cols;
      final v0 = (r + pad) / ScanTemplate.rows;
      final v1 = (r + 1 - pad) / ScanTemplate.rows;

      var darkCount = 0;
      var total = 0;
      for (var sy = 0; sy < samples; sy++) {
        final v = v0 + (v1 - v0) * (sy + 0.5) / samples;
        for (var sx = 0; sx < samples; sx++) {
          final u = u0 + (u1 - u0) * (sx + 0.5) / samples;
          final p = bilerp(u, v);
          final px = p.x.round();
          final py = p.y.round();
          if (px < 0 || px >= w || py < 0 || py >= h) continue;
          total++;
          if (dark[py * w + px] == 1) darkCount++;
        }
      }
      final ratio = total == 0 ? 0.0 : darkCount / total;
      rowFill.add(ratio);
      rowBits.add(ratio >= ScanTemplate.fillThreshold ? 1 : 0);
    }
    cells.add(rowBits);
    fills.add(rowFill);
  }

  // --- Stage previews --------------------------------------------------------
  final grayscalePng = _grayToPng(gray, w, h);
  final binaryPng = _binaryToPng(dark, w, h);
  final overlayPng = _overlayPng(image, corners, bilerp, cells, pad);

  return ScanResult(
    width: w,
    height: h,
    otsuThreshold: threshold,
    gridThreshold: gridThreshold,
    corners: corners,
    cells: cells,
    fillRatios: fills,
    grayscalePng: grayscalePng,
    binaryPng: binaryPng,
    overlayPng: overlayPng,
  );
}

/// Otsu's method over the whole grayscale image.
int _otsuThreshold(Uint8List gray) {
  final hist = List<int>.filled(256, 0);
  for (final g in gray) {
    hist[g]++;
  }
  return _otsuFromHistogram(hist, gray.length);
}

/// Otsu's method over only the pixels inside the grid quad [q] (TL,TR,BR,BL).
///
/// Uses a point-in-polygon test rather than the quad's bounding box, so a
/// tilted grid doesn't drag in the background triangles at its corners — that
/// is the whole reason for the second pass. Returns null if the quad is empty.
int? _otsuInsideQuad(
    Uint8List gray, int w, int h, List<math.Point<double>> q) {
  var minX = w - 1, maxX = 0, minY = h - 1, maxY = 0;
  for (final p in q) {
    minX = math.min(minX, p.x.floor());
    maxX = math.max(maxX, p.x.ceil());
    minY = math.min(minY, p.y.floor());
    maxY = math.max(maxY, p.y.ceil());
  }
  minX = minX.clamp(0, w - 1);
  maxX = maxX.clamp(0, w - 1);
  minY = minY.clamp(0, h - 1);
  maxY = maxY.clamp(0, h - 1);

  final hist = List<int>.filled(256, 0);
  var total = 0;
  for (var y = minY; y <= maxY; y++) {
    final row = y * w;
    for (var x = minX; x <= maxX; x++) {
      if (_inQuad(x.toDouble(), y.toDouble(), q)) {
        hist[gray[row + x]]++;
        total++;
      }
    }
  }
  if (total == 0) return null;
  return _otsuFromHistogram(hist, total);
}

/// True when point ([px],[py]) lies inside the convex quad [q]: it must sit on
/// the same side of all four edges.
bool _inQuad(double px, double py, List<math.Point<double>> q) {
  var pos = false, neg = false;
  for (var i = 0; i < 4; i++) {
    final a = q[i], b = q[(i + 1) % 4];
    final cross = (b.x - a.x) * (py - a.y) - (b.y - a.y) * (px - a.x);
    if (cross > 1e-9) {
      pos = true;
    } else if (cross < -1e-9) {
      neg = true;
    }
    if (pos && neg) return false;
  }
  return true;
}

/// Pick the threshold that maximises between-class variance of [hist]
/// ([total] = pixel count). Shared by both Otsu passes.
int _otsuFromHistogram(List<int> hist, int total) {
  if (total == 0) return 127;
  var sum = 0.0;
  for (var i = 0; i < 256; i++) {
    sum += i * hist[i];
  }

  var sumB = 0.0;
  var wB = 0;
  var maxVar = -1.0;
  var threshold = 127;
  for (var t = 0; t < 256; t++) {
    wB += hist[t];
    if (wB == 0) continue;
    final wF = total - wB;
    if (wF == 0) break;
    sumB += t * hist[t];
    final mB = sumB / wB;
    final mF = (sum - sumB) / wF;
    final between = wB * wF * (mB - mF) * (mB - mF);
    if (between > maxVar) {
      maxVar = between;
      threshold = t;
    }
  }
  return threshold;
}

/// One detected (or partially detected) finder pattern, accumulating the
/// votes of every scanline that crossed it.
class _Finder {
  double x;
  double y;
  double moduleSize;
  int count;
  _Finder(this.x, this.y, this.moduleSize, this.count);
}

int _sum(List<int> s) => s[0] + s[1] + s[2] + s[3] + s[4];

/// True when five consecutive runs match the QR finder ratio 1:1:3:1:1,
/// allowing each module to wobble by ±50% (blur, tilt, ink spread).
bool _finderRatio(List<int> s) {
  final total = _sum(s);
  if (total < 7) return false;
  final module = total / 7.0;
  final tol = module / 2.0;
  return (s[0] - module).abs() < tol &&
      (s[1] - module).abs() < tol &&
      (s[2] - 3 * module).abs() < 3 * tol &&
      (s[3] - module).abs() < tol &&
      (s[4] - module).abs() < tol;
}

/// Centre of the middle (3-module) run, given the index just past run 5.
double _centerFromEnd(List<int> s, int end) => end - s[4] - s[3] - s[2] / 2.0;

/// Locate the four corner finder patterns.
///
/// Markers are detected by *shape*, not by position: we scan every row for the
/// 1:1:3:1:1 dark/light signature, confirm each hit holds vertically and
/// horizontally (so shadows, paper edges and text — which match at most one
/// axis — are rejected), then cluster the surviving hits. One real finder is
/// crossed by many scanlines and so collects many votes; stragglers don't.
List<math.Point<double>> _detectCorners(Uint8List dark, int w, int h) {
  final found = <_Finder>[];
  var anyDark = false;

  for (var y = 0; y < h; y++) {
    final row = y * w;
    final s = [0, 0, 0, 0, 0];
    var state = 0; // even = counting dark run, odd = counting light run
    for (var x = 0; x < w; x++) {
      final isDark = dark[row + x] == 1;
      if (isDark) anyDark = true;
      if (isDark) {
        if ((state & 1) == 1) state++; // light -> dark transition
        s[state]++;
      } else {
        if ((state & 1) == 0) {
          if (state == 4) {
            // Saw dark-light-dark-light-dark; this light pixel closes it.
            if (_finderRatio(s)) _tryConfirm(dark, w, h, s, x, y, found);
            // Slide the window back two runs to catch overlapping patterns.
            s[0] = s[2];
            s[1] = s[3];
            s[2] = s[4];
            s[3] = 1;
            s[4] = 0;
            state = 3;
          } else {
            state++;
            s[state]++;
          }
        } else {
          s[state]++;
        }
      }
    }
    // Pattern that runs into the right edge of the row.
    if (state == 4 && _finderRatio(s)) _tryConfirm(dark, w, h, s, w, y, found);
  }

  if (!anyDark) {
    throw ScanException('No dark marks found — is the sheet in frame?');
  }

  // Prefer patterns confirmed by several scanlines; fall back if too strict.
  var finders = found.where((f) => f.count >= 2).toList();
  if (finders.length < 4) finders = List.of(found);
  finders.sort((a, b) => b.count.compareTo(a.count));
  if (finders.length < 4) {
    throw ScanException(
        'Found ${finders.length} of 4 corner patterns. Make sure all four '
        'corner squares are sharp and fully in frame.');
  }

  // Keep the four strongest and order them TL, TR, BR, BL.
  finders = finders.take(4).toList()..sort((a, b) => a.y.compareTo(b.y));
  final top = finders.sublist(0, 2)..sort((a, b) => a.x.compareTo(b.x));
  final bot = finders.sublist(2, 4)..sort((a, b) => a.x.compareTo(b.x));
  final corners = [
    math.Point(top[0].x, top[0].y), // TL
    math.Point(top[1].x, top[1].y), // TR
    math.Point(bot[1].x, bot[1].y), // BR
    math.Point(bot[0].x, bot[0].y), // BL
  ];

  // Sanity: the four points should span a meaningful area.
  final spanX = (corners[1].x - corners[0].x).abs();
  final spanY = (corners[3].y - corners[0].y).abs();
  if (spanX < w * 0.2 || spanY < h * 0.2) {
    throw ScanException(
        'Corner patterns found too close together. Frame the whole sheet.');
  }
  return corners;
}

/// Confirms a horizontal hit by re-checking the 1:1:3:1:1 signature down the
/// column and back across the row, then records the refined centre.
void _tryConfirm(Uint8List dark, int w, int h, List<int> s, int endX, int y,
    List<_Finder> found) {
  final centerX = _centerFromEnd(s, endX);
  final maxCount = s[2];
  final cy = _crossCheck(dark, w, h, centerX.round(), y, maxCount, vertical: true);
  if (cy == null) return;
  final cx =
      _crossCheck(dark, w, h, cy.round(), centerX.round(), maxCount, vertical: false);
  if (cx == null) return;
  _addOrMerge(found, cx, cy, _sum(s) / 7.0);
}

/// Walks outward from a seed along one axis, measuring the five runs centred on
/// it, and returns the refined centre coordinate if they match 1:1:3:1:1.
///
/// When [vertical] is true [line] is the column x and [start] the seed y;
/// otherwise [line] is the row y and [start] the seed x. [maxCount] bounds the
/// outer runs so a runaway region can't masquerade as a pattern.
double? _crossCheck(Uint8List dark, int w, int h, int line, int start,
    int maxCount,
    {required bool vertical}) {
  final limit = vertical ? h : w;
  bool isDark(int p) =>
      vertical ? dark[p * w + line] == 1 : dark[line * w + p] == 1;

  final s = [0, 0, 0, 0, 0];
  var p = start;
  // Centre run, expanding up/left.
  while (p >= 0 && isDark(p)) {
    s[2]++;
    p--;
  }
  if (p < 0) return null;
  while (p >= 0 && !isDark(p) && s[1] <= maxCount) {
    s[1]++;
    p--;
  }
  if (p < 0 || s[1] > maxCount) return null;
  while (p >= 0 && isDark(p) && s[0] <= maxCount) {
    s[0]++;
    p--;
  }
  if (s[0] > maxCount) return null;

  // Centre run, expanding down/right.
  p = start + 1;
  while (p < limit && isDark(p)) {
    s[2]++;
    p++;
  }
  if (p >= limit) return null;
  while (p < limit && !isDark(p) && s[3] < maxCount) {
    s[3]++;
    p++;
  }
  if (p >= limit || s[3] >= maxCount) return null;
  while (p < limit && isDark(p) && s[4] < maxCount) {
    s[4]++;
    p++;
  }
  if (s[4] >= maxCount) return null;

  if (!_finderRatio(s)) return null;
  return _centerFromEnd(s, p);
}

/// Adds a confirmed centre, merging it into a nearby cluster (same finder hit
/// by another scanline) so each real pattern ends up as one weighted point.
void _addOrMerge(List<_Finder> found, double x, double y, double moduleSize) {
  for (final f in found) {
    if ((f.x - x).abs() <= f.moduleSize && (f.y - y).abs() <= f.moduleSize) {
      final n = f.count + 1;
      f.x = (f.x * f.count + x) / n;
      f.y = (f.y * f.count + y) / n;
      f.moduleSize = (f.moduleSize * f.count + moduleSize) / n;
      f.count = n;
      return;
    }
  }
  found.add(_Finder(x, y, moduleSize, 1));
}

img.Image _grayToImage(Uint8List gray, int w, int h) {
  final out = img.Image(width: w, height: h);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final g = gray[y * w + x];
      out.setPixelRgb(x, y, g, g, g);
    }
  }
  return out;
}

Uint8List _grayToPng(Uint8List gray, int w, int h) =>
    img.encodePng(_grayToImage(gray, w, h));

Uint8List _binaryToPng(Uint8List dark, int w, int h) {
  final out = img.Image(width: w, height: h);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final v = dark[y * w + x] == 1 ? 0 : 255;
      out.setPixelRgb(x, y, v, v, v);
    }
  }
  return img.encodePng(out);
}

/// Draws detected corners and per-cell decisions over the original image.
Uint8List _overlayPng(
  img.Image base,
  List<math.Point<double>> corners,
  math.Point<double> Function(double u, double v) bilerp,
  List<List<int>> cells,
  double pad,
) {
  final out = base.clone();
  final green = img.ColorRgb8(40, 200, 90);
  final red = img.ColorRgb8(230, 70, 70);
  final blue = img.ColorRgb8(40, 120, 255);

  // Cell outlines, tinted by decision.
  for (var r = 0; r < ScanTemplate.rows; r++) {
    for (var c = 0; c < ScanTemplate.cols; c++) {
      final u0 = (c + pad) / ScanTemplate.cols;
      final u1 = (c + 1 - pad) / ScanTemplate.cols;
      final v0 = (r + pad) / ScanTemplate.rows;
      final v1 = (r + 1 - pad) / ScanTemplate.rows;
      final p00 = bilerp(u0, v0);
      final p10 = bilerp(u1, v0);
      final p11 = bilerp(u1, v1);
      final p01 = bilerp(u0, v1);
      final color = cells[r][c] == 1 ? green : red;
      void line(math.Point<double> a, math.Point<double> b) => img.drawLine(
            out,
            x1: a.x.round(),
            y1: a.y.round(),
            x2: b.x.round(),
            y2: b.y.round(),
            color: color,
            thickness: 3,
          );
      line(p00, p10);
      line(p10, p11);
      line(p11, p01);
      line(p01, p00);
    }
  }

  // Corner markers.
  for (final p in corners) {
    img.fillCircle(out, x: p.x.round(), y: p.y.round(), radius: 10, color: blue);
  }
  return img.encodePng(out);
}
