import 'package:flutter/material.dart';

import '../../core/theme/age2_skin.dart';

/// How far through a level the child is, told as stars filling up.
///
/// Deliberately not a score. A star lights when a round is *reached*, not when
/// it is answered correctly, so the row only ever grows and nothing on screen
/// can record a mistake. A two-year-old who taps the wrong picture four times
/// still watches their stars fill, which is the behaviour we want to reward —
/// staying with it.
class Age2ProgressStars extends StatelessWidget {
  const Age2ProgressStars({
    required this.reached,
    required this.total,
    super.key,
  });

  /// Zero-based index of the round being played.
  final int reached;
  final int total;

  /// Past this many, a row of stars stops being countable at a glance and a
  /// bar reads better.
  static const _maxStars = 6;

  @override
  Widget build(BuildContext context) {
    if (total <= 0) return const SizedBox.shrink();
    final palette = Age2Skin.of(context);

    if (total > _maxStars) {
      return _ProgressBar(
        fraction: ((reached + 1) / total).clamp(0.0, 1.0),
        accent: palette.accent,
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < total; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: _Star(filled: i <= reached, accent: palette.accent),
          ),
      ],
    );
  }
}

class _Star extends StatelessWidget {
  const _Star({required this.filled, required this.accent});

  final bool filled;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: filled ? 1 : 0.78,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutBack,
      child: Icon(
        filled ? Icons.star_rounded : Icons.star_outline_rounded,
        size: 34,
        color: filled ? accent : accent.withValues(alpha: 0.3),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.fraction, required this.accent});

  final double fraction;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        children: [
          Container(height: 18, color: accent.withValues(alpha: 0.2)),
          AnimatedFractionallySizedBox(
            duration: const Duration(milliseconds: 450),
            curve: Curves.easeOut,
            widthFactor: fraction,
            child: Container(height: 18, color: accent),
          ),
        ],
      ),
    );
  }
}
