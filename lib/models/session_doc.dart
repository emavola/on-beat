import 'package:cloud_firestore/cloud_firestore.dart';

class SessionDoc {
  final String id;
  final DateTime? timestamp;
  final String mode;
  final String difficulty;
  final String sensorType;
  final int startBpm;
  final int finalBpm;
  final int measuresCompleted;
  final int durationSeconds;
  final int lives;
  final bool maxBpmReached;
  final int perfectStreak;
  final int perfectCount;
  final int okCount;
  final int missCount;
  final String? grade;

  const SessionDoc({
    required this.id,
    required this.timestamp,
    required this.mode,
    required this.difficulty,
    required this.sensorType,
    required this.startBpm,
    required this.finalBpm,
    required this.measuresCompleted,
    required this.durationSeconds,
    required this.lives,
    required this.maxBpmReached,
    required this.perfectStreak,
    required this.perfectCount,
    required this.okCount,
    required this.missCount,
    required this.grade,
  });

  factory SessionDoc.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return SessionDoc(
      id: doc.id,
      timestamp: (d['timestamp'] as Timestamp?)?.toDate(),
      mode: (d['mode'] as String?) ?? '',
      difficulty: (d['difficulty'] as String?) ?? '',
      sensorType: (d['sensorType'] as String?) ?? '',
      startBpm: (d['startBpm'] as int?) ?? 0,
      finalBpm: (d['finalBpm'] as int?) ?? 0,
      measuresCompleted: (d['measuresCompleted'] as int?) ?? 0,
      durationSeconds: (d['durationSeconds'] as int?) ?? 0,
      lives: (d['lives'] as int?) ?? 0,
      maxBpmReached: (d['maxBpmReached'] as bool?) ?? false,
      perfectStreak: (d['perfectStreak'] as int?) ?? 0,
      perfectCount: (d['perfectCount'] as int?) ?? 0,
      okCount: (d['okCount'] as int?) ?? 0,
      missCount: (d['missCount'] as int?) ?? 0,
      grade: d['grade'] as String?,
    );
  }

  int get totalQuarters => perfectCount + okCount + missCount;
  double get perfectPct => totalQuarters == 0 ? 0 : perfectCount / totalQuarters;
}
