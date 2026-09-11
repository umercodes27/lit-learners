import 'package:flutter/material.dart';

import '../../core/theme/age2_skin.dart';
import '../../services/audio/app_sounds.dart';
import '../../services/audio/sound_controller.dart';
import '../play/confetti_burst.dart';
import 'activity_feedback_controller.dart';
import 'age2_mascot.dart';
import 'age2_progress.dart';
import 'correct_feedback_animation.dart';
import 'playful_tap_target.dart';
import 'try_again_feedback_animation.dart';

/// The frame every activity is drawn inside.
///
/// One pastel wash, the koala in the corner, stars filling along the top, a
/// replay button you cannot miss, and a lot of empty space around whatever the
/// component puts in the middle. Every age-2 component renders through here, so
/// this is what makes five modules feel like one product — and it is the reason
/// a new activity is playful and consistent without its author doing anything.
///
/// It also hosts the celebration and try-again animations, so a component only
/// has to call [ActivityFeedbackController.celebrate] to get the full reward.
class ActivityStage extends StatelessWidget {
  const ActivityStage({
    required this.title,
    required this.child,
    required this.isRtl,
    super.key,
    this.roundIndex,
    this.roundCount,
    this.onReplayPrompt,
    this.feedback,
  });

  final String title;
  final Widget child;
  final bool isRtl;
  final int? roundIndex;
  final int? roundCount;

  /// Wired whenever the round has spoken instructions, which is nearly always:
  /// the audio carries the task, so hearing it again has to be one big obvious
  /// tap away.
  final VoidCallback? onReplayPrompt;

  final ActivityFeedbackController? feedback;

  @override
  Widget build(BuildContext context) {
    final palette = Age2Skin.of(context);
    final controller = feedback;

    return DecoratedBox(
      decoration: BoxDecoration(gradient: palette.wash),
      child: Stack(
        fit: StackFit.expand,
        children: [
          _buildStage(context, palette),
          if (controller != null) ...[
            CorrectFeedbackAnimation(pulse: controller.correctPulse),
            TryAgainFeedbackAnimation(pulse: controller.tryAgainPulse),
          ],
        ],
      ),
    );
  }

  Widget _buildStage(BuildContext context, Age2Palette palette) {
    final count = roundCount;
    final index = roundIndex;
    final replay = onReplayPrompt;

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: SafeArea(
        child: Padding(
          // Generous, and deliberately more at the bottom: that is where the
          // hand rests, and where a mis-tap is most likely.
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Age2Mascot(size: 54),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      title,
                      style: Age2Text.titleFor(title),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              if (count != null && index != null && count > 0) ...[
                const SizedBox(height: 20),
                Age2ProgressStars(reached: index, total: count),
              ],
              const SizedBox(height: 28),
              Expanded(child: child),
              if (replay != null) ...[
                const SizedBox(height: 24),
                Center(child: _ReplayButton(onTap: replay)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The "say it again" button.
///
/// Large, labelled and always in the same place. A child who cannot read has
/// only the audio to go on, so this is the most important control on the
/// screen after the answers themselves.
class _ReplayButton extends StatelessWidget {
  const _ReplayButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = Age2Skin.of(context);

    return PlayfulTapTarget(
      onTap: onTap,
      semanticLabel: 'Play the instructions again',
      background: Colors.white,
      borderColor: palette.accent,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
      minSize: Age2Surfaces.minTapTarget,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.volume_up_rounded, size: 40, color: palette.accent),
          const SizedBox(width: 12),
          const Text('Listen again', style: Age2Text.label),
        ],
      ),
    );
  }
}

/// Shown when a level parsed but has nothing playable in it.
class ActivityEmptyNotice extends StatelessWidget {
  const ActivityEmptyNotice({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Age2Mascot(size: 96),
            const SizedBox(height: 20),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Age2Text.label,
            ),
          ],
        ),
      ),
    );
  }
}

/// The end-of-level panel, shared so every component finishes the same way.
///
/// Shows stars earned for finishing, never a mark out of ten. [correct] and
/// [total] still arrive from the components, but they are used to fill a star
/// row rather than to print a score: at this age "3 / 5" is a number a parent
/// reads as a grade, and there is nothing to grade.
class ActivityFinishedNotice extends StatefulWidget {
  const ActivityFinishedNotice({
    required this.correct,
    required this.total,
    super.key,
    this.onDone,
    this.headline = 'You did it!',
  });

  final int correct;
  final int total;
  final VoidCallback? onDone;
  final String headline;

  @override
  State<ActivityFinishedNotice> createState() => _ActivityFinishedNoticeState();
}

class _ActivityFinishedNoticeState extends State<ActivityFinishedNotice> {
  @override
  void initState() {
    super.initState();
    // Finishing a level was silent and still: the mascot appeared, the stars
    // filled, and nothing said "well done". Every activity in the app ends on
    // this screen — a story, a tracing sheet, a sorting game — so this is the
    // one place to say it, and it is said the same way everywhere.
    AppSound.play(Sfx.moduleComplete);
  }

  @override
  Widget build(BuildContext context) {
    final palette = Age2Skin.of(context);
    final total = widget.total;
    final headline = widget.headline;
    final onDone = widget.onDone;

    return Stack(
      children: [
        Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Age2Mascot(size: 118),
                const SizedBox(height: 22),
                Text(headline, style: Age2Text.titleFor(headline)),
                const SizedBox(height: 18),
                // Everyone who reaches the end fills every star.
                Age2ProgressStars(
                  reached: total > 0 ? total - 1 : 0,
                  total: total > 0 ? total : 3,
                ),
                const SizedBox(height: 34),
                PlayfulTapTarget(
                  onTap: onDone ?? () => Navigator.of(context).maybePop(),
                  semanticLabel: 'Finish',
                  background: Colors.white,
                  borderColor: palette.accent,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 40, vertical: 18),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_rounded, size: 38, color: palette.accent),
                      const SizedBox(width: 12),
                      const Text('Done', style: Age2Text.cardTitle),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        // Over the top of it, and never in the way of the Done button.
        const Positioned.fill(
          child: IgnorePointer(child: ConfettiBurst()),
        ),
      ],
    );
  }
}
