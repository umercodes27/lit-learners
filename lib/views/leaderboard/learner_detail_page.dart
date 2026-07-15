import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../models/leaderboard_entry.dart';

class LearnerDetailPage extends StatelessWidget {
  const LearnerDetailPage({
    required this.entry,
    required this.rank,
    super.key,
  });

  final LeaderboardEntry entry;
  final int rank;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cloud,
      body: Column(
        children: [
          DecoratedBox(
            decoration: const BoxDecoration(color: AppColors.ink),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 22),
                child: Column(
                  children: [
                    Row(
                      children: [
                        IconButton(
                          tooltip: 'Back',
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(
                            Icons.arrow_back,
                            color: Colors.white,
                          ),
                        ),
                        const Expanded(
                          child: Column(
                            children: [
                              Text(
                                'Learner Profile',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                'Anonymized leaderboard view',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 48),
                      ],
                    ),
                    const SizedBox(height: 14),
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: _avatarColor(entry.displayName),
                      child: Text(
                        _initials(entry.displayName),
                        style: const TextStyle(
                          color: AppColors.ink,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Rank #$rank - Stage ${entry.ageStage}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    _StatTile(
                      value: entry.completedLevels.toString(),
                      label: 'Levels',
                    ),
                    const SizedBox(width: 8),
                    _StatTile(
                      value: entry.totalStars.toString(),
                      label: 'Stars',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _StatTile(
                      value: entry.rewardCount.toString(),
                      label: 'Rewards',
                    ),
                    const SizedBox(width: 8),
                    _StatTile(
                      value: entry.totalScore.toString(),
                      label: 'Score',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'This leaderboard only shows parent-approved, '
                      'anonymized learning progress. Names and contact details '
                      'stay private.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            height: 1.45,
                          ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.value,
    required this.label,
  });

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
          child: Column(
            children: [
              Text(
                value,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppColors.ink,
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 2),
              Text(label),
            ],
          ),
        ),
      ),
    );
  }
}

String _initials(String value) {
  final parts = value.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty || parts.first.isEmpty) return 'LL';
  if (parts.length == 1) {
    return parts.first.length <= 2
        ? parts.first.toUpperCase()
        : parts.first.substring(0, 2).toUpperCase();
  }
  return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
}

Color _avatarColor(String value) {
  final colors = [
    AppColors.mint,
    const Color(0xFFFFE5A3),
    const Color(0xFFDCEBFF),
    const Color(0xFFF7D8CF),
  ];
  return colors[value.hashCode.abs() % colors.length];
}
