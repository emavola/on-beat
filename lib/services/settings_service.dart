import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'hit_sensor.dart';

class SettingsService extends ChangeNotifier {
  static final SettingsService _instance = SettingsService._internal();
  SettingsService._internal();
  factory SettingsService() => _instance;

  // Defaults
  static const double defaultLatencyMs = 150.0;
  static const double defaultAccelThreshold = 0.9;
  static const double defaultMicThreshold = 0.15;
  static const double defaultMetronomeVolume = 1.0;
  static const SensorType defaultSensorType = SensorType.accelerometer;

  double _latencyMs = defaultLatencyMs;
  double _accelThreshold = defaultAccelThreshold;
  double _micThreshold = defaultMicThreshold;
  double _metronomeVolume = defaultMetronomeVolume;
  SensorType _sensorType = defaultSensorType;

  double get latencyMs => _latencyMs;
  double get accelThreshold => _accelThreshold;
  double get micThreshold => _micThreshold;
  double get metronomeVolume => _metronomeVolume;
  SensorType get sensorType => _sensorType;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _latencyMs = prefs.getDouble('latencyMs') ?? defaultLatencyMs;
    _accelThreshold = prefs.getDouble('accelThreshold') ?? defaultAccelThreshold;
    _micThreshold = prefs.getDouble('micThreshold') ?? defaultMicThreshold;
    _metronomeVolume = prefs.getDouble('metronomeVolume') ?? defaultMetronomeVolume;
    _sensorType = SensorType.values[prefs.getInt('sensorType') ?? 0];
    notifyListeners();
  }

  Future<void> setLatencyMs(double value) async {
    _latencyMs = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('latencyMs', value);
    notifyListeners();
  }

  Future<void> setAccelThreshold(double value) async {
    _accelThreshold = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('accelThreshold', value);
    notifyListeners();
  }

  Future<void> setMicThreshold(double value) async {
    _micThreshold = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('micThreshold', value);
    notifyListeners();
  }

  Future<void> setMetronomeVolume(double value) async {
    _metronomeVolume = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('metronomeVolume', value);
    notifyListeners();
  }

  Future<void> setSensorType(SensorType value) async {
    _sensorType = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('sensorType', value.index);
    notifyListeners();
  }

  Future<void> resetAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    _latencyMs = defaultLatencyMs;
    _accelThreshold = defaultAccelThreshold;
    _micThreshold = defaultMicThreshold;
    _metronomeVolume = defaultMetronomeVolume;
    _sensorType = defaultSensorType;
    notifyListeners();
  }
}
