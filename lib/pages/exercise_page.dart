import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:on_beat/services/accelerometer_service.dart';
import 'package:on_beat/widgets/note_painter.dart';

class ExercisePage extends StatefulWidget {
  const ExercisePage({super.key});
  @override
  State<ExercisePage> createState() => _ExercisePageState();
}

class _ExercisePageState extends State<ExercisePage>
    with SingleTickerProviderStateMixin {
  final AccelerometerService acc = AccelerometerService();
  late AnimationController _controller;
  late Animation<double> _animation;

  int _counter = 0;

  @override
  void initState() {
    super.initState();
    acc.onHitDetected =
        () => setState(() {
          _counter++;
        });
    _controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: 5),
    );
    _animation = Tween<double>(begin: -1, end: 1).animate(_controller)
      ..addListener(() {
        setState(() {});
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
              onPressed: () {
                _controller.reset();
                _controller.forward();
              },
              child: Text("Start"),
            ),
            Center(
              child: SizedBox(
                width: double.infinity,
                height: 300,
                child: CustomPaint(painter: NotePainter()),
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
