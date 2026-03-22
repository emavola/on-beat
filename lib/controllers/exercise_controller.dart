import 'dart:collection';
import 'dart:math';

import 'package:flutter/material.dart';

import '../models/measure_model.dart';
import '../models/quarter_model.dart';
import 'measure_controller.dart';
import 'package:on_beat/services/metronome_service.dart';
import 'package:on_beat/models/quarter_state.dart';

enum ExerciseMode { normal, zen, incremental, survival, challenge }

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

// TODO(architecture): consider refactoring game mode logic into a strategy
// pattern once the per-mode UI is defined. Each mode would become a separate
// class implementing a GameMode interface (onQuarterResult, onMeasureResult,
// shouldStop, exposed state for UI). ExerciseController would delegate to the
// active GameMode instance. Right now the if/switch chains are manageable —
// refactor when you know exactly what each mode's UI needs to expose.
class ExerciseController extends ChangeNotifier {
  final ExerciseMode mode;
  final ExerciseDifficulty difficulty;
  final int startBpm;
  final Random _random = Random();
  final MetronomeService metronome = MetronomeService();
  Queue<MeasureModel> visibleMeasure = Queue();
  bool isFisrtMeasure = true;
  final int queueLength = 4;

  static const int maxLives = 10;

  // Incremental / Survival shared BPM ramp constants
  static const int _bpmStep = 5;
  static const int _measuresPerStep = 4;
  static const int _maxBpm = 200;

  // Incremental stop condition
  static const int _maxConsecutiveMisses = 3;

  // Survival constants
  static const int _survivalStartLives = 3;
  static const int _survivalMaxLives = 5;
  static const int _streakForLife = 4;

  // Challenge constant
  static const int _defaultChallengeMeasures = 16;

  int lives;
  int _currentBpm = 60;
  int _measuresCompleted = 0;
  int _consecutiveMisses = 0;
  bool maxBpmReached = false;

  // Survival
  int _perfectStreak = 0;
  int get perfectStreak => _perfectStreak;

  // Challenge
  int _perfectCount = 0;
  int _okCount = 0;
  int _missCount = 0;
  bool challengeComplete = false;
  int get perfectCount => _perfectCount;
  int get okCount => _okCount;
  int get missCount => _missCount;
  int get totalQuarters => _perfectCount + _okCount + _missCount;

  int get currentBpm => _currentBpm;
  int get measuresCompleted => _measuresCompleted;
  int get consecutiveMisses => _consecutiveMisses;

  MeasureController? currentMeasureController;

  /// Snapshot of the last completed measure's quarter states.
  /// Set before [_startNewMeasure] so the UI can capture it at transition time.
  List<QuarterState>? lastCompletedStates;

  final int challengeTotalMeasures;

  ExerciseController({
    required this.mode,
    this.difficulty = ExerciseDifficulty.easy,
    this.startBpm = 60,
    this.challengeTotalMeasures = _defaultChallengeMeasures,
  }) : lives = mode == ExerciseMode.normal
            ? maxLives
            : mode == ExerciseMode.survival
                ? _survivalStartLives
                : -1,
       _currentBpm = startBpm;

  /// Avvia l'esercizio — prepara il controller ma non avvia il timer.
  /// Chiamare [beginTiming] dopo che il primo frame è stato renderizzato.
  Future<void> start() async {
    lives = mode == ExerciseMode.normal
        ? maxLives
        : mode == ExerciseMode.survival
            ? _survivalStartLives
            : -1;
    _currentBpm = startBpm;
    _measuresCompleted = 0;
    _consecutiveMisses = 0;
    _perfectStreak = 0;
    _perfectCount = 0;
    _okCount = 0;
    _missCount = 0;
    maxBpmReached = false;
    challengeComplete = false;
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
    metronome.dispose();
    currentMeasureController?.removeListener(notifyListeners);
    currentMeasureController?.dispose();
    currentMeasureController = null;
    notifyListeners();
  }

  @override
  void dispose() {
    currentMeasureController?.removeListener(notifyListeners);
    currentMeasureController?.dispose();
    currentMeasureController = null;
    metronome.dispose();
    super.dispose();
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
      bpm: _currentBpm.toDouble(),
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
    lastCompletedStates = List.unmodifiable(states);
    _measuresCompleted++;

    if (mode == ExerciseMode.normal && lives <= 0) {
      stop();
      return;
    }

    if (mode == ExerciseMode.incremental) {
      if (_consecutiveMisses >= _maxConsecutiveMisses) {
        stop();
        return;
      }
      if (_measuresCompleted % _measuresPerStep == 0) {
        if (_currentBpm >= _maxBpm) {
          maxBpmReached = true;
          stop();
          return;
        }
        _currentBpm += _bpmStep;
      }
    }

    if (mode == ExerciseMode.survival) {
      if (lives <= 0) {
        stop();
        return;
      }
      if (_measuresCompleted % _measuresPerStep == 0 && _currentBpm < _maxBpm) {
        _currentBpm += _bpmStep;
      }
    }

    if (mode == ExerciseMode.challenge) {
      if (_measuresCompleted >= challengeTotalMeasures) {
        challengeComplete = true;
        stop();
        return;
      }
    }

    _startNewMeasure(endTime);
  }

  void _handleQuarterResult(QuarterState state) {
    // Challenge: count every quarter result
    if (mode == ExerciseMode.challenge) {
      if (state == QuarterState.perfect) {
        _perfectCount++;
      } else if (state == QuarterState.ok) {
        _okCount++;
      } else {
        _missCount++;
      }
    }

    if (state == QuarterState.miss) {
      if (mode == ExerciseMode.normal) {
        lives = (lives - 1).clamp(0, maxLives);
        if (lives <= 0) { stop(); return; }
      }
      if (mode == ExerciseMode.incremental) _consecutiveMisses++;
      if (mode == ExerciseMode.survival) {
        lives = (lives - 1).clamp(0, _survivalMaxLives);
        _perfectStreak = 0;
        if (lives <= 0) { stop(); return; }
      }
    } else if (state == QuarterState.perfect) {
      if (mode == ExerciseMode.incremental) _consecutiveMisses = 0;
      if (mode == ExerciseMode.survival) {
        _perfectStreak++;
        if (_perfectStreak >= _streakForLife) {
          lives = (lives + 1).clamp(0, _survivalMaxLives);
          _perfectStreak = 0;
        }
      }
    } else {
      // ok
      if (mode == ExerciseMode.incremental) _consecutiveMisses = 0;
      if (mode == ExerciseMode.survival) _perfectStreak = 0;
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
