enum SensorType { accelerometer, microphone, mixed }

/// Abstract interface for input sensors that detect drum hits.
abstract class HitSensor {
  /// Called with the precise hit timestamp in milliseconds since epoch.
  void Function(double timestampMs)? onHitDetected;
  void Function(double magnitude)? onMagnitudeUpdate;

  Future<void> start();
  void stop();
  bool isRunning();
}
