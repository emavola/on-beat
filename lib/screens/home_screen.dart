import 'package:flutter/material.dart';
import '../pages/exercise_setup_sheet.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _openSetup(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const ExerciseSetupSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ElevatedButton.icon(
        onPressed: () => _openSetup(context),
        icon: const Icon(Icons.play_arrow),
        label: const Text('Start Practice'),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        ),
      ),
    );
  }
}
