import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:on_beat/navigation/app_router.dart';
import 'package:on_beat/services/auth_service.dart';
import 'package:on_beat/services/settings_service.dart';
import 'package:on_beat/themes/app_theme.dart';
import 'navigation/app_routes.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await SettingsService().load();
  await AuthService().signInAnonymously();
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
