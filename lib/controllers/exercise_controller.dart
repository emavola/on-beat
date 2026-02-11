import 'dart:math';

import '../models/measure_model.dart';
import '../models/quarter_model.dart';
import 'measure_controller.dart';
import 'package:on_beat/services/metronome_service.dart';
import 'package:on_beat/models/quarter_state.dart';

enum ExerciseMode { normal, zen }

class ExerciseController {
  final ExerciseMode mode;
  final Random _random = Random();
  final MetronomeService metronome = MetronomeService();

  static const int maxLives = 3;

  int lives;
  MeasureController? currentMeasureController;

  ExerciseController({required this.mode})
    : lives = mode == ExerciseMode.normal ? maxLives : -1;

  /// Avvia l'esercizio
  Future<void> start(double startTime) async {
    lives = mode == ExerciseMode.normal ? maxLives : -1;
    await metronome.init();
    _startNewMeasure(startTime);
  }

  /// Ferma l'esercizio
  void stop() {
    currentMeasureController?.dispose();
    metronome.dispose();
    currentMeasureController = null;
  }

  bool get isRunning => currentMeasureController != null;

  // -------------------------
  // PRIVATE
  // -------------------------

  void _startNewMeasure(double startTime) {
    final measure = _generateRandomMeasure();

    final controller = MeasureController(
      measure: measure,
      bpm: 100,
      metronome: metronome,
    );

    controller.onMeasureCompleted = (
      List<QuarterState> states,
      double endTime,
    ) {
      _handleMeasureResult(states, endTime);
    };

    controller.onQuarterCompleted = (state) {
      _handleQuarterResult(state);
    };

    currentMeasureController = controller;
    controller.startMeasure(startTime);
  }

  void _handleMeasureResult(List<QuarterState> states, double endTime) {
    _startNewMeasure(endTime);
  }

  void _handleQuarterResult(QuarterState state) {
    if (state == QuarterState.miss && mode == ExerciseMode.normal) {
      lives--;

      if (lives <= 0) {
        stop();
      }
    }
  }

  MeasureModel _generateRandomMeasure() {
    const patterns = [8, 10, 12, 15, 0];

    return MeasureModel(
      List.generate(
        4,
        (_) => QuarterModel.fromPattern(
          patterns[_random.nextInt(patterns.length)],
        ),
      ),
    );
  }
}
