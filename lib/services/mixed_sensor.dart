import 'accelerometer_service.dart';
import 'microphone_service.dart';
import 'hit_sensor.dart';

/// Combines accelerometer and microphone: fires [onHitDetected] when either
/// sensor detects a hit, with a shared cooldown to prevent double-fires from
/// the same physical strike triggering both sensors simultaneously.
class MixedSensor implements HitSensor {
  final AccelerometerService _accel = AccelerometerService();
  final MicrophoneService _mic = MicrophoneService();

  static DateTime _lastHitTime = DateTime.fromMillisecondsSinceEpoch(0);
  static const Duration _hitCooldown = Duration(milliseconds: 100);

  bool _running = false;

  @override
  void Function(double timestampMs)? onHitDetected;
  @override
  void Function(double magnitude)? onMagnitudeUpdate;

  void _onHit(double timestampMs) {
    final now = DateTime.now();
    if (now.difference(_lastHitTime) > _hitCooldown) {
      _lastHitTime = now;
      onHitDetected?.call(timestampMs);
    }
  }

  @override
  Future<void> start() async {
    _accel.onHitDetected = _onHit;
    _accel.onMagnitudeUpdate = (mag) => onMagnitudeUpdate?.call(mag);
    _mic.onHitDetected = _onHit;
    await _mic.start();
    await _accel.start();
    _running = true;
  }

  @override
  void stop() {
    _accel.stop();
    _mic.stop();
    _running = false;
  }

  @override
  bool isRunning() => _running;
}
