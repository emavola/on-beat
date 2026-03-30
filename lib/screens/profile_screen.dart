import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/session_repository.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _auth = AuthService();
  late Future<StatsData> _statsFuture;
  String? _nickname;

  @override
  void initState() {
    super.initState();
    _statsFuture = SessionRepository().getStats();
    _auth.userChanges.listen((_) {
      if (mounted) setState(() {});
    });
    _loadNickname();
  }

  Future<void> _loadNickname() async {
    final n = await SessionRepository().getNickname();
    if (mounted) setState(() => _nickname = n);
  }

  Future<void> _editNickname() async {
    final controller = TextEditingController(text: _nickname ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Set nickname'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 24,
          decoration: const InputDecoration(hintText: 'Your nickname'),
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      await SessionRepository().setNickname(result);
      if (mounted) setState(() => _nickname = result);
    }
  }

  Future<void> _signInWithGoogle() async {
    try {
      await _auth.linkWithGoogle();
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sign-in failed: $e')),
        );
      }
    }
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          'You will be signed out. If you are anonymous your data may be lost.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _auth.signOut();
      await _auth.signInAnonymously();
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    final isGoogle = _auth.isSignedInWithGoogle;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildAccountCard(context, user, isGoogle),
          const SizedBox(height: 24),
          FutureBuilder<StatsData>(
            future: _statsFuture,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              return _buildPersonalBests(context, snap.data ?? StatsData.empty());
            },
          ),
          const SizedBox(height: 24),
          _buildAppInfo(context),
        ],
      ),
    );
  }

  // ── Account card ──────────────────────────────────────────────────────────

  Widget _buildAccountCard(BuildContext context, User? user, bool isGoogle) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // Avatar
          CircleAvatar(
            radius: 36,
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            backgroundImage: isGoogle && user?.photoURL != null
                ? NetworkImage(user!.photoURL!)
                : null,
            child: isGoogle && user?.photoURL != null
                ? null
                : Text(
                    isGoogle
                        ? (user?.displayName?.isNotEmpty == true
                            ? user!.displayName![0].toUpperCase()
                            : '?')
                        : '?',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
          ),
          const SizedBox(height: 12),
          // Nickname
          GestureDetector(
            onTap: _editNickname,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _nickname?.isNotEmpty == true
                      ? _nickname!
                      : (isGoogle ? (user?.displayName ?? 'Google user') : 'Anonymous'),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 6),
                Icon(Icons.edit, size: 16,
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isGoogle
                ? (user?.email ?? '')
                : 'Sign in to save your data across devices',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          // Action button
          if (!isGoogle)
            ElevatedButton.icon(
              onPressed: _signInWithGoogle,
              icon: const Icon(Icons.login),
              label: const Text('Sign in with Google'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 44),
              ),
            )
          else
            OutlinedButton.icon(
              onPressed: _signOut,
              icon: const Icon(Icons.logout),
              label: const Text('Sign out'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 44),
              ),
            ),
        ],
      ),
    );
  }

  // ── Personal bests ─────────────────────────────────────────────────────────

  Widget _buildPersonalBests(BuildContext context, StatsData stats) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Personal Bests',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
        ),
        const SizedBox(height: 12),
        _TrophyRow(
          icon: Icons.trending_up,
          label: 'Incremental — max BPM',
          value: stats.bestIncrementalBpm > 0
              ? '${stats.bestIncrementalBpm} BPM'
              : '-',
        ),
        _TrophyRow(
          icon: Icons.favorite_outline,
          label: 'Survival — longest run',
          value: stats.bestSurvivalMeasures > 0
              ? '${stats.bestSurvivalMeasures} measures'
              : '-',
        ),
        _TrophyRow(
          icon: Icons.emoji_events_outlined,
          label: 'Challenge — best perfect%',
          value: stats.bestChallengePerfectPct > 0
              ? '${(stats.bestChallengePerfectPct * 100).round()}%'
              : '-',
        ),
        _TrophyRow(
          icon: Icons.sports_score,
          label: 'Total sessions',
          value: '${stats.totalSessions}',
        ),
        _TrophyRow(
          icon: Icons.music_note,
          label: 'Total measures',
          value: stats.totalMeasures >= 1000
              ? '${(stats.totalMeasures / 1000).toStringAsFixed(1)}k'
              : '${stats.totalMeasures}',
        ),
      ],
    );
  }

  // ── App info ──────────────────────────────────────────────────────────────

  Widget _buildAppInfo(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'App',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
        ),
        const SizedBox(height: 8),
        _InfoRow(label: 'Version', value: '1.0.0'),
        _InfoRow(
          label: 'Account ID',
          value: _auth.currentUid != null
              ? '${_auth.currentUid!.substring(0, 8)}…'
              : '-',
        ),
      ],
    );
  }
}

// ── Widgets ───────────────────────────────────────────────────────────────

class _TrophyRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _TrophyRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Icon(icon, size: 18,
              color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 14))),
          Text(value,
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
