import 'package:fl_chart/fl_chart.dart';
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
            SizedBox(
              width: 400,
              height: 200,
              child: LineChart(
                LineChartData(
                  lineBarsData: [
                    LineChartBarData(
                      spots: List.generate(
                        acc.getDerivative().length,
                        (i) => FlSpot(i.toDouble(), acc.getDerivative()[i]),
                      ),
                      isCurved: true,
                      color: Colors.blue,
                      belowBarData: BarAreaData(show: false),
                      dotData: FlDotData(show: false),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(
              width: 400,
              height: 200,
              child: LineChart(
                LineChartData(
                  lineBarsData: [
                    LineChartBarData(
                      spots: List.generate(
                        AccelerometerService.magnitudesForChart.length,
                        (i) => FlSpot(
                          i.toDouble(),
                          AccelerometerService.magnitudesForChart[i],
                        ),
                      ),
                      isCurved: true,
                      color: Colors.blue,
                      belowBarData: BarAreaData(show: false),
                      dotData: FlDotData(show: false),
                    ),
                  ],
                ),
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
