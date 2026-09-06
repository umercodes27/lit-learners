import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../widgets/play/play.dart';

/// A filled arc showing how far through something a child is.
///
/// A ring rather than a bar because a parent takes the whole thing in at a
/// glance without reading a number, and several of them sit side by side in a
/// grid where bars would stack into exactly the list of rows this screen
/// exists to replace.
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.value,
    required this.color,
    this.size = 76,
    this.thickness = 9,
    this.child,
  });

  /// 0..1. Clamped, so a rounding error can never draw more than a full turn.
  final double value;
  final Color color;
  final double size;
  final double thickness;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(
          value: value.clamp(0.0, 1.0),
          color: color,
          thickness: thickness,
        ),
        child: Center(child: child),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.value,
    required this.color,
    required this.thickness,
  });

  final double value;
  final Color color;
  final double thickness;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final centre = rect.center;
    final radius = (math.min(size.width, size.height) - thickness) / 2;

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.round
      ..color = color.withValues(alpha: 0.18);

    canvas.drawCircle(centre, radius, track);

    if (value <= 0) return;

    final progress = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.round
      ..color = color;

    canvas.drawArc(
      Rect.fromCircle(center: centre, radius: radius),
      // Starts at the top, so a nearly-empty ring still reads as a beginning
      // rather than as a stray mark on the right.
      -math.pi / 2,
      value * math.pi * 2,
      false,
      progress,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value || old.color != color || old.thickness != thickness;
}

/// The ring plus the two numbers a parent actually wants from it.
class SubjectRing extends StatelessWidget {
  const SubjectRing({
    super.key,
    required this.title,
    required this.completion,
    required this.color,
    required this.caption,
    this.dimmed = false,
  });

  final String title;
  final double completion;
  final Color color;
  final String caption;

  /// For a subject never opened: present, so a parent can see it exists,
  /// but visibly not part of what has been done.
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final shade = dimmed ? color.withValues(alpha: 0.35) : color;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ProgressRing(
          value: completion,
          color: shade,
          child: Text(
            '${(completion * 100).round()}%',
            style: TextStyle(
              fontFamily: 'Fredoka',
              fontWeight: FontWeight.w900,
              fontSize: 17,
              color: dimmed ? PlayColors.ink.withValues(alpha: 0.45) : PlayColors.ink,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontFamily: 'Fredoka',
            fontWeight: FontWeight.w800,
            fontSize: 14,
            color: PlayColors.ink,
          ),
        ),
        Text(
          caption,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11.5,
            color: PlayColors.ink.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }
}
