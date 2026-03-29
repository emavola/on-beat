import 'package:flutter/material.dart';

import '../models/session_doc.dart';
import '../services/session_repository.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  late Future<StatsData> _statsFuture;

  @override
  void initState() {
    super.initState();
    _statsFuture = SessionRepository().getStats();
  }

  void _refresh() {
    setState(() {
      _statsFuture = SessionRepository().getStats();
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: FutureBuilder<StatsData>(
        future: _statsFuture,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final stats = snap.data ?? StatsData.empty();
          return RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildSummaryCards(context, stats),
                const SizedBox(height: 24),
                _buildBestScores(context, stats),
                const SizedBox(height: 24),
                _buildRecentSessions(context, stats.recentSessions),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Summary cards ─────────────────────────────────────────────────────────

  Widget _buildSummaryCards(BuildContext context, StatsData stats) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(context, 'Overview'),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _SummaryCard(
                icon: Icons.sports_score,
                label: 'Sessions',
                value: '${stats.totalSessions}',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _SummaryCard(
                icon: Icons.music_note,
                label: 'Measures',
                value: '${stats.totalMeasures}',
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _SummaryCard(
                icon: Icons.local_fire_department,
                label: 'Streak',
                value: '${stats.currentStreak} day${stats.currentStreak == 1 ? '' : 's'}',
                highlight: stats.currentStreak > 0,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _SummaryCard(
                icon: Icons.star_outline,
                label: 'Fav mode',
                value: _capitalize(stats.favoriteModeStr),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Best scores ───────────────────────────────────────────────────────────

  Widget _buildBestScores(BuildContext context, StatsData stats) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(context, 'Best Scores'),
        const SizedBox(height: 12),
        _BestRow(
          icon: Icons.trending_up,
          label: 'Incremental — max BPM',
          value: stats.bestIncrementalBpm > 0
              ? '${stats.bestIncrementalBpm} BPM'
              : '-',
        ),
        _BestRow(
          icon: Icons.favorite_outline,
          label: 'Survival — longest run',
          value: stats.bestSurvivalMeasures > 0
              ? '${stats.bestSurvivalMeasures} measures'
              : '-',
        ),
        _BestRow(
          icon: Icons.emoji_events_outlined,
          label: 'Challenge — best perfect%',
          value: stats.bestChallengePerfectPct > 0
              ? '${(stats.bestChallengePerfectPct * 100).round()}%'
              : '-',
        ),
      ],
    );
  }

  // ── Recent sessions ───────────────────────────────────────────────────────

  Widget _buildRecentSessions(BuildContext context, List<SessionDoc> sessions) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(context, 'Recent Sessions'),
        const SizedBox(height: 12),
        if (sessions.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Text(
                'No sessions yet.\nComplete an exercise to see history here.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ),
          )
        else
          ...sessions.map((s) => _SessionRow(session: s)),
      ],
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Widget _sectionHeader(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Theme.of(context).colorScheme.primary,
          ),
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? '-' : s[0].toUpperCase() + s.substring(1);
}

// ── Summary card ──────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool highlight;

  const _SummaryCard({
    required this.icon,
    required this.label,
    required this.value,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: highlight
            ? Theme.of(context).colorScheme.primaryContainer
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon,
              size: 22,
              color: highlight
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: highlight
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  )),
              Text(label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      )),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Best score row ────────────────────────────────────────────────────────

class _BestRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _BestRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label, style: const TextStyle(fontSize: 14)),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

// ── Session row ───────────────────────────────────────────────────────────

class _SessionRow extends StatelessWidget {
  final SessionDoc session;

  const _SessionRow({required this.session});

  IconData get _modeIcon => switch (session.mode) {
        'zen' => Icons.self_improvement,
        'incremental' => Icons.trending_up,
        'survival' => Icons.favorite,
        'challenge' => Icons.emoji_events,
        _ => Icons.sports_score,
      };

  String get _keyStat => switch (session.mode) {
        'challenge' => session.grade ?? '-',
        'incremental' => '${session.finalBpm} BPM',
        'survival' => '${session.measuresCompleted} measures',
        _ => '${session.measuresCompleted} measures',
      };

  String _formatDate(DateTime? dt) {
    if (dt == null) return '';
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(_modeIcon,
              size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${session.mode[0].toUpperCase()}${session.mode.substring(1)} — ${session.difficulty}',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                ),
                Text(
                  '${session.startBpm} BPM • ${session.durationSeconds}s',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(_keyStat,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.bold)),
              Text(_formatDate(session.timestamp),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      )),
            ],
          ),
        ],
      ),
    );
  }
}
