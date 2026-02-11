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

    acc.onHitDetected = () {
      final now = DateTime.now().millisecondsSinceEpoch.toDouble();
      exerciseController.currentMeasureController?.onHit(now);
    };
  }

  Future<void> _startExercise() async {
    final startTime = DateTime.now().millisecondsSinceEpoch.toDouble();

    await exerciseController.start(startTime);
    acc.start();
    exerciseController.currentMeasureController?.addListener(
      _onControllerChanged,
    );

    setState(() {});
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
            if (measureController != null)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  measureController.measure.quarters.length,
                  (index) {
                    final quarter = measureController.measure.quarters[index];
                    final state = measureController.quarterStates[index];
                    final isActive =
                        measureController.currentQuarterIndex == index;

                    return Padding(
                      padding: const EdgeInsets.all(10),
                      child: QuarterTile(
                        state: state,
                        isActive: isActive,
                        child: Image.asset(
                          quarter.assetPath,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    acc.stop();
    super.dispose();
  }
}
