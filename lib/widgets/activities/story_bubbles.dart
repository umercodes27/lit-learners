import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Soap bubbles drifting up behind a story.
///
/// A narrated story is the one activity where the child is not doing anything
/// for twenty seconds, and a completely still screen is where a two-year-old
/// looks away. This gives the page a slow, ignorable pulse — movement that
/// rewards watching without competing with the picture or the voice.
///
/// Bubbles rather than confetti or sparkles: they suit the hand-washing story
/// literally, and read as calm anywhere else. Everything is painted in code,
/// so there is no asset to ship and the colours follow the module.
///
/// Decorative only — [IgnorePointer] means it can never take a tap, and it
/// stops entirely when the platform asks for reduced motion.
class StoryBubbles extends StatefulWidget {
  const StoryBubbles({
    required this.color,
    super.key,
    this.count = 16,
    this.cycle = const Duration(seconds: 11),
  });

  final Color color;
  final int count;

  /// How long one bubble takes to cross the screen. Slow on purpose: fast
  /// bubbles read as an effect, slow ones read as atmosphere.
  final Duration cycle;

  @override
  State<StoryBubbles> createState() => _StoryBubblesState();
}

class _StoryBubblesState extends State<StoryBubbles>
    with SingleTickerProviderStateMixin {
  late final AnimationController _drift = AnimationController(
    vsync: this,
    duration: widget.cycle,
  );

  late final List<_Bubble> _bubbles = _build();

  List<_Bubble> _build() {
    // Fixed seed: the drift should look the same each time a child opens the
    // story, and a stable layout is testable.
    final random = math.Random(7);
    return List.generate(widget.count, (index) {
      return _Bubble(
        x: random.nextDouble(),
        radius: 5 + random.nextDouble() * 16,
        // Spread the starting heights so the screen is never briefly empty.
        phase: random.nextDouble(),
        sway: 0.02 + random.nextDouble() * 0.06,
        swaySpeed: 1 + random.nextDouble() * 2,
        opacity: 0.18 + random.nextDouble() * 0.3,
      );
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduceMotion) {
      if (_drift.isAnimating) _drift.stop();
    } else if (!_drift.isAnimating) {
      _drift.repeat();
    }
  }

  @override
  void dispose() {
    _drift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _drift,
        builder: (context, child) => CustomPaint(
          size: Size.infinite,
          painter: _BubblePainter(
            bubbles: _bubbles,
            progress: _drift.value,
            color: widget.color,
          ),
        ),
      ),
    );
  }
}

@immutable
class _Bubble {
  const _Bubble({
    required this.x,
    required this.radius,
    required this.phase,
    required this.sway,
    required this.swaySpeed,
    required this.opacity,
  });

  /// Horizontal home, as a fraction of the width.
  final double x;
  final double radius;
  final double phase;
  final double sway;
  final double swaySpeed;
  final double opacity;
}

class _BubblePainter extends CustomPainter {
  const _BubblePainter({
    required this.bubbles,
    required this.progress,
    required this.color,
  });

  final List<_Bubble> bubbles;
  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()..style = PaintingStyle.fill;
    final rim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (final bubble in bubbles) {
      // Each bubble runs its own loop, offset by its phase, so they do not
      // pulse in unison.
      final t = (progress + bubble.phase) % 1.0;

      // Rises from just below the bottom to just above the top.
      final y = size.height * (1.1 - t * 1.2);
      final x = size.width *
          (bubble.x + math.sin(t * math.pi * 2 * bubble.swaySpeed) * bubble.sway);

      // Fades in on the way up and out at the top, so nothing pops.
      final fade = t < 0.15
          ? t / 0.15
          : t > 0.8
              ? (1 - t) / 0.2
              : 1.0;
      final alpha = (bubble.opacity * fade).clamp(0.0, 1.0);
      if (alpha <= 0.01) continue;

      final centre = Offset(x, y);
      fill.color = color.withValues(alpha: alpha * 0.55);
      rim.color = color.withValues(alpha: alpha);

      canvas.drawCircle(centre, bubble.radius, fill);
      canvas.drawCircle(centre, bubble.radius, rim);

      // The little highlight that makes a circle read as a bubble.
      canvas.drawCircle(
        centre.translate(-bubble.radius * 0.32, -bubble.radius * 0.32),
        bubble.radius * 0.2,
        Paint()..color = Colors.white.withValues(alpha: alpha * 0.9),
      );
    }
  }

  @override
  bool shouldRepaint(_BubblePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
