import 'package:flutter/material.dart';

import '../../core/theme/age2_skin.dart';
import '../../models/activity_pack.dart';
import '../../widgets/activities/activity_audio.dart';
import '../../widgets/activities/activity_player.dart';

/// Route arguments for one playable level.
class ActivityLevelArgs {
  const ActivityLevelArgs({
    required this.level,
    this.correctSound,
    this.wrongSound,
  });

  final ActivityLevel level;
  final String? correctSound;
  final String? wrongSound;
}

/// Hosts a single activity and owns its audio.
///
/// The players live here rather than inside each component so that leaving the
/// screen reliably stops a half-played narration — a component that rebuilds
/// mid-activity would otherwise strand a player and talk over the next one.
///
/// This is also where the module's colours enter: the whole subtree is wrapped
/// in an [Age2Skin], so the activity, its buttons and its stars all take the
/// module's accent without any component naming a colour.
class ActivityLevelPage extends StatefulWidget {
  const ActivityLevelPage({required this.args, super.key});

  final ActivityLevelArgs args;

  @override
  State<ActivityLevelPage> createState() => _ActivityLevelPageState();
}

class _ActivityLevelPageState extends State<ActivityLevelPage> {
  late final ActivityAudio _audio = ActivityAudio(
    correctSound: widget.args.correctSound,
    wrongSound: widget.args.wrongSound,
  );

  @override
  void dispose() {
    _audio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final level = widget.args.level;
    final palette = Age2Palette.forModule(level.moduleKey);

    return Age2Skin(
      palette: palette,
      child: Scaffold(
        // No app bar: the stage carries its own title and mascot, and a bar
        // would take a fifth of a small screen away from the activity.
        backgroundColor: palette.background,
        // StackFit.expand is load-bearing: without it the stack sizes itself
        // to its largest non-positioned child — the little back button — and
        // the whole activity gets squeezed into a 70-pixel strip that plays
        // its audio from off-screen.
        body: Stack(
          fit: StackFit.expand,
          children: [
            ActivityPlayer(
              data: level.data,
              audio: _audio,
              // `true` is what marks the level finished on the map behind
              // this screen. Backing out with the button below pops without a
              // result, which is the difference between leaving and finishing.
              onCompleted: () => Navigator.of(context).maybePop(true),
            ),
            SafeArea(
              child: Align(
                alignment: AlignmentDirectional.topStart,
                child: Padding(
                  padding: const EdgeInsets.only(left: 4, top: 4),
                  child: _BackButton(accent: palette.accent),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A soft round way out, sized for a small hand.
class _BackButton extends StatelessWidget {
  const _BackButton({required this.accent});

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
          width: 56,
          height: 56,
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.85),
            shape: BoxShape.circle,
            boxShadow: Age2Surfaces.lift(tint: accent),
          ),
          child: Icon(Icons.arrow_back_rounded, color: accent, size: 30),
        ),
      ),
    );
  }
}
