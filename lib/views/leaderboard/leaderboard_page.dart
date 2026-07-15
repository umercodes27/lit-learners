import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../models/leaderboard_entry.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/leaderboard_viewmodel.dart';
import 'learner_detail_page.dart';

class LeaderboardPage extends StatefulWidget {
  const LeaderboardPage({super.key});

  @override
  State<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage> {
  String? _loadedParentId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final parent = context.watch<AuthViewModel>().parent;
    if (parent != null && _loadedParentId != parent.id) {
      _loadedParentId = parent.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<LeaderboardViewModel>().loadLeaderboard(
              parentId: parent.id,
            );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final parent = context.watch<AuthViewModel>().parent;
    final leaderboard = context.watch<LeaderboardViewModel>();

    if (parent == null) {
      return const Scaffold(body: Center(child: Text('Parent not signed in.')));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Leaderboard'),
        actions: [
          IconButton(
            tooltip: 'Refresh leaderboard',
            onPressed: leaderboard.isLoading
                ? null
                : () => context
                    .read<LeaderboardViewModel>()
                    .loadLeaderboard(parentId: parent.id),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: leaderboard.isLoading
            ? const Center(child: CircularProgressIndicator())
            : LeaderboardPanel(
                entries: leaderboard.entries,
                selectedStage: leaderboard.selectedStage,
                errorMessage: leaderboard.errorMessage,
                onStageChanged: (stage) {
                  context.read<LeaderboardViewModel>().loadLeaderboard(
                        parentId: parent.id,
                        stage: stage,
                      );
                },
              ),
      ),
    );
  }
}

class LeaderboardPanel extends StatelessWidget {
  const LeaderboardPanel({
    required this.entries,
    required this.selectedStage,
    required this.onStageChanged,
    this.errorMessage,
    super.key,
  });

  final List<LeaderboardEntry> entries;
  final int selectedStage;
  final ValueChanged<int> onStageChanged;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    if (errorMessage != null) {
      return Center(child: Text(errorMessage!));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _StageFilterChip(
                label: 'All stages',
                stage: 0,
                selectedStage: selectedStage,
                onSelected: onStageChanged,
              ),
              for (var stage = 1; stage <= 4; stage++)
                _StageFilterChip(
                  label: 'Stage $stage',
                  stage: stage,
                  selectedStage: selectedStage,
                  onSelected: onStageChanged,
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (entries.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'No opted-in leaderboard entries yet. Turn on leaderboard '
                'sharing for a child profile, complete a level, and refresh.',
              ),
            ),
          )
        else ...[
          _Podium(entries: entries.take(3).toList()),
          const SizedBox(height: 16),
          Text(
            'Rankings',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 8),
          for (var index = 0; index < entries.length; index++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _LeaderboardRow(
                rank: index + 1,
                entry: entries[index],
              ),
            ),
        ],
      ],
    );
  }
}

class _StageFilterChip extends StatelessWidget {
  const _StageFilterChip({
    required this.label,
    required this.stage,
    required this.selectedStage,
    required this.onSelected,
  });

  final String label;
  final int stage;
  final int selectedStage;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selectedStage == stage,
        onSelected: (_) => onSelected(stage),
      ),
    );
  }
}

class _Podium extends StatelessWidget {
  const _Podium({required this.entries});

  final List<LeaderboardEntry> entries;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final slotCount = entries.length > 3 ? 3 : entries.length;
            const gap = 8.0;
            final itemWidth =
                ((constraints.maxWidth - (gap * (slotCount - 1))) / slotCount)
                    .clamp(52.0, 72.0)
                    .toDouble();
            final children = <Widget>[];

            void addItem(Widget child) {
              if (children.isNotEmpty) children.add(const SizedBox(width: gap));
              children.add(child);
            }

            if (entries.length > 1) {
              addItem(
                _PodiumItem(
                  entry: entries[1],
                  rank: 2,
                  height: 52,
                  width: itemWidth,
                  color: AppColors.line,
                ),
              );
            }
            addItem(
              _PodiumItem(
                entry: entries.first,
                rank: 1,
                height: 72,
                width: itemWidth,
                color: AppColors.honey,
                avatarRadius: 26,
              ),
            );
            if (entries.length > 2) {
              addItem(
                _PodiumItem(
                  entry: entries[2],
                  rank: 3,
                  height: 42,
                  width: itemWidth,
                  color: AppColors.coral,
                ),
              );
            }

            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: children,
            );
          },
        ),
      ),
    );
  }
}

class _PodiumItem extends StatelessWidget {
  const _PodiumItem({
    required this.entry,
    required this.rank,
    required this.height,
    required this.width,
    required this.color,
    this.avatarRadius = 22,
  });

  final LeaderboardEntry entry;
  final int rank;
  final double height;
  final double width;
  final Color color;
  final double avatarRadius;

  @override
  Widget build(BuildContext context) {
    final effectiveAvatarRadius = avatarRadius.clamp(16.0, width / 2);

    return SizedBox(
      width: width,
      child: Column(
        children: [
          CircleAvatar(
            radius: effectiveAvatarRadius.toDouble(),
            backgroundColor: _avatarColor(entry.displayName),
            child: Text(
              _initials(entry.displayName),
              style: const TextStyle(
                color: AppColors.ink,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            '#$rank',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          Text(
            '${entry.totalStars} stars',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
          const SizedBox(height: 6),
          Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(8),
              ),
            ),
            child: Center(
              child: Text(
                '$rank',
                style: const TextStyle(
                  color: AppColors.ink,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  const _LeaderboardRow({
    required this.rank,
    required this.entry,
  });

  final int rank;
  final LeaderboardEntry entry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => LearnerDetailPage(entry: entry, rank: rank),
            ),
          );
        },
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              SizedBox(
                width: 24,
                child: Text(
                  '$rank',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                radius: 16,
                backgroundColor: _avatarColor(entry.displayName),
                child: Text(
                  _initials(entry.displayName),
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${entry.displayName} - Stage ${entry.ageStage}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${entry.completedLevels} levels completed',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.star_rounded, color: AppColors.honey, size: 16),
              const SizedBox(width: 2),
              SizedBox(
                width: 26,
                child: Text(
                  entry.totalStars.toString(),
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, size: 18),
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
