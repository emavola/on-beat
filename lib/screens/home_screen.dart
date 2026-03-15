import 'package:flutter/material.dart';
import '../navigation/app_routes.dart';
import '../pages/exercise_page.dart';
import '../services/hit_sensor.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  SensorType _selectedSensor = SensorType.accelerometer;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SegmentedButton<SensorType>(
            segments: const [
              ButtonSegment(
                value: SensorType.accelerometer,
                icon: Icon(Icons.vibration),
                label: Text('Accel'),
              ),
              ButtonSegment(
                value: SensorType.microphone,
                icon: Icon(Icons.mic),
                label: Text('Mic'),
              ),
              ButtonSegment(
                value: SensorType.mixed,
                icon: Icon(Icons.sensors),
                label: Text('Mixed'),
              ),
            ],
            selected: {_selectedSensor},
            onSelectionChanged: (s) => setState(() => _selectedSensor = s.first),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ExercisePage(sensorType: _selectedSensor),
              ),
            ),
            child: const Text('Go to exercise!'),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () =>
                Navigator.pushNamed(context, AppRoutes.accelerometerTest),
            child: const Text('Accelerometer test'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pushNamed(context, AppRoutes.microphoneTest),
            child: const Text('Microphone test'),
          ),
        ],
      ),
    );
  }
}
