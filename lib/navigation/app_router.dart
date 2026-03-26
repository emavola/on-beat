import 'package:flutter/material.dart';
import '/pages/main_page.dart';
import '/pages/exercise_page.dart';
import '/pages/accelerometer_test_page.dart';
import '/pages/microphone_test_page.dart';
import '/pages/calibration_page.dart';
import 'app_routes.dart';

class AppRouter {
  static final routes = <String, WidgetBuilder>{
    AppRoutes.main: (context) => const MainPage(),
    AppRoutes.exercise: (context) => const ExercisePage(),
    AppRoutes.accelerometerTest: (context) => const AccelerometerTestPage(),
    AppRoutes.microphoneTest: (context) => const MicrophoneTestPage(),
    AppRoutes.calibration: (context) => const CalibrationPage(),
  };
}
