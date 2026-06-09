import 'package:flutter/material.dart';

import '../models/session_doc.dart';
import '../pages/exercise_setup_sheet.dart';
import '../pages/scan_rhythm_page.dart';
import '../services/session_repository.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeData {
  final int streak;
  final List<SessionDoc> todaySessions;
  final SessionDoc? lastSession;
  final String? nickname;

  const _HomeData({
    required this.streak,
    required this.todaySessions,
    required this.lastSession,
    required this.nickname,
  });
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<_HomeData> _dataFuture;

  @override
  void initState() {
    super.initState();
    _dataFuture = _loadData();
  }

  Future<_HomeData> _loadData() async {
    final repo = SessionRepository();
    final results = await Future.wait([
      repo.getTodaySessions(),
      repo.getRecentSessions(limit: 1),
      repo.getStats(),
      repo.getNickname(),
    ]);
    final today = results[0] as List<SessionDoc>;
    final recent = results[1] as List<SessionDoc>;
    final stats = results[2] as StatsData;
    final nickname = results[3] as String?;
    return _HomeData(
      streak: stats.currentStreak,
      todaySessions: today,
      lastSession: recent.firstOrNull,
      nickname: nickname,
    );
  }

  void _openSetup(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const ExerciseSetupSheet(),
    ).then((_) => setState(() => _dataFuture = _loadData()));
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 32),
            FutureBuilder<_HomeData>(
              future: _dataFuture,
              builder: (context, snap) {
                final data = snap.data;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(context, data?.nickname),
                    const SizedBox(height: 32),
                    _buildTodayRow(context, data),
                    const SizedBox(height: 16),
                    _buildLastSession(context, data?.lastSession),
                  ],
                );
              },
            ),
            const Spacer(),
            _buildStartButton(context),
            const SizedBox(height: 12),
            _buildScanButton(context),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, String? nickname) {
    final name = nickname?.isNotEmpty == true ? nickname! : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name != null ? '$_greeting, $name' : _greeting,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          'OnBeat',
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
        ),
      ],
    );
  }

  Widget _buildTodayRow(BuildContext context, _HomeData? data) {
    final streak = data?.streak ?? 0;
    final todayCount = data?.todaySessions.length ?? 0;
    final todayMeasures = data?.todaySessions
            .fold(0, (sum, s) => sum + s.measuresCompleted) ??
        0;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _StatCard(
              icon: Icons.local_fire_department,
              value: '$streak',
              label: 'day streak',
              highlight: streak > 0,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatCard(
              icon: Icons.today,
              value: '$todayCount',
              label: 'today',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatCard(
              icon: Icons.music_note,
              value: '$todayMeasures',
              label: 'measures',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLastSession(BuildContext context, SessionDoc? last) {
    if (last == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'No sessions yet — hit Start Practice to begin!',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    final mode = last.mode[0].toUpperCase() + last.mode.substring(1);
    final keyStat = switch (last.mode) {
      'challenge' => last.grade ?? '-',
      'incremental' => '${last.finalBpm} BPM',
      _ => '${last.measuresCompleted} measures',
    };

    String timeAgo = '';
    if (last.timestamp != null) {
      final d = DateTime.now().difference(last.timestamp!);
      if (d.inMinutes < 60) {
        timeAgo = '${d.inMinutes}m ago';
      } else if (d.inHours < 24) {
        timeAgo = '${d.inHours}h ago';
      } else if (d.inDays == 1) {
        timeAgo = 'Yesterday';
      } else {
        timeAgo = '${d.inDays}d ago';
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.history,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Last session',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                Text(
                  '$mode · ${last.difficulty} · ${last.startBpm} BPM',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                keyStat,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              Text(
                timeAgo,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStartButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => _openSetup(context),
        icon: const Icon(Icons.play_arrow),
        label: const Text('Start Practice'),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 18),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildScanButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ScanRhythmPage()),
        ),
        icon: const Icon(Icons.document_scanner_outlined),
        label: const Text('Scan a rhythm'),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final bool highlight;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: highlight
            ? Theme.of(context).colorScheme.primaryContainer
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 20,
            color: highlight
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: highlight
                  ? Theme.of(context).colorScheme.primary
                  : null,
            ),
          ),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
