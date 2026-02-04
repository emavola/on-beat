import 'dart:math';

import '../models/measure_model.dart';
import '../models/quarter_model.dart';
import 'measure_controller.dart';
import 'package:on_beat/services/metronome_service.dart';

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
  void start(double startTime) {
    lives = mode == ExerciseMode.normal ? maxLives : -1;
    _startNewMeasure(startTime);
  }

  /// Chiamato quando una battuta finisce
  void onMeasureFinished({required bool success, required double endTime}) {
    if (!success && mode == ExerciseMode.normal) {
      lives--;
    }

    if (mode == ExerciseMode.normal && lives <= 0) {
      stop();
      return;
    }

    _startNewMeasure(endTime);
  }

  /// Ferma l'esercizio (game over o stop manuale)
  void stop() {
    currentMeasureController = null;
  }

  bool get isRunning => currentMeasureController != null;

  // -------------------------
  // PRIVATE
  // -------------------------

  void _startNewMeasure(double startTime) {
    final measure = _generateRandomMeasure();
    currentMeasureController = MeasureController(
      measure: measure,
      bpm: 100,
      metronome: metronome,
    );
    currentMeasureController!.startMeasure(startTime);
  }

  /// GENERAZIONE RANDOM DELLA BATTUTA
  MeasureModel _generateRandomMeasure() {
    // pattern disponibili (decimali!)
    // 8  = 1000 (quarto)
    // 10 = 1010 (due ottavi)
    // 12 = 1100 (ottavo + pausa)
    // 15 = 1111 (sedicesimi)
    // 0  = terzina
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
