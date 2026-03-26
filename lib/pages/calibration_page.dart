import 'dart:async';
import 'package:flutter/material.dart';
import '../services/accelerometer_service.dart';
import '../services/hit_sensor.dart';
import '../services/metronome_service.dart';
import '../services/microphone_service.dart';
import '../services/settings_service.dart';

enum _LatencyCalibState { idle, countIn, recording, done }

class CalibrationPage extends StatefulWidget {
  const CalibrationPage({super.key});

  @override
  State<CalibrationPage> createState() => _CalibrationPageState();
}

class _CalibrationPageState extends State<CalibrationPage> {
  // ── Audio latency calibration ──────────────────────────────────────────────
  static const double _calibBpm = 80.0;
  static const int _countInBeats = 4;
  static const int _recordBeats = 8;
  final double _beatDurationMs = 60000.0 / _calibBpm;

  final MetronomeService _metronome = MetronomeService();
  _LatencyCalibState _latencyState = _LatencyCalibState.idle;

  int _beatCount = 0;           // count-in beats (1..4), then recording beats (1..8)
  double? _firstBeatTime;       // wall-clock ms of beat-1 in recording phase
  Timer? _beatTimer;
  final List<double> _tapDeltas = [];
  double? _suggestedLatencyMs;

  // ── Sensor threshold calibration ──────────────────────────────────────────
  SensorType _threshSensorType = SensorType.accelerometer;
  HitSensor? _threshSensor;
  double _liveMagnitude = 0;

  // Peak detection state (raw, bypasses service threshold)
  static const double _calibMinMag = 0.2; // minimum to count as a hit sample
  bool _inHit = false;
  double _currentPeak = 0;
  final List<double> _hitSamples = [];

  // ── Settings ──────────────────────────────────────────────────────────────
  final SettingsService _settings = SettingsService();

  // ── Init / dispose ────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _metronome.init();
    _startThreshSensor(SensorType.accelerometer);
  }

  @override
  void dispose() {
    _beatTimer?.cancel();
    _metronome.dispose();
    _stopThreshSensor();
    super.dispose();
  }

  void _startThreshSensor(SensorType type) {
    _stopThreshSensor();
    setState(() {
      _threshSensorType = type;
      _liveMagnitude = 0;
      _inHit = false;
      _currentPeak = 0;
      _hitSamples.clear();
    });

    HitSensor sensor;
    if (type == SensorType.microphone) {
      sensor = MicrophoneService();
    } else {
      sensor = AccelerometerService();
    }

    sensor.onMagnitudeUpdate = (mag) {
      if (!mounted) return;
      setState(() => _liveMagnitude = mag);
      // Accelerometer sends continuous data → use rise/fall peak detection
      if (type == SensorType.accelerometer) _detectPeak(mag);
    };

    if (type == SensorType.microphone) {
      // Mic fires onHitDetected once per detected hit (native side).
      // Record each hit magnitude directly — no peak detection needed.
      sensor.onHitDetected = (_) {
        if (!mounted) return;
        if (_liveMagnitude > 0) {
          setState(() => _hitSamples.add(_liveMagnitude));
        }
      };
    }

    sensor.start();
    _threshSensor = sensor;
  }

  void _stopThreshSensor() {
    _threshSensor?.onMagnitudeUpdate = null;
    _threshSensor?.onHitDetected = null;
    _threshSensor?.stop();
    _threshSensor = null;
  }

  // Simple peak detector: track rising edge above _calibMinMag, record peak when signal drops back
  void _detectPeak(double mag) {
    if (!_inHit && mag >= _calibMinMag) {
      _inHit = true;
      _currentPeak = mag;
    } else if (_inHit) {
      if (mag > _currentPeak) _currentPeak = mag;
      if (mag < _calibMinMag * 0.4) {
        // Signal has settled — record this hit
        if (mounted) {
          setState(() => _hitSamples.add(_currentPeak));
        }
        _inHit = false;
        _currentPeak = 0;
      }
    }
  }

  double get _suggestedThreshold {
    if (_hitSamples.isEmpty) return 0;
    final avg = _hitSamples.reduce((a, b) => a + b) / _hitSamples.length;
    // 70% of average: below average hit to catch softer ones, above noise
    return (avg * 0.70).clamp(0.1, 3.0);
  }

  // ── Latency calibration logic ─────────────────────────────────────────────

  void _startLatencyCalibration() {
    setState(() {
      _latencyState = _LatencyCalibState.countIn;
      _beatCount = 0;
      _tapDeltas.clear();
      _suggestedLatencyMs = null;
      _firstBeatTime = null;
    });
    _metronome.reset();
    _scheduleBeat();
  }

  void _scheduleBeat() {
    _beatTimer?.cancel();
    _beatTimer = Timer(Duration(milliseconds: _beatDurationMs.round()), _onBeat);
  }

  void _onBeat() {
    _metronome.play();

    if (_latencyState == _LatencyCalibState.countIn) {
      _beatCount++;
      setState(() {});
      if (_beatCount >= _countInBeats) {
        // Switch to recording on next beat
        _beatCount = 0;
        _firstBeatTime = null;
        setState(() => _latencyState = _LatencyCalibState.recording);
      }
      _scheduleBeat();
    } else if (_latencyState == _LatencyCalibState.recording) {
      _beatCount++;
      // Anchor first beat time
      _firstBeatTime ??= DateTime.now().millisecondsSinceEpoch.toDouble();
      setState(() {});
      if (_beatCount >= _recordBeats) {
        _finishLatencyCalibration();
      } else {
        _scheduleBeat();
      }
    }
  }

  void _onTap() {
    if (_latencyState != _LatencyCalibState.recording) return;
    if (_firstBeatTime == null) return;

    final now = DateTime.now().millisecondsSinceEpoch.toDouble();
    final elapsed = now - _firstBeatTime!;
    // Beat 1 happened at t=0, beat 2 at t=beatDuration, etc.
    final nearestBeat = (elapsed / _beatDurationMs).round() * _beatDurationMs;
    final delta = elapsed - nearestBeat;
    setState(() => _tapDeltas.add(delta));
  }

  void _finishLatencyCalibration() {
    _beatTimer?.cancel();
    if (_tapDeltas.isEmpty) {
      setState(() => _latencyState = _LatencyCalibState.idle);
      return;
    }
    final avg = _tapDeltas.reduce((a, b) => a + b) / _tapDeltas.length;
    setState(() {
      _suggestedLatencyMs = avg.clamp(-300.0, 300.0);
      _latencyState = _LatencyCalibState.done;
    });
  }

  void _applyLatency() {
    if (_suggestedLatencyMs == null) return;
    _settings.setLatencyMs(_suggestedLatencyMs!.abs());
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Latency set to ${_suggestedLatencyMs!.abs().round()} ms'),
      ),
    );
  }

  void _resetLatency() {
    _beatTimer?.cancel();
    setState(() {
      _latencyState = _LatencyCalibState.idle;
      _tapDeltas.clear();
      _suggestedLatencyMs = null;
      _beatCount = 0;
      _firstBeatTime = null;
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Calibration')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildLatencySection(context),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          _buildThresholdSection(context),
        ],
      ),
    );
  }

  // ── Latency section ───────────────────────────────────────────────────────

  Widget _buildLatencySection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Audio Latency',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          'Tap in time with the metronome for 8 beats. '
          'The app measures your average offset and suggests a compensation value.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        _buildLatencyBody(context),
      ],
    );
  }

  Widget _buildLatencyBody(BuildContext context) {
    switch (_latencyState) {
      case _LatencyCalibState.idle:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Current: ${_settings.latencyMs.round()} ms',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _startLatencyCalibration,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start calibration'),
            ),
          ],
        );

      case _LatencyCalibState.countIn:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text('Get ready…', style: TextStyle(fontSize: 18)),
            const SizedBox(height: 4),
            Text(
              'Count-in: $_beatCount / $_countInBeats',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            TextButton(onPressed: _resetLatency, child: const Text('Cancel')),
          ],
        );

      case _LatencyCalibState.recording:
        return GestureDetector(
          onTapDown: (_) => _onTap(),
          behavior: HitTestBehavior.opaque,
          child: Container(
            height: 120,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'TAP HERE',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Beat $_beatCount / $_recordBeats  •  ${_tapDeltas.length} taps',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        );

      case _LatencyCalibState.done:
        final ms = _suggestedLatencyMs;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (ms != null) ...[
              Text(
                'Suggested: ${ms.abs().round()} ms',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Text(
                ms >= 0
                    ? 'You tapped ${ms.abs().round()} ms after the beat on average.'
                    : 'You tapped ${ms.abs().round()} ms before the beat on average.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  ElevatedButton(
                    onPressed: _applyLatency,
                    child: const Text('Apply'),
                  ),
                  const SizedBox(width: 8),
                  TextButton(onPressed: _resetLatency, child: const Text('Retry')),
                ],
              ),
            ] else ...[
              const Text('No taps recorded.'),
              TextButton(onPressed: _resetLatency, child: const Text('Retry')),
            ],
          ],
        );
    }
  }

  // ── Threshold section ─────────────────────────────────────────────────────

  Widget _buildThresholdSection(BuildContext context) {
    const maxBar = 5.0;
    final barFraction = (_liveMagnitude / maxBar).clamp(0.0, 1.0);
    final suggested = _suggestedThreshold;
    final suggestedFraction = (suggested / maxBar).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sensor Threshold',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          'Hit your pad normally a few times. '
          'The app collects samples and suggests a threshold based on the average, '
          'so one hard hit won\'t skew it.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        // Sensor selector
        if (_threshSensorType == SensorType.microphone)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Note: mic magnitudes are 0–1. The suggested threshold will be applied to the accelerometer threshold setting.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
        SegmentedButton<SensorType>(
          segments: const [
            ButtonSegment(
              value: SensorType.accelerometer,
              label: Text('Accelerometer'),
              icon: Icon(Icons.vibration),
            ),
            ButtonSegment(
              value: SensorType.microphone,
              label: Text('Microphone'),
              icon: Icon(Icons.mic),
            ),
          ],
          selected: {_threshSensorType},
          onSelectionChanged: (s) => _startThreshSensor(s.first),
        ),
        const SizedBox(height: 16),
        Text(
          'Current threshold: ${_settings.accelThreshold.toStringAsFixed(2)}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        _MagnitudeBar(
          barFraction: barFraction,
          suggestedFraction: suggestedFraction,
          liveMagnitude: _liveMagnitude,
          suggestedThreshold: suggested,
          sampleCount: _hitSamples.length,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            ElevatedButton.icon(
              onPressed: _hitSamples.length >= 3
                  ? () {
                      _settings.setAccelThreshold(suggested);
                      setState(() => _hitSamples.clear());
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Threshold set to ${suggested.toStringAsFixed(2)}',
                          ),
                        ),
                      );
                    }
                  : null,
              icon: const Icon(Icons.check),
              label: Text(
                _hitSamples.length < 3
                    ? 'Need ${3 - _hitSamples.length} more hit${_hitSamples.length == 2 ? '' : 's'}'
                    : 'Apply (${_hitSamples.length} samples)',
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: _hitSamples.isNotEmpty
                  ? () => setState(() {
                        _hitSamples.clear();
                        _inHit = false;
                        _currentPeak = 0;
                      })
                  : null,
              child: const Text('Clear samples'),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Magnitude bar widget ───────────────────────────────────────────────────

class _MagnitudeBar extends StatelessWidget {
  final double barFraction;
  final double suggestedFraction;
  final double liveMagnitude;
  final double suggestedThreshold;
  final int sampleCount;

  const _MagnitudeBar({
    required this.barFraction,
    required this.suggestedFraction,
    required this.liveMagnitude,
    required this.suggestedThreshold,
    required this.sampleCount,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 28,
              child: Stack(
                children: [
                  // Background
                  Container(
                    width: width,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  // Live magnitude bar
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 40),
                    width: width * barFraction,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  // Suggested threshold marker
                  if (suggestedThreshold > 0)
                    Positioned(
                      left: (width * suggestedFraction - 2).clamp(0.0, width - 3),
                      top: 0,
                      child: Container(
                        width: 3,
                        height: 28,
                        color: Theme.of(context).colorScheme.tertiary,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Live: ${liveMagnitude.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (sampleCount > 0)
                  Text(
                    'Suggested: ${suggestedThreshold.toStringAsFixed(2)}  ($sampleCount samples)',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.tertiary,
                        ),
                  )
                else
                  Text(
                    'Hit your pad to collect samples',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}
