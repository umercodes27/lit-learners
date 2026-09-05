import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/constants/app_colors.dart';
import 'play_motion.dart';

/// The stars a child earns, arriving one at a time.
///
/// The app's existing `StarRating` draws three 20px icons with the empty ones
/// in `Colors.black38` — the size of a form checkbox, in grey, as the reward
/// for finishing a lesson. This is the same information given the weight it
/// actually has: each earned star flies in, overshoots, and settles, with a
/// beat between them so three stars feel like three separate wins.
///
/// [StarRating] is kept for the parent-facing screens, where a compact inline
/// summary is the right call.
class PoppingStars extends StatelessWidget {
  const PoppingStars({
    super.key,
    required this.count,
    this.total = 3,
    this.size = 64,
    this.animate = true,
  });

  /// How many were earned.
  final int count;

  final int total;
  final double size;

  /// Off for a static display, on for the moment of winning them.
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final still = !animate || PlayMotion.reduced(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: List.generate(total, (index) {
        final earned = index < count;
        final star = Padding(
          padding: EdgeInsets.symmetric(horizontal: size * 0.06),
          child: _Star(earned: earned, size: size),
        );

        if (still || !earned) return star;

        // Each star waits its turn. The gap is what turns one chord into
        // three distinct moments of "I got another one".
        final delay = Duration(milliseconds: 260 * index);
        return star
            .animate()
            .scaleXY(
              begin: 0,
              end: 1,
              delay: delay,
              duration: PlayMotion.pop,
              curve: PlayMotion.springCurve,
            )
            .rotate(begin: -0.12, end: 0, delay: delay, duration: 520.ms)
            .shimmer(
              delay: delay + 320.ms,
              duration: 700.ms,
              color: Colors.white,
            );
      }),
    );
  }
}

class _Star extends StatelessWidget {
  const _Star({required this.earned, required this.size});

  final bool earned;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (!earned) {
      // An unearned star is a quiet outline, not a grey blot. It should read
      // as "there is one more to get", never as a mark against the child.
      return Icon(
        Icons.star_rounded,
        size: size,
        color: Colors.white.withValues(alpha: 0.32),
      );
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        Icon(
          Icons.star_rounded,
          size: size * 1.1,
          color: AppColors.honey.withValues(alpha: 0.45),
        ),
        Icon(Icons.star_rounded, size: size, color: AppColors.honey),
        Icon(
          Icons.star_rounded,
          size: size * 0.52,
          color: Colors.white.withValues(alpha: 0.5),
        ),
      ],
    );
  }
}
