class QuarterModel {
  /// 0     -> terzina
  /// 1..15 -> pattern binario su 4 sedicesimi
  final int pattern;

  final String assetPath;

  const QuarterModel._({required this.pattern, required this.assetPath});

  factory QuarterModel.fromPattern(int pattern) {
    assert(pattern >= 0 && pattern <= 15);

    return QuarterModel._(
      pattern: pattern,
      assetPath: 'assets/figures/$pattern.png',
    );
  }

  List<double> get expectedHits {
    // TERZINA
    if (pattern == 0) {
      return const [0.0, 1 / 3, 2 / 3];
    }

    final hits = <double>[];

    for (int i = 0; i < 4; i++) {
      final bit = (pattern >> (3 - i)) & 1;
      if (bit == 1) {
        hits.add(i / 4);
      }
    }

    return hits;
  }
}
