import 'package:flutter/material.dart';
import 'package:on_beat/models/quarter_state.dart';

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

  void _startExercise() {
    final startTime = DateTime.now().millisecondsSinceEpoch.toDouble();

    exerciseController.start(startTime);
    acc.start();

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

                    return Padding(
                      padding: const EdgeInsets.all(10),
                      child: QuarterTile(
                        state: state,
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
