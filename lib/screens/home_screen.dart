import 'package:flutter/material.dart';
import '../navigation/app_routes.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ElevatedButton(
            onPressed: () => Navigator.pushNamed(context, AppRoutes.exercise),
            child: const Text('Go to exercise!'),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () =>
                Navigator.pushNamed(context, AppRoutes.accelerometerTest),
            child: const Text('Accelerometer test'),
          ),
        ],
      ),
    );
  }
}
