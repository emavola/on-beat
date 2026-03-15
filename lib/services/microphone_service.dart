import 'dart:async';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'hit_sensor.dart';

class MicrophoneService implements HitSensor {
  static final MicrophoneService _instance = MicrophoneService._internal();
  MicrophoneService._internal();
  factory MicrophoneService() => _instance;

  static const EventChannel _channel =
      EventChannel('com.example.on_beat/audio_hit');

  StreamSubscription? _subscription;

  static List<double> magnitudesForChart = [];

  @override
  void Function(double timestampMs)? onHitDetected;
  @override
  void Function(double magnitude)? onMagnitudeUpdate;

  @override
  Future<void> start() async {
    final status = await Permission.microphone.request();
    if (!status.isGranted) return;

    _subscription?.cancel();
    magnitudesForChart.clear();

    _subscription = _channel.receiveBroadcastStream().listen((event) {
      final data = List<double>.from(event as List);
      final timestampMs = data[0];
      final magnitude = data[1];

      magnitudesForChart.add(magnitude.clamp(0.0, 1.0));
      if (magnitudesForChart.length > 100) magnitudesForChart.removeAt(0);

      onMagnitudeUpdate?.call(magnitude.clamp(0.0, 1.0));
      onHitDetected?.call(timestampMs);
    });
  }

  @override
  void stop() {
    _subscription?.cancel();
    _subscription = null;
  }

  @override
  bool isRunning() => _subscription != null;
}
