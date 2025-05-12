import 'package:flutter/material.dart';
import 'package:on_beat/services/accelerometer_service.dart';

class ExercisePage extends StatefulWidget {
  const ExercisePage({super.key});
  @override
  State<ExercisePage> createState() => _ExercisePageState();
}

class _ExercisePageState extends State<ExercisePage> {
  final AccelerometerService acc = AccelerometerService();

  int _counter = 0;

  @override
  void initState() {
    super.initState();
    acc.onHitDetected =
        () => setState(() {
          _counter++;
        });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Esercizio Batteria'),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          children: [
            ElevatedButton(
              onPressed: AccelerometerService().start,
              child: Text("Start"),
            ),
            ElevatedButton(
              onPressed: AccelerometerService().stop,
              child: Text("stop"),
            ),
            Text(_counter.toString()),
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
