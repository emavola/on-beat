// Generates the printable rhythm template PNG.
//
//   dart run tool/generate_template.dart
//
// Output: assets/scan/rhythm_template.png
//
// The sheet has four QR-style finder-pattern markers at the corners of a
// grid. Each row is one measure of four sixteenth-note cells: colour a cell to
// mark a stroke, leave it blank for a rest. The geometry mirrors
// `ScanTemplate` so the scanner reads exactly what this draws.

import 'dart:io';

import 'package:image/image.dart';
import 'package:on_beat/services/scan_template.dart';

void main() {
  final img = Image(
    width: ScanTemplate.pageWidth,
    height: ScanTemplate.pageHeight,
  );

  final white = ColorRgb8(255, 255, 255);
  final black = ColorRgb8(0, 0, 0);
  final gray = ColorRgb8(180, 180, 180);
  final darkGray = ColorRgb8(90, 90, 90);

  fill(img, color: white);

  // Title + instructions.
  drawString(img, 'OnBeat — Rhythm Sheet', font: arial48, x: ScanTemplate.margin, y: 24, color: black);
  drawString(
    img,
    'Colour a box = stroke.  Leave it blank = rest.  Keep the 4 corner squares visible.',
    font: arial24,
    x: ScanTemplate.margin,
    y: 78,
    color: darkGray,
  );

  final left = ScanTemplate.gridLeft;
  final top = ScanTemplate.gridTop;
  final right = ScanTemplate.gridRight;
  final bottom = ScanTemplate.gridBottom;
  final cellW = (right - left) / ScanTemplate.cols;
  final cellH = (bottom - top) / ScanTemplate.rows;

  // Cell outlines (light gray so thresholding treats them as background).
  // Every beat (group of cellsPerBeat cells) gets a darker separator so the
  // user can read the four beats of each measure — cells stay uniformly
  // spaced, which is what the scanner's grid sampling assumes.
  for (var r = 0; r < ScanTemplate.rows; r++) {
    final yTop = (top + r * cellH).round();
    final yBot = (top + (r + 1) * cellH).round();
    for (var c = 0; c < ScanTemplate.cols; c++) {
      final x1 = (left + c * cellW).round();
      final x2 = (left + (c + 1) * cellW).round();
      drawRect(img, x1: x1, y1: yTop, x2: x2, y2: yBot, color: gray, thickness: 2);
    }
    // Darker vertical lines at beat boundaries.
    for (var b = 0; b <= ScanTemplate.beatsPerRow; b++) {
      final x = (left + b * ScanTemplate.cellsPerBeat * cellW).round();
      drawLine(img, x1: x, y1: yTop, x2: x, y2: yBot, color: darkGray, thickness: 3);
    }
    // Row (measure) number to the left of each row.
    drawString(
      img,
      '${r + 1}',
      font: arial24,
      x: (left - 36).round(),
      y: (top + r * cellH + cellH / 2 - 12).round(),
      color: darkGray,
    );
  }

  // Four QR-style finder patterns, centred on the grid corners: nested
  // squares 7×7 black, 5×5 white, 3×3 black. A line across the middle reads
  // 1:1:3:1:1, the signature the scanner hunts for.
  final m = ScanTemplate.markerModule;
  void square(double cx, double cy, double halfModules, dynamic color) =>
      fillRect(
        img,
        x1: (cx - halfModules * m).round(),
        y1: (cy - halfModules * m).round(),
        x2: (cx + halfModules * m).round(),
        y2: (cy + halfModules * m).round(),
        color: color,
      );
  void marker(double cx, double cy) {
    square(cx, cy, 3.5, black); // 7×7 outer black
    square(cx, cy, 2.5, white); // 5×5 white ring
    square(cx, cy, 1.5, black); // 3×3 inner black
  }

  marker(left, top);
  marker(right, top);
  marker(left, bottom);
  marker(right, bottom);

  final outDir = Directory('assets/scan');
  outDir.createSync(recursive: true);
  final outPath = '${outDir.path}/rhythm_template.png';
  File(outPath).writeAsBytesSync(encodePng(img));
  stdout.writeln('Wrote $outPath (${img.width}x${img.height})');
}
