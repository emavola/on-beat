import 'dart:async';
import 'dart:collection';
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
  static final Duration _hitCooldown = Duration(milliseconds: 0);
  static const double _treshold = 0.02;
  void Function()? onHitDetected;
  static List<double> magnitudesForChart = [0, 0];
  static Queue<double> avgBuffer = Queue();
  static double previousMagnitude = 0;
  static const double alphaLowPass = 0.01;

  void start() {
    avgBuffer.addAll([0, 0, 0, 0, 0, 0, 0]);
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

    // avg buffer to make the graph smoother
    avgBuffer.removeLast();
    avgBuffer.add(magnitude);
    double avg = avgBuffer.reduce((a, b) => a + b) / avgBuffer.length;
    // Low-pass filter
    double smoothed =
        alphaLowPass * previousMagnitude + (1 - alphaLowPass) * avg;
    smoothed = smoothed >= 0.003 ? smoothed : 0;
    magnitudesForChart.add(smoothed);
    if (smoothed < 0) {
      print("Minore di zero strunz");
    }
    if (magnitudesForChart.length > 100) {
      magnitudesForChart.removeAt(0);
    }

    //update every tick
    onHitDetected?.call();
    /* Previous shot detection with trashold
    if (magnitude > _treshold && now.difference(_lastHitTime) > _hitCooldown) {
      print('💥 Colpo rilevato!');
      onHitDetected?.call();
      _lastHitTime = now;
    }*/

    List<double> dev = getDerivative();
    if (dev.last > 0 && dev[dev.length - 2] <= 0) {
      print('💥 Colpo rilevato!');
      onHitDetected?.call();
      _lastHitTime = now;
    }
    previousMagnitude = magnitude;
  }

  List<double> getDerivative() {
    List<double> slopes = [];

    for (int i = 1; i < magnitudesForChart.length; i++) {
      double delta = magnitudesForChart[i] - magnitudesForChart[i - 1];
      slopes.add(delta);
    }
    return slopes;
  }

  bool isRunning() => _subscription != null;
}
