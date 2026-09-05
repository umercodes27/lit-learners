import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/routing/app_router.dart';
import '../../core/routing/route_names.dart';
import '../../models/child_profile.dart';
import '../../models/learning_module.dart';
import '../../viewmodels/active_child_session.dart';
import '../../viewmodels/learning_viewmodel.dart';
import '../../widgets/child_action_bar.dart';
import '../../widgets/child_avatar.dart';
import '../../widgets/module_card.dart';
import '../../widgets/parent_area_button.dart';
import '../../services/audio/app_sounds.dart';
import '../../services/audio/sound_controller.dart';
import '../../widgets/play/play.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<ActiveChildSession>();
    final learning = context.watch<LearningViewModel>();
    final child = session.activeChild;

    if (child == null) return const _NoProfileChosen();

    return Scaffold(
      // The screen is a colour, not a white page. See PlayGround.
      body: PlayGround(
        color: PlayColors.blueberry,
        safeArea: false,
        child: SafeArea(
          bottom: false,
          // A Column rather than a ListView: the hero and the heading stay put
          // while only the modules move, so the child never loses sight of whose
          // dashboard this is or what the grid below is for.
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: _ChildHero(
                  child: child,
                  starsEarned: learning.totalStarsEarned,
                  levelsCompleted: learning.completedLevelCount,
                ),
              ),
              const SizedBox(height: 18),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _ModuleSectionHeading(count: learning.modules.length),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: learning.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : learning.modules.isEmpty
                        ? const SingleChildScrollView(
                            padding: EdgeInsets.fromLTRB(16, 4, 16, 24),
                            child: _NoModulesYet(),
                          )
                        : _ModuleGrid(
                            modules: learning.modules,
                            onOpen: (module) => _openModule(context, module),
                          ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _ChildActionBar(
        onSwitchChild: () {
          session.clear();
          Navigator.of(context).pushNamedAndRemoveUntil(
            RouteNames.childSelection,
            (route) => false,
          );
        },
        onOpenParentArea: () => _openParentArea(context),
      ),
    );
  }

  /// The way out of the child's part of the app, behind the same check that
  /// already guards profile edits and reports.
  void _openParentArea(BuildContext context) {
    Navigator.of(context).pushNamed(
      RouteNames.parentalLock,
      arguments: const ParentalLockArgs(
        successRoute: RouteNames.parentDashboard,
      ),
    );
  }

  void _openModule(BuildContext context, LearningModule module) {
    final route = module.category == ModuleCategory.video
        ? RouteNames.videoLearning
        : RouteNames.moduleLevels;
    Navigator.of(context).pushNamed(route, arguments: module.id);
  }
}

class _ChildHero extends StatelessWidget {
  const _ChildHero({
    required this.child,
    required this.starsEarned,
    required this.levelsCompleted,
  });

  final ChildProfile child;
  final int starsEarned;
  final int levelsCompleted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: PlayColors.card,
        borderRadius: BorderRadius.circular(PlayMotion.radiusLarge),
        border: Border.all(color: Colors.white, width: 4),
        boxShadow: [
          BoxShadow(
            color: PlayColors.ink.withValues(alpha: 0.20),
            offset: const Offset(0, 7),
            blurRadius: 0,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              ChildAvatar(
                name: child.name,
                avatarValue: child.avatarAsset,
                radius: 34,
                borderColor: PlayColors.sunshine,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hi, ${child.name}!',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Fredoka',
                        color: PlayColors.ink,
                        fontSize: 30,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'What shall we play today?',
                      style: TextStyle(
                        color: PlayColors.grape,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _HeroStat(
                  icon: Icons.star_rounded,
                  iconColor: PlayColors.tangerine,
                  value: '$starsEarned',
                  label: starsEarned == 1 ? 'star' : 'stars',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _HeroStat(
                  icon: Icons.check_circle_rounded,
                  iconColor: PlayColors.grass,
                  value: '$levelsCompleted',
                  label: levelsCompleted == 1 ? 'level done' : 'levels done',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: iconColor.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: iconColor, width: 2.5),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 28),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontFamily: 'Fredoka',
                    color: PlayColors.ink,
                    fontSize: 24,
                    height: 1.1,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: PlayColors.ink.withValues(alpha: 0.62),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
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

/// The two things a grown-up needs from a child screen, spelled out. They sit
/// in the action bar rather than as icons in the hero: an unlabelled glyph
/// beside a child's name did not read as "leave this child's dashboard".
class _ChildActionBar extends StatelessWidget {
  const _ChildActionBar({
    required this.onSwitchChild,
    required this.onOpenParentArea,
  });

  final VoidCallback onSwitchChild;
  final VoidCallback onOpenParentArea;

  @override
  Widget build(BuildContext context) {
    return ChildActionBar(
      actions: [
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: PlayColors.grape,
            side: const BorderSide(color: PlayColors.grape, width: 2.5),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            minimumSize: const Size(0, PlayMotion.minTouchTarget),
            textStyle: const TextStyle(
              fontFamily: 'Fredoka',
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          onPressed: onSwitchChild,
          icon: const Icon(Icons.switch_account_rounded, size: 20),
          label: const Text(
            'Switch child',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        ParentAreaButton(onPressed: onOpenParentArea),
      ],
    );
  }
}

class _ModuleGrid extends StatefulWidget {
  const _ModuleGrid({required this.modules, required this.onOpen});

  final List<LearningModule> modules;
  final ValueChanged<LearningModule> onOpen;

  @override
  State<_ModuleGrid> createState() => _ModuleGridState();
}

class _ModuleGridState extends State<_ModuleGrid> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Reached directly from the celebration screen's Home button, which is
    // playing a different track by then.
    AppSound.instance.playMusic(MusicTrack.home);
  }

  /// Cards the grid has already introduced. A tile scrolled far enough out of
  /// view is disposed and rebuilt on the way back, and replaying its arrival
  /// then would read as a glitch rather than as a flourish.
  final _alreadyArrived = <int>{};

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columnCount = constraints.maxWidth >= 720
            ? 4
            : constraints.maxWidth >= 500
                ? 3
                : 2;
        const spacing = 14.0;
        const padding = EdgeInsets.fromLTRB(16, 4, 16, 24);
        final aspectRatio = columnCount == 2 ? 0.84 : 0.9;
        final tileWidth = (constraints.maxWidth -
                padding.horizontal -
                spacing * (columnCount - 1)) /
            columnCount;
        final tileHeight = tileWidth / aspectRatio;

        return GridView.builder(
          controller: _scrollController,
          padding: padding,
          itemCount: widget.modules.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columnCount,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
            childAspectRatio: aspectRatio,
          ),
          itemBuilder: (context, index) {
            final module = widget.modules[index];
            return _AnimatedModuleTile(
              scrollController: _scrollController,
              // Everything the tile needs to know where it sits in the scroll
              // without measuring itself: the grid geometry is fixed here.
              rowTop:
                  padding.top + (index ~/ columnCount) * (tileHeight + spacing),
              tileHeight: tileHeight,
              viewportHeight: constraints.maxHeight,
              index: index,
              hasArrived: _alreadyArrived.contains(index),
              onArrived: () => _alreadyArrived.add(index),
              child: ModuleCard(
                module: module,
                onTap: () => widget.onOpen(module),
              ),
            );
          },
        );
      },
    );
  }
}

/// Gives each card two movements: it drops into place when the grid first
/// appears, staggered so the modules arrive one after another, and then it
/// lifts and fades as it crosses the edges of the scroll while the child
/// swipes.
class _AnimatedModuleTile extends StatefulWidget {
  const _AnimatedModuleTile({
    required this.scrollController,
    required this.rowTop,
    required this.tileHeight,
    required this.viewportHeight,
    required this.index,
    required this.hasArrived,
    required this.onArrived,
    required this.child,
  });

  final ScrollController scrollController;
  final double rowTop;
  final double tileHeight;
  final double viewportHeight;
  final int index;
  final bool hasArrived;
  final VoidCallback onArrived;
  final Widget child;

  @override
  State<_AnimatedModuleTile> createState() => _AnimatedModuleTileState();
}

class _AnimatedModuleTileState extends State<_AnimatedModuleTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );
  Timer? _stagger;

  @override
  void initState() {
    super.initState();
    if (widget.hasArrived) {
      _entrance.value = 1;
      return;
    }
    // Capped so a long list never leaves the last card waiting seconds.
    final delay = Duration(milliseconds: 70 * (widget.index % 6));
    _stagger = Timer(delay, () {
      if (!mounted) return;
      widget.onArrived();
      _entrance.forward();
    });
  }

  @override
  void dispose() {
    _stagger?.cancel();
    _entrance.dispose();
    super.dispose();
  }

  /// 1 while the card sits well inside the viewport, easing to 0 as it passes
  /// either edge.
  double _scrollProgress() {
    if (!widget.scrollController.hasClients) return 1;
    final viewTop = widget.scrollController.offset;
    final viewBottom = viewTop + widget.viewportHeight;
    final tileBottom = widget.rowTop + widget.tileHeight;
    // A card is fully settled once this much of it has cleared the edge.
    final window = widget.tileHeight * 0.75;
    if (window <= 0) return 1;

    final entering = ((viewBottom - widget.rowTop) / window).clamp(0.0, 1.0);
    final leaving = ((tileBottom - viewTop) / window).clamp(0.0, 1.0);
    return entering < leaving ? entering : leaving;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_entrance, widget.scrollController]),
      child: widget.child,
      builder: (context, child) {
        final entrance = Curves.easeOutCubic.transform(_entrance.value);
        final progress = Curves.easeOut.transform(_scrollProgress());
        final scale = 0.9 + 0.1 * progress;

        return Opacity(
          opacity: (entrance * (0.45 + 0.55 * progress)).clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, (1 - entrance) * 26),
            child: Transform.scale(scale: scale, child: child),
          ),
        );
      },
    );
  }
}

class _ModuleSectionHeading extends StatelessWidget {
  const _ModuleSectionHeading({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.honey, AppColors.rose],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.explore_rounded, color: Colors.white),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pick an adventure',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text(
                count == 1 ? '1 module ready' : '$count modules ready',
                style: TextStyle(
                  color: AppColors.ink.withValues(alpha: 0.6),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const Icon(Icons.auto_awesome, color: AppColors.rose),
      ],
    );
  }
}

class _NoModulesYet extends StatelessWidget {
  const _NoModulesYet();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.lavender,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.lilac.withValues(alpha: 0.6)),
      ),
      child: const Column(
        children: [
          Icon(Icons.explore_off_rounded, size: 36, color: AppColors.violet),
          SizedBox(height: 10),
          Text(
            'No modules for this age yet',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          SizedBox(height: 4),
          Text(
            'Check the age on this profile, or ask an adult to add content.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _NoProfileChosen extends StatelessWidget {
  const _NoProfileChosen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircleAvatar(
                radius: 34,
                backgroundColor: AppColors.mint,
                child: Icon(
                  Icons.child_care,
                  size: 36,
                  color: AppColors.forest,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Choose a learner profile first',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil(
                  RouteNames.childSelection,
                  (route) => false,
                ),
                icon: const Icon(Icons.switch_account),
                label: const Text('Choose profile'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
