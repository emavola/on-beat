import '../controllers/exercise_controller.dart';
import '../services/hit_sensor.dart';

class ExerciseResult {
  // Original config — needed for the Retry button
  final ExerciseMode mode;
  final ExerciseDifficulty difficulty;
  final int startBpm;
  final SensorType sensorType;

  // Snapshot of controller state at exercise end
  final int measuresCompleted;
  final int lives;
  final int finalBpm;
  final bool maxBpmReached;
  final bool challengeComplete;
  final int perfectCount;
  final int okCount;
  final int missCount;
  final int perfectStreak;

  const ExerciseResult({
    required this.mode,
    required this.difficulty,
    required this.startBpm,
    required this.sensorType,
    required this.measuresCompleted,
    required this.lives,
    required this.finalBpm,
    required this.maxBpmReached,
    required this.challengeComplete,
    required this.perfectCount,
    required this.okCount,
    required this.missCount,
    required this.perfectStreak,
  });

  int get totalQuarters => perfectCount + okCount + missCount;

  double get perfectPct =>
      totalQuarters == 0 ? 0 : perfectCount / totalQuarters;

  double get okPct => totalQuarters == 0 ? 0 : okCount / totalQuarters;

  double get missPct => totalQuarters == 0 ? 0 : missCount / totalQuarters;

  String get challengeGrade {
    if (totalQuarters == 0) return '-';
    if (perfectPct >= 0.90) return 'S';
    if (perfectPct >= 0.75) return 'A';
    if (perfectPct >= 0.60) return 'B';
    return 'C';
  }

  factory ExerciseResult.fromController(
    ExerciseController controller,
    SensorType sensorType,
  ) {
    return ExerciseResult(
      mode: controller.mode,
      difficulty: controller.difficulty,
      startBpm: controller.startBpm,
      sensorType: sensorType,
      measuresCompleted: controller.measuresCompleted,
      lives: controller.lives,
      finalBpm: controller.currentBpm,
      maxBpmReached: controller.maxBpmReached,
      challengeComplete: controller.challengeComplete,
      perfectCount: controller.perfectCount,
      okCount: controller.okCount,
      missCount: controller.missCount,
      perfectStreak: controller.perfectStreak,
    );
  }
}
