import 'package:flutter/material.dart';
import '/pages/main_page.dart';
import '/pages/exercise_page.dart';
import 'app_routes.dart';

class AppRouter {
  static final routes = <String, WidgetBuilder>{
    AppRoutes.main: (context) => const MainPage(),
    AppRoutes.exercize: (context) => ExercisePage(),
  };
}
