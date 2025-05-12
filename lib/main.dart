import 'package:flutter/material.dart';
import 'package:on_beat/navigation/app_router.dart';
import 'package:on_beat/themes/app_theme.dart';
import 'navigation/app_routes.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OnBeat',
      theme: appTheme,
      initialRoute: AppRoutes.main,
      routes: AppRouter.routes,
    );
  }
}
