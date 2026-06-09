// Round-trip check for the rhythm scanner, runnable without an emulator:
//
//   dart run tool/test_scan_roundtrip.dart
//
// Synthesises a filled sheet for known measures, optionally warps it to
// simulate a tilted photo, scans it back, and asserts the decode matches.
//
// Each measure is [beatsPerRow] beat patterns (0–15); the sheet draws one
// measure per row across [cols] sixteenth-note cells.

// ignore_for_file: avoid_print

import 'dart:math' as math;

import 'package:image/image.dart' as img;
import 'package:on_beat/services/rhythm_scanner_service.dart';
import 'package:on_beat/services/scan_template.dart';

/// Builds a sheet image encoding [measures] (one measure per row).
/// [warp] shifts the corners to fake perspective/tilt (0 = perfectly flat).
/// [clutter] drops dark blobs near the image corners — the kind of shadow or
/// paper-edge junk that fooled the old "darkest extreme pixel" detector.
img.Image buildFilledSheet(List<List<int>> measures,
    {double warp = 0, bool clutter = false}) {
  final image = img.Image(
    width: ScanTemplate.pageWidth,
    height: ScanTemplate.pageHeight,
  );
  img.fill(image, color: img.ColorRgb8(255, 255, 255));

  if (clutter) {
    final junk = img.ColorRgb8(30, 30, 30);
    // A shadow wedge hugging the very top-left corner, and a stray blob beyond
    // the bottom-right marker — both more "extreme" than the real finders.
    img.fillRect(image, x1: 0, y1: 0, x2: 60, y2: 240, color: junk);
    img.fillRect(image, x1: 0, y1: 0, x2: 240, y2: 40, color: junk);
    img.fillCircle(image,
        x: ScanTemplate.pageWidth - 20,
        y: ScanTemplate.pageHeight - 20,
        radius: 36,
        color: junk);
  }

  final left = ScanTemplate.gridLeft;
  final top = ScanTemplate.gridTop;
  final right = ScanTemplate.gridRight;
  final bottom = ScanTemplate.gridBottom;
  final dx = warp * (right - left);

  final tl = math.Point(left + dx, top);
  final tr = math.Point(right + dx, top);
  final br = math.Point(right - dx, bottom);
  final bl = math.Point(left - dx, bottom);

  math.Point<double> bilerp(double u, double v) {
    final topX = tl.x + (tr.x - tl.x) * u;
    final topY = tl.y + (tr.y - tl.y) * u;
    final botX = bl.x + (br.x - bl.x) * u;
    final botY = bl.y + (br.y - bl.y) * u;
    return math.Point(topX + (botX - topX) * v, topY + (botY - topY) * v);
  }

  for (var r = 0; r < measures.length; r++) {
    for (var b = 0; b < ScanTemplate.beatsPerRow; b++) {
      final pattern = measures[r][b];
      for (var i = 0; i < ScanTemplate.cellsPerBeat; i++) {
        final bit = (pattern >> (ScanTemplate.cellsPerBeat - 1 - i)) & 1;
        if (bit == 0) continue;
        final c = b * ScanTemplate.cellsPerBeat + i;
        const inner = 0.7; // fill 70% of the cell, like a real colouring-in
        final pad = (1 - inner) / 2;
        final u0 = (c + pad) / ScanTemplate.cols;
        final u1 = (c + 1 - pad) / ScanTemplate.cols;
        final v0 = (r + pad) / ScanTemplate.rows;
        final v1 = (r + 1 - pad) / ScanTemplate.rows;
        for (var t = 0.0; t <= 1.0; t += 0.02) {
          final vv = v0 + (v1 - v0) * t;
          final pL = bilerp(u0, vv);
          final pR = bilerp(u1, vv);
          img.drawLine(image,
              x1: pL.x.round(),
              y1: pL.y.round(),
              x2: pR.x.round(),
              y2: pR.y.round(),
              color: img.ColorRgb8(20, 20, 20),
              thickness: 2);
        }
      }
    }
  }

  // Finder patterns: nested 7×7 black, 5×5 white, 3×3 black squares.
  final m = ScanTemplate.markerModule;
  final black = img.ColorRgb8(0, 0, 0);
  final white = img.ColorRgb8(255, 255, 255);
  void square(math.Point<double> p, double halfModules, img.Color color) =>
      img.fillRect(image,
          x1: (p.x - halfModules * m).round(),
          y1: (p.y - halfModules * m).round(),
          x2: (p.x + halfModules * m).round(),
          y2: (p.y + halfModules * m).round(),
          color: color);
  void marker(math.Point<double> p) {
    square(p, 3.5, black);
    square(p, 2.5, white);
    square(p, 1.5, black);
  }

  marker(tl);
  marker(tr);
  marker(br);
  marker(bl);

  return image;
}

void main() {
  // 8 rows. Rows 3 and 7 left empty (unused lines) — expect them dropped.
  final sheet = <List<int>>[
    [10, 13, 15, 8], // measure 1
    [8, 8, 10, 12], // measure 2
    [15, 1, 2, 4], // measure 3
    [0, 0, 0, 0], // empty row -> dropped
    [9, 6, 5, 3], // measure 4
    [12, 12, 12, 12], // measure 5
    [1, 2, 4, 8], // measure 6
    [0, 0, 0, 0], // empty row -> dropped
  ];
  final expected =
      sheet.where((m) => m.any((p) => p != 0)).toList(growable: false);

  var failures = 0;
  final cases = <(String, double, bool)>[
    ('flat', 0.0, false),
    ('warped (0.04)', 0.04, false),
    ('cluttered', 0.0, true), // shadows/edges that broke the old detector
    ('warped + cluttered', 0.04, true),
  ];
  for (final (label, warp, clutter) in cases) {
    final image = buildFilledSheet(sheet, warp: warp, clutter: clutter);
    final bytes = img.encodePng(image);
    final result = scanRhythmBytes(bytes);

    final got = result.measures;
    final ok = _measuresEq(got, expected);
    print('[$label] otsu=${result.otsuThreshold}/${result.gridThreshold} '
        'corners=${result.corners.map((p) => '(${p.x.toStringAsFixed(0)},${p.y.toStringAsFixed(0)})').join(' ')}');
    print('  expected: $expected');
    print('  got     : $got    ${ok ? 'PASS' : 'FAIL'}');
    if (!ok) {
      failures++;
      for (var r = 0; r < result.fillRatios.length; r++) {
        print('    row $r fill: '
            '${result.fillRatios[r].map((f) => f.toStringAsFixed(2)).join(' ')}');
      }
    }
  }

  print(failures == 0 ? '\nALL PASS ✓' : '\n$failures case(s) FAILED ✗');
}

bool _measuresEq(List<List<int>> a, List<List<int>> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i].length != b[i].length) return false;
    for (var j = 0; j < a[i].length; j++) {
      if (a[i][j] != b[i][j]) return false;
    }
  }
  return true;
}
