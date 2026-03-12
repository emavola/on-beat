import 'dart:collection';
import 'dart:math';

import 'package:flutter/material.dart';

import '../models/measure_model.dart';
import '../models/quarter_model.dart';
import 'measure_controller.dart';
import 'package:on_beat/services/metronome_service.dart';
import 'package:on_beat/models/quarter_state.dart';

enum ExerciseMode { normal, zen }

class ExerciseController extends ChangeNotifier {
  final ExerciseMode mode;
  final Random _random = Random();
  final MetronomeService metronome = MetronomeService();
  Queue<MeasureModel> visibleMeasure = Queue();
  bool isFisrtMeasure = true;
  final int queueLength = 4;

  static const int maxLives = 10;

  int lives;
  MeasureController? currentMeasureController;

  ExerciseController({required this.mode})
    : lives = mode == ExerciseMode.normal ? maxLives : -1;

  /// Avvia l'esercizio — prepara il controller ma non avvia il timer.
  /// Chiamare [beginTiming] dopo che il primo frame è stato renderizzato.
  Future<void> start() async {
    lives = mode == ExerciseMode.normal ? maxLives : -1;
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
  }

  bool get isRunning => currentMeasureController != null;

  MeasureModel getCurrentMeasure() {
    isFisrtMeasure
        ? print(visibleMeasure.first.hashCode)
        : print(visibleMeasure.elementAt(1).hashCode);
    return isFisrtMeasure ? visibleMeasure.first : visibleMeasure.elementAt(1);
  }

  // -------------------------
  // PRIVATE
  // -------------------------

  void _startNewMeasure(double startTime, {bool startTiming = true}) {
    print("_startNewMeasure");

    currentMeasureController?.removeListener(notifyListeners);
    currentMeasureController?.dispose();
    currentMeasureController = null;

    MeasureModel measure;
    if (isFisrtMeasure) {
      measure = visibleMeasure.first;
    } else {
      _addMeasure(_generateRandomMeasure());
      measure = visibleMeasure.elementAt(1);
    }

    final controller = MeasureController(
      measure: measure,
      bpm: 100,
      metronome: metronome,
    );

    controller.onMeasureCompleted = (
      List<QuarterState> states,
      double endTime,
    ) {
      print("Callback exercise - measure completed");
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
