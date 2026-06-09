/// Shared geometry for the printable rhythm template and the scanner.
///
/// The printed sheet has four QR-style **finder-pattern markers** at the
/// corners of a grid area — three nested squares (black/white/black) whose
/// cross-section reads 1:1:3:1:1, the same registration signature a QR code
/// uses. Each row of the grid is one measure of [cols] sixteenth-note cells;
/// the user colours a cell to mark a stroke (a hit) and leaves it blank for a
/// rest.
///
/// Both the generator (`tool/generate_template.dart`) and the scanner
/// (`RhythmScannerService`) import these constants so the layout they draw and
/// the layout they read stay in lockstep. The scanner cannot infer the number
/// of rows from four corner markers alone, so [rows] is a fixed contract here.
class ScanTemplate {
  ScanTemplate._();

  /// Number of measures (rows) on one printed sheet.
  static const int rows = 8;

  /// Sixteenth-note cells per beat — one beat packs into a [0,15] pattern,
  /// matching the app's `QuarterModel`.
  static const int cellsPerBeat = 4;

  /// Beats per measure (row).
  static const int beatsPerRow = 4;

  /// Total cells per row: a full bar of sixteenth notes.
  static const int cols = cellsPerBeat * beatsPerRow; // 16

  // --- Generator page geometry (pixels) ---
  static const int pageWidth = 1000;
  static const int pageHeight = 1400;
  static const int margin = 90;

  /// Extra space reserved at the top of the page for the title/instructions,
  /// so the grid (and its top markers) sit clear of the header text.
  static const int headerSpace = 70;

  /// Side length of each corner finder pattern (the outer black square).
  static const int markerSize = 70;

  /// One "module" of the finder pattern. The pattern is 7 modules wide, drawn
  /// as nested squares 7×7 black, 5×5 white, 3×3 black — so a line across its
  /// middle reads 1:1:3:1:1 (one module : one : three : one : one).
  static double get markerModule => markerSize / 7;

  /// The grid's bounding quadrilateral is defined by the marker *centroids*,
  /// which sit half a marker in from the page margin.
  static double get gridLeft => (margin + markerSize / 2);
  static double get gridTop => (margin + headerSpace + markerSize / 2);
  static double get gridRight => (pageWidth - margin - markerSize / 2);
  static double get gridBottom => (pageHeight - margin - markerSize / 2);

  // --- Classification parameters (shared) ---

  /// When sampling a cell we only look at its central fraction, ignoring the
  /// printed outline and any overlap with a corner marker.
  static const double cellInnerFraction = 0.6;

  /// A cell is read as a stroke (bit 1) when at least this fraction of its
  /// sampled inner region is dark after thresholding.
  static const double fillThreshold = 0.5;
}
