import 'dart:async';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';

class AccelerometerService {
  static final AccelerometerService _instance =
      AccelerometerService._internal();

  AccelerometerService._internal();

  factory AccelerometerService() {
    return _instance;
  }

  static StreamSubscription<UserAccelerometerEvent>? _subscription;
  static DateTime _lastHitTime = DateTime.now();
  static final Duration _hitCooldown = Duration(milliseconds: 300);
  static const double _treshold = 0.02;
  void Function()? onHitDetected;
  static List<double> magnitudesForChart = [0];

  void start() {
    _subscription?.cancel();
    _subscription = userAccelerometerEventStream().listen(_detectHit);
  }

  void stop() {
    _subscription?.cancel();
  }

  void _detectHit(UserAccelerometerEvent event) {
    final now = DateTime.now();
    double magnitude = sqrt(
      event.x * event.x * 0 + event.y * event.y * 0 + event.z * event.z * 3,
    );

    magnitudesForChart.add(magnitude);
    if (magnitudesForChart.length > 100) {
      magnitudesForChart.removeAt(0);
    }
    onHitDetected?.call();
    if (magnitude > _treshold && now.difference(_lastHitTime) > _hitCooldown) {
      print('💥 Colpo rilevato!');
      onHitDetected?.call();
      _lastHitTime = now;
    }
  }

  bool isRunning() => _subscription != null;
}
