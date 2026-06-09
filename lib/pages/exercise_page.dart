import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../controllers/exercise_controller.dart';
import '../controllers/measure_controller.dart';
import '../models/exercise_result.dart';
import '../models/measure_model.dart';
import '../models/quarter_state.dart';
import '../services/accelerometer_service.dart';
import '../services/microphone_service.dart';
import '../services/mixed_sensor.dart';
import '../services/hit_sensor.dart';
import '../widgets/quarter_tile.dart';
import 'exercise_result_page.dart';

HitSensor _sensorForType(SensorType type) => switch (type) {
  SensorType.accelerometer => AccelerometerService(),
  SensorType.microphone => MicrophoneService(),
  SensorType.mixed => MixedSensor(),
};

enum _PageState { preview, countIn, running, paused }

class ExercisePage extends StatefulWidget {
  final SensorType sensorType;
  final ExerciseMode mode;
  final ExerciseDifficulty difficulty;
  final int bpm;

  /// Optional fixed measures to play (from the rhythm scanner). When set, the
  /// page runs challenge-style through exactly these measures.
  final List<MeasureModel>? scriptedMeasures;

  const ExercisePage({
    super.key,
    this.sensorType = SensorType.accelerometer,
    this.mode = ExerciseMode.normal,
    this.difficulty = ExerciseDifficulty.easy,
    this.bpm = 80,
    this.scriptedMeasures,
  });

  @override
  State<ExercisePage> createState() => _ExercisePageState();
}

class _ExercisePageState extends State<ExercisePage>
    with TickerProviderStateMixin {
  late ExerciseController exerciseController;
  late final HitSensor _sensor;

  // QuarterTile 70px + Padding(all(10)) = 90px per row.
  static const double _itemHeight = 90.0;

  // Opacity by slot index: 0=played, 1=current, 2=next, 3=next+1, 4=entering
  static const List<double> _slotOpacities = [0.3, 1.0, 0.55, 0.25, 0.0];

  // Running queue state
  List<MeasureModel?> _animatedQueue = [];
  List<List<QuarterState>?> _queueStates = [];
  late AnimationController _slideController;
  late Animation<double> _slideAnim;

  // Count-in state
  _PageState _pageState = _PageState.preview;
  String? _countdownLabel;
  int _countdownStep = 0;
  Timer? _countInTimer;
  bool _resumingFromPause = false;
  late AnimationController _stampController;
  late Animation<double> _stampAnim;

  bool _loading = true;
  bool _wasRunning = false;
  bool _resultShown = false;
  DateTime? _exerciseStartTime;

  @override
  void initState() {
    super.initState();

    _sensor = _sensorForType(widget.sensorType);
    exerciseController = ExerciseController(
      mode: widget.mode,
      difficulty: widget.difficulty,
      startBpm: widget.bpm,
      scriptedMeasures: widget.scriptedMeasures,
      challengeTotalMeasures: widget.scriptedMeasures?.length ??
          ExerciseController.defaultChallengeMeasures,
    );
    exerciseController.addListener(_onControllerChanged);

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _slideAnim = CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeInOut,
    );
    _slideController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _slideController.reset();
        setState(() {
          _animatedQueue = _animatedQueue.sublist(1);
          _queueStates = _queueStates.sublist(1);
        });
      }
    });

    _stampController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _stampAnim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _stampController, curve: Curves.elasticOut),
    );

    _sensor.onHitDetected = (double timestampMs) {
      exerciseController.currentMeasureController?.onHit(timestampMs);
    };

    exerciseController.preview().then((_) {
      if (mounted) setState(() => _loading = false);
    });
  }

  // ---------------------------------------------------------------------------
  // Count-in
  // ---------------------------------------------------------------------------

  void _startCountIn({bool resuming = false}) {
    _resumingFromPause = resuming;

    if (resuming) {
      // Reset the current measure to neutral states immediately so the queue
      // looks clean during the count-in, not frozen mid-evaluation.
      exerciseController.prepareResume();
      final playedMeasure = _animatedQueue.isNotEmpty ? _animatedQueue[0] : null;
      final playedStates = _queueStates.isNotEmpty ? _queueStates[0] : null;
      _animatedQueue = [playedMeasure, ...exerciseController.visibleMeasure.take(3)];
      _queueStates = [playedStates, null, null, null];
    }

    setState(() {
      _pageState = _PageState.countIn;
      _countdownStep = 0;
      _countdownLabel = null;
    });

    // Reset tick index so beat "3" is always a strong click and the exercise
    // first beat lands on strong too (4 count-in beats → _tickIndex back to 0).
    exerciseController.metronome.reset();

    final beatDuration = Duration(
      milliseconds: (60000 / exerciseController.currentBpm).round(),
    );

    _fireCountInBeat();

    _countInTimer = Timer.periodic(beatDuration, (timer) {
      if (_countdownStep >= 4) {
        timer.cancel();
        if (_resumingFromPause) {
          _resumeExercise();
        } else {
          _launchExercise();
        }
      } else {
        _fireCountInBeat();
      }
    });
  }

  void _fireCountInBeat() {
    exerciseController.metronome.play();
    _countdownStep++;

    final label = switch (_countdownStep) {
      1 => '3',
      2 => '2',
      3 => '1',
      4 => 'GO!',
      _ => null,
    };

    setState(() => _countdownLabel = label);
    _stampController.forward(from: 0.0);
  }

  // ---------------------------------------------------------------------------
  // Launch (first start)
  // ---------------------------------------------------------------------------

  Future<void> _launchExercise() async {
    // Pre-populate from the preview queue so AnimatedSwitcher never sees an
    // empty frame between count-in and the first running frame.
    _animatedQueue = [null, ...exerciseController.visibleMeasure.take(3)];
    _queueStates = [null, null, null, null];
    _slideController.stop();
    _slideController.reset();
    _exerciseStartTime = DateTime.now();

    setState(() {
      _pageState = _PageState.running;
      _countdownLabel = null;
    });

    await exerciseController.start();
    _sensor.start();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      exerciseController.beginTiming();
    });
  }

  // ---------------------------------------------------------------------------
  // Pause / Resume
  // ---------------------------------------------------------------------------

  void _pauseExercise() {
    _countInTimer?.cancel();
    _slideController.stop();
    _slideController.reset();
    _sensor.stop();
    exerciseController.pauseExercise();
    setState(() => _pageState = _PageState.paused);
  }

  void _resumeExercise() {
    // prepareResume() and queue reset already done at the start of _startCountIn.
    setState(() {
      _pageState = _PageState.running;
      _countdownLabel = null;
    });

    _sensor.start();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      exerciseController.beginTiming();
    });
  }

  // ---------------------------------------------------------------------------
  // Quit / Result
  // ---------------------------------------------------------------------------

  void _quitExercise() {
    _countInTimer?.cancel();
    _sensor.stop();
    exerciseController.stop();
    if (mounted) Navigator.of(context).pop();
  }

  void _navigateToResult() {
    if (_resultShown) return;
    _resultShown = true;
    _sensor.stop();
    final result = ExerciseResult.fromController(
      exerciseController,
      widget.sensorType,
    );
    final duration = _exerciseStartTime == null
        ? 0
        : DateTime.now().difference(_exerciseStartTime!).inSeconds;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ExerciseResultPage(
              result: result,
              durationSeconds: duration,
            ),
          ),
        );
      }
    });
  }

  // ---------------------------------------------------------------------------
  // PopScope dialog
  // ---------------------------------------------------------------------------

  Future<bool> _onPopRequested() async {
    if (_pageState == _PageState.preview || _pageState == _PageState.countIn) {
      _countInTimer?.cancel();
      return true; // allow pop freely
    }

    // Running or paused: ask the user
    final result = await showDialog<_QuitAction>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Exercise in progress'),
        content: const Text('What do you want to do?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, _QuitAction.cancel),
            child: const Text('Cancel'),
          ),
          if (_pageState == _PageState.running)
            TextButton(
              onPressed: () => Navigator.pop(ctx, _QuitAction.pause),
              child: const Text('Pause'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, _QuitAction.quit),
            child: const Text('Quit', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (result == _QuitAction.pause) {
      _pauseExercise();
      return false;
    }
    if (result == _QuitAction.quit) {
      _quitExercise();
      return false; // _quitExercise pops manually
    }
    return false;
  }

  // ---------------------------------------------------------------------------
  // Controller listener
  // ---------------------------------------------------------------------------

  void _onControllerChanged() {
    final isRunning = exerciseController.isRunning;
    if (_wasRunning && !isRunning && _pageState == _PageState.running) {
      _navigateToResult();
    }
    _wasRunning = isRunning;

    final mc = exerciseController.currentMeasureController;
    if (mc != null && _pageState == _PageState.running) {
      if (_animatedQueue.isEmpty) {
        _animatedQueue = [null, ...exerciseController.visibleMeasure.take(3)];
        _queueStates = [null, null, null, null];
      } else if (_animatedQueue.length >= 2 &&
          _animatedQueue.elementAt(1) != mc.measure &&
          _slideController.value == 0.0) {
        final states = exerciseController.lastCompletedStates;
        _queueStates = [..._queueStates, null];
        if (states != null) {
          _queueStates[1] = states;
        }
        final entering = exerciseController.visibleMeasure.elementAt(2);
        _animatedQueue = [..._animatedQueue, entering];
        _slideController.forward(from: 0.0);
      }
    }
    setState(() {});
  }

  // ---------------------------------------------------------------------------
  // UI builders
  // ---------------------------------------------------------------------------

  Widget _buildModeInfo(BuildContext context) {
    final ec = exerciseController;
    final bpmChip = _InfoChip('${ec.currentBpm} BPM');

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        alignment: WrapAlignment.center,
        children: switch (ec.mode) {
          ExerciseMode.zen => [bpmChip],
          ExerciseMode.normal => [
              _InfoChip('Lives: ${ec.lives}', prominent: true),
              bpmChip,
            ],
          ExerciseMode.incremental => [
              _InfoChip('${ec.currentBpm} BPM', prominent: true),
              _InfoChip('Misses: ${ec.consecutiveMisses} / 3'),
            ],
          ExerciseMode.survival => [
              _InfoChip('Lives: ${ec.lives}', prominent: true),
              _InfoChip('Streak: ${ec.perfectStreak} / 4'),
              bpmChip,
            ],
          ExerciseMode.challenge => [
              _InfoChip(
                '${ec.measuresCompleted} / ${ec.challengeTotalMeasures}',
                prominent: true,
              ),
              _InfoChip('Perfect: ${ec.perfectCount}'),
              _InfoChip('Ok: ${ec.okCount}'),
              _InfoChip('Miss: ${ec.missCount}'),
            ],
        },
      ),
    );
  }

  double _opacityForIndex(int i, double animValue) {
    final from = _slotOpacities[i.clamp(0, 4)];
    if (animValue == 0.0) return from;
    final to = i == 0 ? 0.0 : _slotOpacities[(i - 1).clamp(0, 4)];
    return lerpDouble(from, to, animValue)!;
  }

  Widget _buildStaticQueue({double overallOpacity = 1.0}) {
    final measures = exerciseController.visibleMeasure.take(3).toList();

    return Opacity(
      opacity: overallOpacity,
      child: SizedBox(
        height: 4 * _itemHeight,
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            for (int i = 0; i < measures.length; i++)
              Positioned(
                top: (i + 1) * _itemHeight,
                left: 0,
                right: 0,
                height: _itemHeight,
                child: Opacity(
                  opacity: _slotOpacities[i + 1],
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      measures[i].quarters.length,
                      (index) => Padding(
                        padding: const EdgeInsets.all(10),
                        child: QuarterTile(
                          key: ObjectKey((measures[i], index)),
                          state: QuarterState.neutral,
                          isActive: false,
                          child: Image.asset(
                            measures[i].quarters[index].assetPath,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRunningQueue(MeasureController measureController) {
    return AnimatedBuilder(
      animation: _slideAnim,
      builder: (context, _) {
        final animValue = _slideAnim.value;
        final slideOffset = animValue * _itemHeight;

        return SizedBox(
          height: 4 * _itemHeight,
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: List.generate(_animatedQueue.length, (i) {
              final m = _animatedQueue[i];
              final opacity = _opacityForIndex(i, animValue);

              return Positioned(
                top: i * _itemHeight - slideOffset,
                left: 0,
                right: 0,
                height: _itemHeight,
                child: Opacity(
                  opacity: opacity.clamp(0.0, 1.0),
                  child: m == null
                      ? const SizedBox.shrink()
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            m.quarters.length,
                            (index) {
                              final isCurrent = m == measureController.measure;
                              final quarter = m.quarters[index];
                              final slotStates = _queueStates[i];
                              final state = isCurrent
                                  ? measureController.quarterStates[index]
                                  : slotStates != null
                                      ? slotStates[index]
                                      : QuarterState.neutral;
                              final isActive = isCurrent &&
                                  measureController.currentQuarterIndex ==
                                      index;

                              return Padding(
                                padding: const EdgeInsets.all(10),
                                child: QuarterTile(
                                  key: ObjectKey((m, index)),
                                  state: state,
                                  isActive: isActive,
                                  child: Image.asset(
                                    quarter.assetPath,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                ),
              );
            }),
          ),
        );
      },
    );
  }

  Widget _buildCountdownWidget() {
    if (_countdownLabel == null) return const SizedBox.shrink();

    final isGo = _countdownLabel == 'GO!';
    return ScaleTransition(
      scale: _stampAnim,
      child: Text(
        _countdownLabel!,
        style: TextStyle(
          fontSize: isGo ? 56 : 80,
          fontWeight: FontWeight.w900,
          color: isGo
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final measureController = exerciseController.currentMeasureController;
    final isPreview = _pageState == _PageState.preview;
    final isCountIn = _pageState == _PageState.countIn;
    final isRunning = _pageState == _PageState.running;
    final isPaused = _pageState == _PageState.paused;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) await _onPopRequested();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('On Beat'),
          centerTitle: true,
          actions: [
            if (isRunning)
              IconButton(
                icon: const Icon(Icons.pause),
                tooltip: 'Pause',
                onPressed: _pauseExercise,
              ),
          ],
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isRunning && exerciseController.isRunning)
                _buildModeInfo(context),

              const SizedBox(height: 24),

              // Queue area.
              // 'static' key: initial preview / initial count-in (no played slot yet).
              // 'running' key: running, paused, and resume count-in — same key so
              //   AnimatedSwitcher never transitions between them, preserving the
              //   played slot at index 0 throughout.
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                child: _loading
                    ? const SizedBox(
                        key: ValueKey('loading'),
                        height: 4 * _itemHeight,
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : (isPreview || (isCountIn && !_resumingFromPause))
                        ? Stack(
                            key: const ValueKey('static'),
                            alignment: Alignment.center,
                            children: [
                              _buildStaticQueue(),
                              if (isCountIn) _buildCountdownWidget(),
                            ],
                          )
                        : (measureController != null && _animatedQueue.isNotEmpty)
                            ? Stack(
                                key: const ValueKey('running'),
                                alignment: Alignment.center,
                                children: [
                                  Opacity(
                                    opacity: isPaused ? 0.4 : 1.0,
                                    child: _buildRunningQueue(measureController),
                                  ),
                                  if (isCountIn) _buildCountdownWidget(),
                                ],
                              )
                            : const SizedBox(key: ValueKey('empty')),
              ),

              const SizedBox(height: 32),

              // Action buttons
              if (isPreview && !_loading)
                ElevatedButton(
                  onPressed: _startCountIn,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 32,
                    ),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  ),
                  child: const Text(
                    'Start',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

              if (isPaused) ...[
                const Text(
                  'PAUSED',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 4,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => _startCountIn(resuming: true),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Resume'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 28,
                    ),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _quitExercise,
                  child: const Text(
                    'Quit',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _countInTimer?.cancel();
    _slideController.dispose();
    _stampController.dispose();
    exerciseController.removeListener(_onControllerChanged);
    exerciseController.dispose();
    _sensor.stop();
    super.dispose();
  }
}

enum _QuitAction { cancel, pause, quit }

class _InfoChip extends StatelessWidget {
  final String label;
  final bool prominent;

  const _InfoChip(this.label, {this.prominent = false});

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: prominent ? 16 : 13,
          fontWeight: prominent ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }
}
