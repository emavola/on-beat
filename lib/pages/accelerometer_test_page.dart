import 'dart:async';

import 'package:flutter/material.dart';

import '../services/accelerometer_service.dart';
import '../services/metronome_service.dart';

class AccelerometerTestPage extends StatefulWidget {
  const AccelerometerTestPage({super.key});

  @override
  State<AccelerometerTestPage> createState() => _AccelerometerTestPageState();
}

class _AccelerometerTestPageState extends State<AccelerometerTestPage> {
  final AccelerometerService acc = AccelerometerService();
  final MetronomeService _metronome = MetronomeService();

  int _hitCount = 0;
  bool _flash = false;
  Timer? _flashTimer;

  double _currentMag = 0;
  double _peakMag = 0;

  bool _metronomeRunning = false;
  int _bpm = 80;
  Timer? _metronomeTimer;

  @override
  void initState() {
    super.initState();
    acc.onHitDetected = _onHit;
    acc.onMagnitudeUpdate = _onMagnitude;
    acc.start();
    _metronome.init();
  }

  void _changeBpm(int newBpm) {
    setState(() => _bpm = newBpm);
    if (_metronomeRunning) {
      _metronomeTimer?.cancel();
      final interval = Duration(milliseconds: (60000 / _bpm).round());
      _metronome.reset();
      _metronomeTimer = Timer.periodic(interval, (_) => _metronome.play());
    }
  }

  void _toggleMetronome() {
    if (_metronomeRunning) {
      _metronomeTimer?.cancel();
      _metronomeTimer = null;
      setState(() => _metronomeRunning = false);
    } else {
      final interval = Duration(milliseconds: (60000 / _bpm).round());
      _metronome.reset();
      _metronomeTimer = Timer.periodic(interval, (_) => _metronome.play());
      setState(() => _metronomeRunning = true);
    }
  }

  void _onHit(double _) {
    _flashTimer?.cancel();
    setState(() {
      _hitCount++;
      _flash = true;
    });
    _flashTimer = Timer(const Duration(milliseconds: 150), () {
      if (mounted) setState(() => _flash = false);
    });
  }

  void _onMagnitude(double mag) {
    if (mounted) {
      setState(() {
        _currentMag = mag;
        if (mag > _peakMag) _peakMag = mag;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Accelerometer Test')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 80),
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _flash ? Colors.greenAccent : Colors.grey.shade800,
                boxShadow: _flash
                    ? [
                        BoxShadow(
                          color: Colors.greenAccent.withValues(alpha: 0.6),
                          blurRadius: 30,
                          spreadRadius: 10,
                        ),
                      ]
                    : [],
              ),
            ),
            const SizedBox(height: 32),
            Text(
              '$_hitCount',
              style: const TextStyle(fontSize: 64, fontWeight: FontWeight.bold),
            ),
            const Text('hits', style: TextStyle(fontSize: 20)),
            const SizedBox(height: 32),
            _InfoRow(label: 'current', value: _currentMag),
            const SizedBox(height: 8),
            _InfoRow(label: 'peak', value: _peakMag, highlight: true),
            const SizedBox(height: 8),
            _InfoRow(
              label: 'threshold',
              value: AccelerometerService.threshold,
              color: Colors.orangeAccent,
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove),
                  onPressed: _bpm > 40 ? () => _changeBpm(_bpm - 5) : null,
                ),
                Text('$_bpm BPM', style: const TextStyle(fontSize: 18)),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: _bpm < 240 ? () => _changeBpm(_bpm + 5) : null,
                ),
              ],
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _toggleMetronome,
              icon: Icon(_metronomeRunning ? Icons.stop : Icons.play_arrow),
              label: Text(_metronomeRunning ? 'Stop' : 'Metronome'),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => setState(() {
                _hitCount = 0;
                _peakMag = 0;
              }),
              child: const Text('Reset'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _flashTimer?.cancel();
    _metronomeTimer?.cancel();
    _metronome.dispose();
    acc.onHitDetected = null;
    acc.onMagnitudeUpdate = null;
    acc.stop();
    super.dispose();
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final double value;
  final bool highlight;
  final Color? color;

  const _InfoRow({
    required this.label,
    required this.value,
    this.highlight = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: Colors.grey,
              fontSize: highlight ? 16 : 14,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          value.toStringAsFixed(4),
          style: TextStyle(
            fontSize: highlight ? 20 : 16,
            fontWeight: highlight ? FontWeight.bold : FontWeight.normal,
            color: color,
          ),
        ),
      ],
    );
  }
}
