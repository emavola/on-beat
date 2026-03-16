import 'dart:collection';
import 'dart:math';

import 'package:flutter/material.dart';

import '../models/measure_model.dart';
import '../models/quarter_model.dart';
import 'measure_controller.dart';
import 'package:on_beat/services/metronome_service.dart';
import 'package:on_beat/models/quarter_state.dart';

enum ExerciseMode { normal, zen }

enum ExerciseDifficulty {
  easy,
  medium,
  hard;

  List<int> get patterns => switch (this) {
        ExerciseDifficulty.easy => const [8, 10, 12, 15],
        ExerciseDifficulty.medium => const [8, 10, 12, 15, 0, 9, 13, 14, 11, 7],
        ExerciseDifficulty.hard => const [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15],
      };
}

class ExerciseController extends ChangeNotifier {
  final ExerciseMode mode;
  final ExerciseDifficulty difficulty;
  final Random _random = Random();
  final MetronomeService metronome = MetronomeService();
  Queue<MeasureModel> visibleMeasure = Queue();
  bool isFisrtMeasure = true;
  final int queueLength = 4;

  static const int maxLives = 10;

  int lives;
  MeasureController? currentMeasureController;

  /// Snapshot of the last completed measure's quarter states.
  /// Set before [_startNewMeasure] so the UI can capture it at transition time.
  List<QuarterState>? lastCompletedStates;

  ExerciseController({
    required this.mode,
    this.difficulty = ExerciseDifficulty.easy,
  }) : lives = mode == ExerciseMode.normal ? maxLives : -1;

  /// Avvia l'esercizio — prepara il controller ma non avvia il timer.
  /// Chiamare [beginTiming] dopo che il primo frame è stato renderizzato.
  Future<void> start() async {
    lives = mode == ExerciseMode.normal ? maxLives : -1;
    visibleMeasure.clear();
    isFisrtMeasure = true;
    await metronome.init();
    _initRandomMeasure();
    _startNewMeasure(0, startTiming: false);
  }

  /// Avvia effettivamente il timer e il primo click del metronomo.
  /// Va chiamato dopo [start], una volta che la UI è stata renderizzata.
  void beginTiming() {
    final startTime = DateTime.now().millisecondsSinceEpoch.toDouble();
    currentMeasureController?.startMeasure(startTime);
  }

  /// Ferma l'esercizio
  void stop() {
    print("[exercise controller] - stop");
    metronome.dispose();
    currentMeasureController?.removeListener(notifyListeners);
    currentMeasureController?.dispose();
    currentMeasureController = null;
    notifyListeners();
  }

  bool get isRunning => currentMeasureController != null;

  MeasureModel getCurrentMeasure() => visibleMeasure.first;

  // -------------------------
  // PRIVATE
  // -------------------------

  void _startNewMeasure(double startTime, {bool startTiming = true}) {

    currentMeasureController?.removeListener(notifyListeners);
    currentMeasureController?.dispose();
    currentMeasureController = null;

    if (isFisrtMeasure) {
      isFisrtMeasure = false;
    } else {
      _addMeasure(_generateRandomMeasure());
    }

    final measure = visibleMeasure.first;

    final controller = MeasureController(
      measure: measure,
      bpm: 60,
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
    controller.addListener(notifyListeners);
    notifyListeners();

    if (startTiming) {
      controller.startMeasure(startTime);
    }
  }

  void _handleMeasureResult(List<QuarterState> states, double endTime) {
    if (mode == ExerciseMode.normal && lives <= 0) {
      stop();
      return;
    }
    lastCompletedStates = List.unmodifiable(states);
    _startNewMeasure(endTime);
  }

  void _handleQuarterResult(QuarterState state) {
    if (state == QuarterState.miss && mode == ExerciseMode.normal) {
      lives--;
    }
  }

  MeasureModel _generateRandomMeasure() {
    final patterns = difficulty.patterns;
    return MeasureModel(
      List.generate(
        4,
        (_) => QuarterModel.fromPattern(
          patterns[_random.nextInt(patterns.length)],
        ),
      ),
    );
  }

  void _addMeasure(MeasureModel measure) {
    visibleMeasure.removeFirst();
    visibleMeasure.addLast(measure);
  }

  void _initRandomMeasure() {
    visibleMeasure.addAll(
      List.generate(queueLength, (_) => _generateRandomMeasure()),
    );
  }
}
