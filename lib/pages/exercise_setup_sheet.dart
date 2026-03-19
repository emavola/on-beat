import 'package:flutter/material.dart';
import '../controllers/exercise_controller.dart';
import '../services/hit_sensor.dart';
import 'exercise_page.dart';

/// Default starting BPM per mode.
int _defaultBpmForMode(ExerciseMode mode) => switch (mode) {
      ExerciseMode.incremental => 60,
      ExerciseMode.zen => 70,
      ExerciseMode.survival => 70,
      _ => 80,
    };

class ExerciseSetupSheet extends StatefulWidget {
  const ExerciseSetupSheet({super.key});

  @override
  State<ExerciseSetupSheet> createState() => _ExerciseSetupSheetState();
}

class _ExerciseSetupSheetState extends State<ExerciseSetupSheet> {
  ExerciseMode _mode = ExerciseMode.normal;
  ExerciseDifficulty _difficulty = ExerciseDifficulty.easy;
  SensorType _sensor = SensorType.accelerometer;
  int _bpm = 80;

  void _setMode(ExerciseMode mode) {
    setState(() {
      _mode = mode;
      _bpm = _defaultBpmForMode(mode);
    });
  }

  void _start() {
    if (_sensor == SensorType.microphone || _sensor == SensorType.mixed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Use headphones — speaker metronome will be picked up by the mic.',
          ),
          duration: Duration(seconds: 4),
        ),
      );
    }
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ExercisePage(
          mode: _mode,
          difficulty: _difficulty,
          sensorType: _sensor,
          bpm: _bpm,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          Text('Practice Setup', style: theme.textTheme.titleLarge),
          const SizedBox(height: 24),

          // Mode
          Text('Mode', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ExerciseMode.values.map((mode) {
              return ChoiceChip(
                label: Text(_modeLabel(mode)),
                selected: _mode == mode,
                onSelected: (_) => _setMode(mode),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          // Difficulty
          Text('Difficulty', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          SegmentedButton<ExerciseDifficulty>(
            segments: const [
              ButtonSegment(
                value: ExerciseDifficulty.easy,
                label: Text('Easy'),
              ),
              ButtonSegment(
                value: ExerciseDifficulty.medium,
                label: Text('Medium'),
              ),
              ButtonSegment(
                value: ExerciseDifficulty.hard,
                label: Text('Hard'),
              ),
            ],
            selected: {_difficulty},
            onSelectionChanged: (s) =>
                setState(() => _difficulty = s.first),
          ),
          const SizedBox(height: 20),

          // BPM
          Text('BPM', style: theme.textTheme.labelLarge),
          const SizedBox(height: 4),
          if (_mode == ExerciseMode.incremental)
            Text(
              'Starting BPM — increases +5 every 4 measures',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.remove),
                onPressed: _bpm > 40
                    ? () => setState(() => _bpm -= 5)
                    : null,
              ),
              Text(
                '$_bpm',
                style: theme.textTheme.headlineMedium,
              ),
              const SizedBox(width: 4),
              Text('BPM', style: theme.textTheme.bodyMedium),
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: _bpm < 240
                    ? () => setState(() => _bpm += 5)
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Sensor
          Text('Input sensor', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
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
            selected: {_sensor},
            onSelectionChanged: (s) => setState(() => _sensor = s.first),
          ),
          const SizedBox(height: 32),

          // Start button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _start,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Start'),
            ),
          ),
        ],
      ),
    );
  }
}

String _modeLabel(ExerciseMode mode) => switch (mode) {
      ExerciseMode.normal => 'Normal',
      ExerciseMode.zen => 'Zen',
      ExerciseMode.incremental => 'Incremental',
      ExerciseMode.survival => 'Survival',
      ExerciseMode.challenge => 'Challenge',
    };
