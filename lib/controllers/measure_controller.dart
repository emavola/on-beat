import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/measure_model.dart';
import '../models/quarter_model.dart';
import '../models/quarter_state.dart';
import '../services/metronome_service.dart';
import '../services/settings_service.dart';

class MeasureController extends ChangeNotifier {
  final MeasureModel measure;
  final double bpm;
  final MetronomeService metronome;

  late final double quarterDurationMs;
  Timer? _timer;

  bool _isDisposed = false;

  int currentQuarterIndex = 0;
  double? startTime;
  double? quarterStartTime;

  final List<double> currentHits = [];
  final List<QuarterState> quarterStates;

  MeasureController({
    required this.measure,
    required this.bpm,
    required this.metronome,
  }) : quarterStates = List.filled(
         measure.quarters.length,
         QuarterState.neutral,
       ) {
    quarterDurationMs = 60000 / bpm;
  }

  void Function(QuarterState state)? onQuarterCompleted;
  void Function(List<QuarterState> states, double endTime)? onMeasureCompleted;

  /// Inizia la battuta
  void startMeasure(double startTimeMs) {
    startTime = startTimeMs;
    currentQuarterIndex = 0;
    metronome.reset();

    _startQuarter(startTimeMs);
    metronome.play(); // primo click

    _scheduleNextQuarter();
  }

  void _scheduleNextQuarter() {
    final nextBoundary =
        startTime! + (currentQuarterIndex + 1) * quarterDurationMs;
    final now = DateTime.now().millisecondsSinceEpoch.toDouble();
    final delayMs = (nextBoundary - now).clamp(0.0, quarterDurationMs);

    _timer?.cancel();
    _timer = Timer(
      Duration(milliseconds: delayMs.round()),
      _onQuarterBoundary,
    );
  }

  void _onQuarterBoundary() {
    final now = DateTime.now().millisecondsSinceEpoch.toDouble();
    nextQuarter(now);
    if (!isMeasureFinished) {
      metronome.play();
      _scheduleNextQuarter();
    }
  }

  /// Riceve un colpo dall'input
  void onHit(double timestamp) {
    if (isMeasureFinished) return;
    currentHits.add(timestamp);
  }

  /// Passa al prossimo quarter
  void nextQuarter(double endTime) {
    _evaluateCurrentQuarter();
    onQuarterCompleted?.call(quarterStates[currentQuarterIndex]);

    currentQuarterIndex++;
    currentHits.clear();
    if (!_isDisposed) notifyListeners();

    if (currentQuarterIndex < measure.quarters.length) {
      _startQuarter(endTime);
    } else {
      quarterStartTime = null;
      _timer?.cancel();
      onMeasureCompleted?.call(List.unmodifiable(quarterStates), endTime);
    }
  }

  void _evaluateCurrentQuarter() {
    final quarter = currentQuarter;
    if (quarter == null || quarterStartTime == null) return;

    const double perfectWindow = 80.0;
    const double okWindow = 160.0;

    // Compensate for audio output latency: configurable in Settings.
    final double audioLatencyMs = SettingsService().latencyMs;

    final List<double> expectedTimes =
        quarter.expectedHits
            .map((fraction) =>
                quarterStartTime! +
                fraction * quarterDurationMs +
                audioLatencyMs)
            .toList();

    int matchedPerfect = 0;
    int matchedOk = 0;

    final remainingHits = List<double>.from(currentHits);

    for (final expected in expectedTimes) {
      double? bestDelta;
      double? bestHit;

      for (final hit in remainingHits) {
        final delta = (hit - expected).abs();

        if (bestDelta == null || delta < bestDelta) {
          bestDelta = delta;
          bestHit = hit;
        }
      }

      if (bestDelta == null) {
        continue;
      }

      if (bestDelta <= perfectWindow) {
        matchedPerfect++;
        remainingHits.remove(bestHit);
      } else if (bestDelta <= okWindow) {
        matchedOk++;
        remainingHits.remove(bestHit);
      }
    }

    final totalExpected = expectedTimes.length;
    final bool hasExtraHits = remainingHits.isNotEmpty;

    QuarterState result;
    if (hasExtraHits) {
      result = QuarterState.miss;
    } else if (matchedPerfect == totalExpected) {
      result = QuarterState.perfect;
    } else if (matchedPerfect + matchedOk == totalExpected) {
      result = QuarterState.ok;
    } else {
      result = QuarterState.miss;
    }

    quarterStates[currentQuarterIndex] = result;
  }

  QuarterModel? get currentQuarter {
    if (currentQuarterIndex < measure.quarters.length) {
      return measure.quarters[currentQuarterIndex];
    }
    return null;
  }

  bool get isMeasureFinished => currentQuarterIndex >= measure.quarters.length;

  void _startQuarter(double startTime) {
    quarterStartTime = startTime;
    currentHits.clear();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _timer?.cancel();
    super.dispose();
  }
}
