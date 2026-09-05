import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/leaderboard_entry.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/leaderboard_viewmodel.dart';
import '../../widgets/play/play.dart';
import 'learner_detail_page.dart';

/// The leaderboard, as its own screen and as a tab inside the parent
/// dashboard.
///
/// The panel paints no background of its own, so it sits on whichever ground
/// hosts it — tangerine here, grape inside the dashboard.
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
      body: PlayGround(
        color: PlayColors.tangerine,
        safeArea: false,
        child: SafeArea(
          child: Column(
            children: [
              PlayHeader(
                title: 'Leaderboard',
                onBack: Navigator.of(context).canPop()
                    ? () => Navigator.of(context).maybePop()
                    : null,
                trailing: PlayIconButton(
                  icon: Icons.refresh_rounded,
                  semanticLabel: 'Refresh leaderboard',
                  onPressed: leaderboard.isLoading
                      ? null
                      : () => context
                          .read<LeaderboardViewModel>()
                          .loadLeaderboard(parentId: parent.id),
                  color: PlayColors.card,
                  iconColor: PlayColors.tangerine,
                  size: 54,
                ),
              ),
              Expanded(
                child: leaderboard.isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      )
                    : LeaderboardPanel(
                        entries: leaderboard.entries,
                        selectedStage: leaderboard.selectedStage,
                        errorMessage: leaderboard.errorMessage,
                        onStageChanged: (stage) {
                          context
                              .read<LeaderboardViewModel>()
                              .loadLeaderboard(
                                parentId: parent.id,
                                stage: stage,
                              );
                        },
                      ),
              ),
            ],
          ),
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
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: PlayBanner(message: errorMessage!),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        SizedBox(
          height: 56,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _StageChip(
                label: 'All stages',
                stage: 0,
                selectedStage: selectedStage,
                onSelected: onStageChanged,
              ),
              for (var stage = 1; stage <= 4; stage++)
                _StageChip(
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
          const _NoEntriesCard()
        else ...[
          _Podium(entries: entries.take(3).toList()),
          const SizedBox(height: 18),
          const PlaySectionLabel('All rankings'),
          for (var index = 0; index < entries.length; index++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: PopIn(
                index: index,
                child: _LeaderboardRow(rank: index + 1, entry: entries[index]),
              ),
            ),
        ],
      ],
    );
  }
}

class _StageChip extends StatelessWidget {
  const _StageChip({
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
    final selected = selectedStage == stage;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Squishy(
        semanticLabel: label,
        onTap: () => onSelected(stage),
        scale: 0.93,
        child: AnimatedContainer(
          duration: PlayMotion.pressDown,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? PlayColors.sunshine : PlayColors.card,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: PlayColors.ink.withValues(alpha: 0.16),
                offset: const Offset(0, 4),
                blurRadius: 0,
              ),
            ],
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Fredoka',
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: selected
                  ? PlayColors.ink
                  : PlayColors.ink.withValues(alpha: 0.55),
            ),
          ),
        ),
      ),
    );
  }
}

class _NoEntriesCard extends StatelessWidget {
  const _NoEntriesCard();

  @override
  Widget build(BuildContext context) {
    return PlayPanel(
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: const BoxDecoration(
              color: PlayColors.sunshine,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.emoji_events_rounded,
              color: PlayColors.ink,
              size: 42,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'No opted-in leaderboard entries yet. Turn on leaderboard '
            'sharing for a child profile, complete a level, and refresh.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              height: 1.35,
              fontWeight: FontWeight.w600,
              color: PlayColors.ink.withValues(alpha: 0.66),
            ),
          ),
        ],
      ),
    );
  }
}

/// The top three, on blocks.
///
/// Solid colour rather than the purple gradient this used to be, and the
/// blocks are the same chunky slabs the rest of the app is built from.
class _Podium extends StatelessWidget {
  const _Podium({required this.entries});

  final List<LeaderboardEntry> entries;

  @override
  Widget build(BuildContext context) {
    return PlayPanel(
      padding: const EdgeInsets.fromLTRB(12, 18, 12, 0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final slotCount = entries.length > 3 ? 3 : entries.length;
          const gap = 8.0;
          // Long aliases are the reason for the clamp: three of them on a
          // 320px phone is what this screen's one test guards against.
          final itemWidth =
              ((constraints.maxWidth - (gap * (slotCount - 1))) / slotCount)
                  .clamp(52.0, 88.0)
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
                height: 62,
                width: itemWidth,
                color: PlayColors.sky,
                avatarRadius: 24,
              ),
            );
          }
          addItem(
            _PodiumItem(
              entry: entries.first,
              rank: 1,
              height: 88,
              width: itemWidth,
              color: PlayColors.sunshine,
              avatarRadius: 30,
            ),
          );
          if (entries.length > 2) {
            addItem(
              _PodiumItem(
                entry: entries[2],
                rank: 3,
                height: 46,
                width: itemWidth,
                color: PlayColors.strawberry,
                avatarRadius: 24,
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
    this.avatarRadius = 24,
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
          if (rank == 1)
            const Icon(
              Icons.workspace_premium_rounded,
              color: PlayColors.sunshine,
              size: 28,
            ),
          Container(
            width: effectiveAvatarRadius * 2,
            height: effectiveAvatarRadius * 2,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
            ),
            child: FittedBox(
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Text(
                  _initials(entry.displayName),
                  style: TextStyle(
                    fontFamily: 'Fredoka',
                    fontWeight: FontWeight.w700,
                    color: PlayColors.onGround(color),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${entry.totalStars} ★',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: PlayColors.ink.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(18),
              ),
              border: Border.all(color: Colors.white, width: 3),
            ),
            child: Center(
              child: Text(
                '$rank',
                style: TextStyle(
                  fontFamily: 'Fredoka',
                  fontSize: 30,
                  height: 1,
                  fontWeight: FontWeight.w700,
                  color: PlayColors.onGround(color),
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
  const _LeaderboardRow({required this.rank, required this.entry});

  final int rank;
  final LeaderboardEntry entry;

  @override
  Widget build(BuildContext context) {
    final tint = PlayColors.byIndex(entry.displayName.hashCode);

    return Squishy(
      semanticLabel: 'Open ${entry.displayName}',
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => LearnerDetailPage(entry: entry, rank: rank),
          ),
        );
      },
      scale: 0.97,
      child: PlayPanel(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        radius: 26,
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: rank <= 3 ? PlayColors.sunshine : PlayColors.cream,
                shape: BoxShape.circle,
              ),
              child: Text(
                '$rank',
                style: const TextStyle(
                  fontFamily: 'Fredoka',
                  fontSize: 17,
                  height: 1,
                  fontWeight: FontWeight.w700,
                  color: PlayColors.ink,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: tint,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
              ),
              child: Text(
                _initials(entry.displayName),
                style: TextStyle(
                  fontFamily: 'Fredoka',
                  fontSize: 14,
                  height: 1,
                  fontWeight: FontWeight.w700,
                  color: PlayColors.onGround(tint),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${entry.displayName} · Stage ${entry.ageStage}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Fredoka',
                      fontSize: 17,
                      height: 1.15,
                      fontWeight: FontWeight.w600,
                      color: PlayColors.ink,
                    ),
                  ),
                  Text(
                    '${entry.completedLevels} levels completed',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: PlayColors.ink.withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            const Icon(
              Icons.star_rounded,
              color: PlayColors.sunshine,
              size: 22,
            ),
            const SizedBox(width: 2),
            SizedBox(
              width: 30,
              child: Text(
                entry.totalStars.toString(),
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontFamily: 'Fredoka',
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: PlayColors.ink,
                ),
              ),
            ),
          ],
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
