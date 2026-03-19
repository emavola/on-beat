import 'package:flutter/material.dart';

import '../controllers/exercise_controller.dart';
import '../models/exercise_result.dart';
import 'exercise_page.dart';

class ExerciseResultPage extends StatelessWidget {
  final ExerciseResult result;

  const ExerciseResultPage({super.key, required this.result});

  void _retry(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ExercisePage(
          mode: result.mode,
          difficulty: result.difficulty,
          bpm: result.startBpm,
          sensorType: result.sensorType,
        ),
      ),
    );
  }

  void _home(BuildContext context) {
    Navigator.popUntil(context, ModalRoute.withName('/'));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Results'), centerTitle: true),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Column(
            children: [
              Expanded(child: _buildBody(context)),
              _buildButtons(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    return switch (result.mode) {
      ExerciseMode.normal => _NormalResult(result: result),
      ExerciseMode.zen => _ZenResult(result: result),
      ExerciseMode.incremental => _IncrementalResult(result: result),
      ExerciseMode.survival => _SurvivalResult(result: result),
      ExerciseMode.challenge => _ChallengeResult(result: result),
    };
  }

  Widget _buildButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => _home(context),
            child: const Text('Home'),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton(
            onPressed: () => _retry(context),
            child: const Text('Retry'),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// Normal
// ─────────────────────────────────────────────
class _NormalResult extends StatelessWidget {
  final ExerciseResult result;
  const _NormalResult({required this.result});

  @override
  Widget build(BuildContext context) {
    final passed = result.lives > 0;
    return _ResultLayout(
      icon: passed ? Icons.check_circle_outline : Icons.cancel_outlined,
      iconColor: passed ? Colors.greenAccent : Colors.redAccent,
      title: passed ? 'Complete!' : 'Failed',
      stats: [
        _Stat('Measures', '${result.measuresCompleted}'),
        _Stat('Lives left', '${result.lives}'),
        _Stat('BPM', '${result.finalBpm}'),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// Zen
// ─────────────────────────────────────────────
class _ZenResult extends StatelessWidget {
  final ExerciseResult result;
  const _ZenResult({required this.result});

  @override
  Widget build(BuildContext context) {
    return _ResultLayout(
      icon: Icons.self_improvement,
      iconColor: Colors.blueAccent,
      title: 'Session Complete',
      stats: [
        _Stat('Measures played', '${result.measuresCompleted}'),
        _Stat('BPM', '${result.finalBpm}'),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// Incremental
// ─────────────────────────────────────────────
class _IncrementalResult extends StatelessWidget {
  final ExerciseResult result;
  const _IncrementalResult({required this.result});

  @override
  Widget build(BuildContext context) {
    final won = result.maxBpmReached;
    return _ResultLayout(
      icon: won ? Icons.emoji_events_outlined : Icons.trending_up,
      iconColor: won ? Colors.amber : Colors.orangeAccent,
      title: won ? 'Max BPM Reached!' : 'Stopped at ${result.finalBpm} BPM',
      stats: [
        _Stat('Max BPM', '${result.finalBpm}'),
        _Stat('Start BPM', '${result.startBpm}'),
        _Stat('Measures', '${result.measuresCompleted}'),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// Survival
// ─────────────────────────────────────────────
class _SurvivalResult extends StatelessWidget {
  final ExerciseResult result;
  const _SurvivalResult({required this.result});

  @override
  Widget build(BuildContext context) {
    final survived = result.lives > 0;
    return _ResultLayout(
      icon: survived ? Icons.favorite_outline : Icons.heart_broken_outlined,
      iconColor: survived ? Colors.pinkAccent : Colors.redAccent,
      title: survived ? 'Survived!' : 'Game Over',
      stats: [
        _Stat('Measures survived', '${result.measuresCompleted}'),
        _Stat('Lives left', '${result.lives}'),
        _Stat('Max streak', '${result.perfectStreak}'),
        _Stat('Final BPM', '${result.finalBpm}'),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// Challenge
// ─────────────────────────────────────────────
class _ChallengeResult extends StatelessWidget {
  final ExerciseResult result;
  const _ChallengeResult({required this.result});

  Color _gradeColor() => switch (result.challengeGrade) {
        'S' => Colors.amber,
        'A' => Colors.greenAccent,
        'B' => Colors.blueAccent,
        _ => Colors.redAccent,
      };

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          result.challengeGrade,
          style: TextStyle(
            fontSize: 96,
            fontWeight: FontWeight.bold,
            color: _gradeColor(),
          ),
        ),
        const SizedBox(height: 32),
        _BarStat(
          label: 'Perfect',
          count: result.perfectCount,
          total: result.totalQuarters,
          color: Colors.greenAccent,
        ),
        const SizedBox(height: 12),
        _BarStat(
          label: 'Ok',
          count: result.okCount,
          total: result.totalQuarters,
          color: Colors.orangeAccent,
        ),
        const SizedBox(height: 12),
        _BarStat(
          label: 'Miss',
          count: result.missCount,
          total: result.totalQuarters,
          color: Colors.redAccent,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// Shared layout helpers
// ─────────────────────────────────────────────
class _ResultLayout extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final List<_Stat> stats;

  const _ResultLayout({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.stats,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 80, color: iconColor),
        const SizedBox(height: 16),
        Text(
          title,
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 40),
        ...stats.map((s) => _StatRow(stat: s)),
      ],
    );
  }
}

class _Stat {
  final String label;
  final String value;
  const _Stat(this.label, this.value);
}

class _StatRow extends StatelessWidget {
  final _Stat stat;
  const _StatRow({required this.stat});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(stat.label, style: const TextStyle(color: Colors.grey, fontSize: 16)),
          Text(stat.value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _BarStat extends StatelessWidget {
  final String label;
  final int count;
  final int total;
  final Color color;

  const _BarStat({
    required this.label,
    required this.count,
    required this.total,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0.0 : count / total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 14, color: Colors.grey)),
            Text(
              '$count (${(pct * 100).round()}%)',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 8,
            backgroundColor: Colors.grey.shade800,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }
}
