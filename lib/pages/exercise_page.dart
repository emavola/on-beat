import 'package:flutter/material.dart';

import '../controllers/exercise_controller.dart';
import '../services/accelerometer_service.dart';
import '../widgets/quarter_tile.dart';

class ExercisePage extends StatefulWidget {
  const ExercisePage({super.key});

  @override
  State<ExercisePage> createState() => _ExercisePageState();
}

class _ExercisePageState extends State<ExercisePage> {
  late ExerciseController exerciseController;
  final AccelerometerService acc = AccelerometerService();

  @override
  void initState() {
    super.initState();

    exerciseController = ExerciseController(mode: ExerciseMode.normal);
    exerciseController.addListener(_onControllerChanged);

    acc.onHitDetected = () {
      final now = DateTime.now().millisecondsSinceEpoch.toDouble();
      exerciseController.currentMeasureController?.onHit(now);
    };
  }

  Future<void> _startExercise() async {
    await exerciseController.start();
    acc.start();
    // Wait for the first frame to render before starting the timer,
    // so the UI rebuild doesn't block the event loop during beat 1.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      exerciseController.beginTiming();
    });
  }

  void _onControllerChanged() {
    setState(() {});
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
            // VITE
            if (exerciseController.mode == ExerciseMode.normal)
              Text(
                'Vite: ${exerciseController.lives}',
                style: const TextStyle(fontSize: 20),
              ),

            const SizedBox(height: 24),

            // START
            if (!exerciseController.isRunning)
              ElevatedButton(
                onPressed: _startExercise,
                child: const Text('Start'),
              ),

            // BATTUTA CORRENTE
            // if (true && measureController != null)
            //   Row(
            //     mainAxisAlignment: MainAxisAlignment.center,
            //     children: List.generate(
            //       measureController.measure.quarters.length,
            //       (index) {
            //         final quarter = measureController.measure.quarters[index];
            //         final state = measureController.quarterStates[index];
            //         final isActive =
            //             measureController.currentQuarterIndex == index;

            //         return Padding(
            //           padding: const EdgeInsets.all(10),
            //           child: QuarterTile(
            //             state: state,
            //             isActive: isActive,
            //             child: Image.asset(
            //               quarter.assetPath,
            //               color: Theme.of(context).colorScheme.onSurface,
            //             ),
            //           ),
            //         );
            //       },
            //     ),
            //   ),
            if (measureController != null)
              AnimatedSwitcher(
                duration: Duration(milliseconds: 400),
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: Offset(0, 0.3),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: Column(
                  key: ValueKey(
                    exerciseController.getCurrentMeasure().hashCode,
                  ),
                  children:
                      exerciseController.visibleMeasure.map((m) {
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(m.quarters.length, (index) {
                            final quarter = m.quarters[index];
                            final state =
                                measureController.quarterStates[index];
                            final isActive =
                                measureController.currentQuarterIndex == index;

                            return Padding(
                              padding: const EdgeInsets.all(10),
                              child: QuarterTile(
                                state: state,
                                isActive: isActive,
                                child: Image.asset(
                                  quarter.assetPath,
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                            );
                          }),
                        );
                      }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    exerciseController.removeListener(_onControllerChanged);
    exerciseController.dispose();
    acc.stop();
    super.dispose();
  }
}
