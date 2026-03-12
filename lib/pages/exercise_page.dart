import 'dart:ui';

import 'package:flutter/material.dart';

import '../controllers/exercise_controller.dart';
import '../models/measure_model.dart';
import '../models/quarter_state.dart';
import '../services/accelerometer_service.dart';
import '../widgets/quarter_tile.dart';

class ExercisePage extends StatefulWidget {
  const ExercisePage({super.key});

  @override
  State<ExercisePage> createState() => _ExercisePageState();
}

class _ExercisePageState extends State<ExercisePage>
    with SingleTickerProviderStateMixin {
  late ExerciseController exerciseController;
  final AccelerometerService acc = AccelerometerService();

  // QuarterTile 70px + Padding(all(10)) = 90px per row.
  // 4 visible slots: [played|empty, current, next, next+1]
  static const double _itemHeight = 90.0;

  // Opacity by slot index: 0=played, 1=current, 2=next, 3=next+1, 4=entering
  static const List<double> _slotOpacities = [0.3, 1.0, 0.55, 0.25, 0.0];

  // null = empty played slot (no previous measure yet)
  List<MeasureModel?> _animatedQueue = [];

  late AnimationController _slideController;
  late Animation<double> _slideAnim;

  @override
  void initState() {
    super.initState();

    exerciseController = ExerciseController(mode: ExerciseMode.normal);
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
        // Reset BEFORE setState so AnimatedBuilder rebuilds at value=0,
        // keeping all 4 slots at the correct positions.
        _slideController.reset();
        setState(() {
          _animatedQueue = _animatedQueue.sublist(1);
        });
      }
    });

    acc.onHitDetected = () {
      final now = DateTime.now().millisecondsSinceEpoch.toDouble();
      exerciseController.currentMeasureController?.onHit(now);
    };
  }

  Future<void> _startExercise() async {
    _animatedQueue = [];
    _slideController.stop();
    _slideController.reset();
    await exerciseController.start();
    acc.start();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      exerciseController.beginTiming();
    });
  }

  void _onControllerChanged() {
    final mc = exerciseController.currentMeasureController;
    if (mc != null) {
      if (_animatedQueue.isEmpty) {
        // First population: empty played slot + current + next + next+1
        _animatedQueue = [
          null,
          ...exerciseController.visibleMeasure.take(3),
        ];
      } else if (_animatedQueue.length >= 2 &&
          _animatedQueue.elementAt(1) != mc.measure &&
          _slideController.value == 0.0) {
        // Measure advanced — add the item that was off-screen below (index 2
        // of the new visibleMeasure) and slide the whole column up by one slot.
        final entering = exerciseController.visibleMeasure.elementAt(2);
        _animatedQueue = [..._animatedQueue, entering];
        _slideController.forward(from: 0.0);
      }
    }
    setState(() {});
  }

  double _opacityForIndex(int i, double animValue) {
    final from = _slotOpacities[i.clamp(0, 4)];
    if (animValue == 0.0) return from;
    final to = i == 0 ? 0.0 : _slotOpacities[(i - 1).clamp(0, 4)];
    return lerpDouble(from, to, animValue)!;
  }

  @override
  Widget build(BuildContext context) {
    final measureController = exerciseController.currentMeasureController;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Esercizio Batteria'),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (exerciseController.mode == ExerciseMode.normal)
              Text(
                'Vite: ${exerciseController.lives}',
                style: const TextStyle(fontSize: 20),
              ),

            const SizedBox(height: 24),

            if (!exerciseController.isRunning)
              ElevatedButton(
                onPressed: _startExercise,
                child: const Text('Start'),
              ),

            if (measureController != null && _animatedQueue.isNotEmpty)
              AnimatedBuilder(
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
                                        final isCurrent =
                                            m == measureController.measure;
                                        final quarter = m.quarters[index];
                                        final state = isCurrent
                                            ? measureController
                                                .quarterStates[index]
                                            : QuarterState.neutral;
                                        final isActive =
                                            isCurrent &&
                                            measureController
                                                    .currentQuarterIndex ==
                                                index;

                                        return Padding(
                                          padding: const EdgeInsets.all(10),
                                          child: QuarterTile(
                                            state: state,
                                            isActive: isActive,
                                            child: Image.asset(
                                              quarter.assetPath,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurface,
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
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _slideController.dispose();
    exerciseController.removeListener(_onControllerChanged);
    exerciseController.dispose();
    acc.stop();
    super.dispose();
  }
}
