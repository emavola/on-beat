import 'dart:async';

import 'package:flutter/material.dart';

import '../services/microphone_service.dart';

class MicrophoneTestPage extends StatefulWidget {
  const MicrophoneTestPage({super.key});

  @override
  State<MicrophoneTestPage> createState() => _MicrophoneTestPageState();
}

class _MicrophoneTestPageState extends State<MicrophoneTestPage> {
  final MicrophoneService mic = MicrophoneService();

  int _hitCount = 0;
  bool _flash = false;
  Timer? _flashTimer;

  double _currentMag = 0;
  double _peakMag = 0;

  @override
  void initState() {
    super.initState();
    mic.onHitDetected = _onHit;
    mic.onMagnitudeUpdate = _onMagnitude;
    mic.start();
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
      appBar: AppBar(title: const Text('Microphone Test')),
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
                color: _flash ? Colors.blueAccent : Colors.grey.shade800,
                boxShadow: _flash
                    ? [
                        BoxShadow(
                          color: Colors.blueAccent.withValues(alpha: 0.6),
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
              value: 0.15, // matches AudioHitDetector.THRESHOLD in Kotlin
              color: Colors.orangeAccent,
            ),
            const SizedBox(height: 32),
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
    mic.onHitDetected = null;
    mic.onMagnitudeUpdate = null;
    mic.stop();
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
