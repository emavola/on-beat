import 'dart:async';
import 'dart:collection';
import 'package:sensors_plus/sensors_plus.dart';
import 'hit_sensor.dart';
import 'settings_service.dart';

class AccelerometerService implements HitSensor {
  static final AccelerometerService _instance =
      AccelerometerService._internal();

  AccelerometerService._internal();

  factory AccelerometerService() {
    return _instance;
  }

  static StreamSubscription<UserAccelerometerEvent>? _subscription;
  static DateTime _lastHitTime = DateTime.fromMillisecondsSinceEpoch(0);
  static const Duration _hitCooldown = Duration(milliseconds: 100);
  static const double threshold = 0.9;

  // Sliding window buffer for smoothing (size 7)
  static final Queue<double> _avgBuffer = Queue();
  static const int _bufferSize = 7;

  static double _previousSmoothed = 0;
  static const double _alphaLowPass = 0.2;

  @override
  void Function(double timestampMs)? onHitDetected;
  @override
  void Function(double magnitude)? onMagnitudeUpdate;

  // Public magnitudes for chart display
  static List<double> magnitudesForChart = [];

  @override
  Future<void> start() async {
    _avgBuffer.clear();
    for (int i = 0; i < _bufferSize; i++) {
      _avgBuffer.add(0);
    }
    _previousSmoothed = 0;
    magnitudesForChart.clear();
    _subscription?.cancel();
    _subscription = userAccelerometerEventStream(
      samplingPeriod: SensorInterval.fastestInterval,
    ).listen(_detectHit);
  }

  @override
  void stop() {
    _subscription?.cancel();
    _subscription = null;
  }

  void _detectHit(UserAccelerometerEvent event) {
    final now = DateTime.now();

    // Only Z axis for vertical drum strike detection
    final double magnitude = event.z.abs();

    // Proper sliding window: remove oldest, add newest
    _avgBuffer.removeFirst();
    _avgBuffer.add(magnitude);
    final double avg = _avgBuffer.reduce((a, b) => a + b) / _bufferSize;

    // Low-pass filter: smooth the signal using previous smoothed value
    final double smoothed =
        _alphaLowPass * avg + (1 - _alphaLowPass) * _previousSmoothed;
    _previousSmoothed = smoothed;

    magnitudesForChart.add(smoothed);
    if (magnitudesForChart.length > 100) {
      magnitudesForChart.removeAt(0);
    }

    onMagnitudeUpdate?.call(magnitude);

    // Threshold + cooldown on raw magnitude.
    final bool cooledDown = now.difference(_lastHitTime) > _hitCooldown;
    if (magnitude > SettingsService().accelThreshold && cooledDown) {
      _lastHitTime = now;
      onHitDetected?.call(now.millisecondsSinceEpoch.toDouble());
    }
  }

  List<double> getDerivative() {
    final List<double> slopes = [];
    for (int i = 1; i < magnitudesForChart.length; i++) {
      slopes.add(magnitudesForChart[i] - magnitudesForChart[i - 1]);
    }
    return slopes;
  }

  @override
  bool isRunning() => _subscription != null;
}
