import 'package:flutter/material.dart';
import '../navigation/app_routes.dart';
import '../services/settings_service.dart';
import '../services/hit_sensor.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SettingsService _settings = SettingsService();

  @override
  void initState() {
    super.initState();
    _settings.addListener(_onSettingsChanged);
  }

  void _onSettingsChanged() => setState(() {});

  @override
  void dispose() {
    _settings.removeListener(_onSettingsChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionHeader('Timing'),
          _SettingRow(
            label: 'Audio latency compensation',
            value: '${_settings.latencyMs.round()} ms',
            child: Slider(
              value: _settings.latencyMs,
              min: 0,
              max: 300,
              divisions: 60,
              label: '${_settings.latencyMs.round()} ms',
              onChanged: (v) => _settings.setLatencyMs(v),
            ),
          ),
          const SizedBox(height: 8),
          _SectionHeader('Metronome'),
          _SettingRow(
            label: 'Volume',
            value: '${(_settings.metronomeVolume * 100).round()}%',
            child: Slider(
              value: _settings.metronomeVolume,
              min: 0,
              max: 1,
              divisions: 20,
              label: '${(_settings.metronomeVolume * 100).round()}%',
              onChanged: (v) => _settings.setMetronomeVolume(v),
            ),
          ),
          const SizedBox(height: 8),
          _SectionHeader('Accelerometer'),
          _SettingRow(
            label: 'Hit threshold',
            value: _settings.accelThreshold.toStringAsFixed(2),
            child: Slider(
              value: _settings.accelThreshold,
              min: 0.1,
              max: 3.0,
              divisions: 29,
              label: _settings.accelThreshold.toStringAsFixed(2),
              onChanged: (v) => _settings.setAccelThreshold(v),
            ),
          ),
          const SizedBox(height: 8),
          _SectionHeader('Microphone'),
          _SettingRow(
            label: 'Hit threshold',
            value: _settings.micThreshold.toStringAsFixed(2),
            child: Slider(
              value: _settings.micThreshold,
              min: 0.01,
              max: 1.0,
              divisions: 99,
              label: _settings.micThreshold.toStringAsFixed(2),
              onChanged: (v) => _settings.setMicThreshold(v),
            ),
          ),
          const SizedBox(height: 8),
          _SectionHeader('Default Sensor'),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: SegmentedButton<SensorType>(
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
              selected: {_settings.sensorType},
              onSelectionChanged: (s) => _settings.setSensorType(s.first),
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () => Navigator.pushNamed(context, AppRoutes.calibration),
            icon: const Icon(Icons.tune),
            label: const Text('Open Calibration'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () async {
              await _settings.resetAll();
            },
            child: const Text('Reset to defaults'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  final String label;
  final String value;
  final Widget child;

  const _SettingRow({
    required this.label,
    required this.value,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label),
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        child,
      ],
    );
  }
}
