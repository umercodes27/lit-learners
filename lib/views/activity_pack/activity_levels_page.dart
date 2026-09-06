import 'package:flutter/material.dart';

import '../../core/routing/gentle_page_route.dart';
import '../../core/theme/age2_skin.dart';
import '../../models/activity_data.dart';
import '../../models/activity_pack.dart';
import '../../widgets/activities/age2_mascot.dart';
import '../../widgets/activities/playful_tap_target.dart';
import 'activity_level_page.dart';
import 'activity_modules_page.dart';

/// The levels inside one module, in the order the pack lists them.
///
/// Every level is open. The age-2 pack is a tap-and-listen curriculum with no
/// prerequisite chain, and gating it would only stop a two-year-old reaching
/// the one activity they wanted.
class ActivityLevelsPage extends StatelessWidget {
  const ActivityLevelsPage({required this.args, super.key});

  final ActivityLevelsArgs args;

  @override
  Widget build(BuildContext context) {
    final module = args.module;
    final palette = Age2Palette.forModule(module.key);

    return Age2Skin(
      palette: palette,
      child: Scaffold(
        backgroundColor: palette.background,
        body: DecoratedBox(
          decoration: BoxDecoration(gradient: palette.wash),
          child: SafeArea(
            child: module.levels.isEmpty
                ? const Center(
                    child: Text('Nothing here yet', style: Age2Text.cardTitle),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
                    children: [
                      Row(
                        children: [
                          _RoundBackButton(accent: palette.accent),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(module.title,
                                style: Age2Text.titleFor(module.title)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      const Age2MascotBanner(
                        message: 'Pick something to play',
                      ),
                      const SizedBox(height: 26),
                      for (final level in module.levels)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 20),
                          child: _LevelCard(
                            level: level,
                            onTap: () => Navigator.of(context).push(
                              GentlePageRoute<void>(
                                builder: (_) => ActivityLevelPage(
                                  args: ActivityLevelArgs(
                                    level: level,
                                    correctSound: level.data.correctSound ??
                                        args.pack.correctSound,
                                    wrongSound: level.data.wrongSound ??
                                        args.pack.wrongSound,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _RoundBackButton extends StatelessWidget {
  const _RoundBackButton({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Go back',
      child: GestureDetector(
        onTap: () => Navigator.of(context).maybePop(),
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.9),
            shape: BoxShape.circle,
            boxShadow: Age2Surfaces.lift(tint: accent),
          ),
          child: Icon(Icons.arrow_back_rounded, color: accent, size: 28),
        ),
      ),
    );
  }
}

class _LevelCard extends StatelessWidget {
  const _LevelCard({required this.level, required this.onTap});

  final ActivityLevel level;
  final VoidCallback onTap;

  /// A picture for the kind of play, not a word. The label underneath is for
  /// the adult; the icon is what the child navigates by.
  static IconData _iconFor(ActivityComponent component) {
    return switch (component) {
      ActivityComponent.twoChoiceTap => Icons.touch_app_rounded,
      ActivityComponent.identifyAndTap => Icons.search_rounded,
      ActivityComponent.tapToCount => Icons.filter_5_rounded,
      ActivityComponent.shadowMatch => Icons.contrast_rounded,
      ActivityComponent.puzzle => Icons.extension_rounded,
      ActivityComponent.oddOneOut => Icons.psychology_alt_rounded,
      ActivityComponent.storyInteractive => Icons.auto_stories_rounded,
      ActivityComponent.listenAndSee => Icons.hearing_rounded,
      ActivityComponent.tracing => Icons.gesture_rounded,
      ActivityComponent.dragAndMatch => Icons.compare_arrows_rounded,
      ActivityComponent.sortIntoZones => Icons.inbox_rounded,
      ActivityComponent.patternComplete => Icons.auto_awesome_motion_rounded,
      ActivityComponent.wordBuilder => Icons.abc_rounded,
      ActivityComponent.visualMath => Icons.calculate_rounded,
      ActivityComponent.maze => Icons.route_rounded,
      ActivityComponent.memoryMatch => Icons.style_rounded,
      ActivityComponent.unknown => Icons.hourglass_empty_rounded,
    };
  }

  @override
  Widget build(BuildContext context) {
    final palette = Age2Skin.of(context);
    final playable = !level.data.isEmpty;

    return PlayfulTapTarget(
      onTap: onTap,
      semanticLabel: level.title,
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: palette.background,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Icon(
              _iconFor(level.data.component),
              size: 38,
              color: palette.accent,
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(level.title, style: Age2Text.cardTitleFor(level.title)),
                const SizedBox(height: 4),
                Text(level.displayLabel, style: Age2Text.label),
              ],
            ),
          ),
          Icon(
            playable ? Icons.play_circle_fill_rounded : Icons.hourglass_empty_rounded,
            color: palette.accent,
            size: 44,
          ),
        ],
      ),
    );
  }
}
