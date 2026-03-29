import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/exercise_result.dart';
import '../models/session_doc.dart';
import 'auth_service.dart';

class SessionRepository {
  static final SessionRepository _instance = SessionRepository._internal();
  SessionRepository._internal();
  factory SessionRepository() => _instance;

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _sessions {
    final uid = AuthService().currentUid;
    if (uid == null) throw StateError('Not signed in');
    return _db.collection('users').doc(uid).collection('sessions');
  }

  DocumentReference<Map<String, dynamic>> get _userDoc {
    final uid = AuthService().currentUid;
    if (uid == null) throw StateError('Not signed in');
    return _db.collection('users').doc(uid);
  }

  /// Saves a completed session. Fire-and-forget — caller should not await
  /// unless it needs confirmation.
  Future<void> saveSession(ExerciseResult result, int durationSeconds) async {
    try {
      final batch = _db.batch();

      final sessionRef = _sessions.doc();
      batch.set(sessionRef, {
        'timestamp': FieldValue.serverTimestamp(),
        'mode': result.mode.name,
        'difficulty': result.difficulty.name,
        'sensorType': result.sensorType.name,
        'startBpm': result.startBpm,
        'finalBpm': result.finalBpm,
        'measuresCompleted': result.measuresCompleted,
        'durationSeconds': durationSeconds,
        // per-mode extras
        'lives': result.lives,
        'maxBpmReached': result.maxBpmReached,
        'perfectStreak': result.perfectStreak,
        'perfectCount': result.perfectCount,
        'okCount': result.okCount,
        'missCount': result.missCount,
        'grade': result.mode.name == 'challenge' ? result.challengeGrade : null,
      });

      // Update denormalized counters on the user doc
      batch.set(
        _userDoc,
        {
          'totalSessions': FieldValue.increment(1),
          'totalMeasures': FieldValue.increment(result.measuresCompleted),
          'lastSessionAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      await batch.commit();
    } catch (_) {
      // Never crash the UI if cloud save fails
    }
  }

  /// Returns the last [limit] sessions ordered by newest first.
  Future<List<SessionDoc>> getRecentSessions({int limit = 20}) async {
    try {
      final snap = await _sessions
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();
      return snap.docs.map((d) => SessionDoc.fromFirestore(d)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Returns aggregate stats for the stats screen.
  Future<StatsData> getStats() async {
    try {
      final userSnap = await _userDoc.get();
      final data = userSnap.data() ?? {};

      final totalSessions = (data['totalSessions'] as int?) ?? 0;
      final totalMeasures = (data['totalMeasures'] as int?) ?? 0;

      // Fetch recent sessions to compute streak + best scores
      final sessions = await getRecentSessions(limit: 100);

      return StatsData(
        totalSessions: totalSessions,
        totalMeasures: totalMeasures,
        currentStreak: _computeStreak(sessions),
        favoriteModeStr: _computeFavoriteMode(sessions),
        bestChallengePerfectPct: _bestChallengePerfectPct(sessions),
        bestIncrementalBpm: _bestIncrementalBpm(sessions),
        bestSurvivalMeasures: _bestSurvivalMeasures(sessions),
        recentSessions: sessions.take(20).toList(),
      );
    } catch (_) {
      return StatsData.empty();
    }
  }

  // ── helpers ───────────────────────────────────────────────────────────────

  int _computeStreak(List<SessionDoc> sessions) {
    final days = sessions
        .map((s) => s.timestamp)
        .whereType<DateTime>()
        .map((t) => DateTime(t.year, t.month, t.day))
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a));

    if (days.isEmpty) return 0;
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    if (days.first.isBefore(todayDate.subtract(const Duration(days: 1)))) {
      return 0;
    }

    int streak = 1;
    for (int i = 1; i < days.length; i++) {
      if (days[i - 1].difference(days[i]).inDays == 1) {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }

  String _computeFavoriteMode(List<SessionDoc> sessions) {
    if (sessions.isEmpty) return '-';
    final counts = <String, int>{};
    for (final s in sessions) {
      counts[s.mode] = (counts[s.mode] ?? 0) + 1;
    }
    return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  double _bestChallengePerfectPct(List<SessionDoc> sessions) {
    final challenge = sessions.where((s) => s.mode == 'challenge').toList();
    if (challenge.isEmpty) return 0;
    return challenge
        .map((s) => s.totalQuarters == 0 ? 0.0 : s.perfectCount / s.totalQuarters)
        .reduce((a, b) => a > b ? a : b);
  }

  int _bestIncrementalBpm(List<SessionDoc> sessions) {
    final inc = sessions.where((s) => s.mode == 'incremental').toList();
    if (inc.isEmpty) return 0;
    return inc.map((s) => s.finalBpm).reduce((a, b) => a > b ? a : b);
  }

  int _bestSurvivalMeasures(List<SessionDoc> sessions) {
    final surv = sessions.where((s) => s.mode == 'survival').toList();
    if (surv.isEmpty) return 0;
    return surv.map((s) => s.measuresCompleted).reduce((a, b) => a > b ? a : b);
  }
}

class StatsData {
  final int totalSessions;
  final int totalMeasures;
  final int currentStreak;
  final String favoriteModeStr;
  final double bestChallengePerfectPct;
  final int bestIncrementalBpm;
  final int bestSurvivalMeasures;
  final List<SessionDoc> recentSessions;

  const StatsData({
    required this.totalSessions,
    required this.totalMeasures,
    required this.currentStreak,
    required this.favoriteModeStr,
    required this.bestChallengePerfectPct,
    required this.bestIncrementalBpm,
    required this.bestSurvivalMeasures,
    required this.recentSessions,
  });

  factory StatsData.empty() => const StatsData(
        totalSessions: 0,
        totalMeasures: 0,
        currentStreak: 0,
        favoriteModeStr: '-',
        bestChallengePerfectPct: 0,
        bestIncrementalBpm: 0,
        bestSurvivalMeasures: 0,
        recentSessions: [],
      );
}
