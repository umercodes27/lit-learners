import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

/// A soft "not quite — try again" cue.
///
/// Deliberately warm rather than corrective: an amber question mark that
/// breathes in, wobbles once and fades, with no red, no cross and no flash.
/// A two-year-old should read it as *have another go*, not *you got it wrong*,
/// so the whole gesture is slower and smaller than the confetti burst it
/// mirrors.
///
/// Plays whenever [pulse] changes and renders nothing when idle. Wrapped in
/// [IgnorePointer] so the child can tap again while it is still fading.
class TryAgainFeedbackAnimation extends StatefulWidget {
  const TryAgainFeedbackAnimation({
    required this.pulse,
    super.key,
    this.duration = const Duration(milliseconds: 1100),
    this.message,
  });

  final ValueListenable<int> pulse;
  final Duration duration;

  /// Optional word under the mark. Left off for the youngest packs, where a
  /// symbol lands and a sentence does not.
  final String? message;

  @override
  State<TryAgainFeedbackAnimation> createState() =>
      _TryAgainFeedbackAnimationState();
}

class _TryAgainFeedbackAnimationState extends State<TryAgainFeedbackAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  @override
  void initState() {
    super.initState();
    widget.pulse.addListener(_onPulse);
  }

  @override
  void didUpdateWidget(TryAgainFeedbackAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pulse != widget.pulse) {
      oldWidget.pulse.removeListener(_onPulse);
      widget.pulse.addListener(_onPulse);
    }
  }

  @override
  void dispose() {
    widget.pulse.removeListener(_onPulse);
    _controller.dispose();
    super.dispose();
  }

  void _onPulse() {
    if (!mounted) return;
    _controller.forward(from: 0);
  }

  /// In over the first quarter, hold, then out over the last third.
  double _opacityAt(double t) {
    if (t < 0.22) return t / 0.22;
    if (t < 0.66) return 1;
    return (1 - (t - 0.66) / 0.34).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          // Leaves the tree once it has played out; an invisible badge would
          // still be found by anything walking the widget tree.
          if (!_controller.isAnimating) return const SizedBox.expand();

          final t = _controller.value;
          final opacity = _opacityAt(t);
          // Settles rather than pops — an overshoot would feel like a buzzer.
          final scale = 0.7 + Curves.easeOutBack.transform((t / 0.35).clamp(0.0, 1.0)) * 0.3;
          final wobble = math.sin(t * math.pi * 4) * (1 - t) * 0.06;

          return Center(
            child: Opacity(
              opacity: opacity,
              child: Transform.rotate(
                angle: wobble,
                child: Transform.scale(scale: scale, child: child),
              ),
            ),
          );
        },
        child: _TryAgainBadge(message: widget.message),
      ),
    );
  }
}

class _TryAgainBadge extends StatelessWidget {
  const _TryAgainBadge({this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 108,
          height: 108,
          decoration: BoxDecoration(
            color: AppColors.lemon,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.honey, width: 5),
            boxShadow: [
              BoxShadow(
                color: AppColors.honey.withValues(alpha: 0.45),
                blurRadius: 24,
                spreadRadius: 2,
              ),
            ],
          ),
          alignment: Alignment.center,
          child: const Text(
            '?',
            style: TextStyle(
              fontSize: 60,
              height: 1,
              fontWeight: FontWeight.w900,
              color: AppColors.honey,
            ),
          ),
        ),
        if (message != null) ...[
          const SizedBox(height: 10),
          DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.lemon,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Text(
                message!,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: AppColors.ink,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
