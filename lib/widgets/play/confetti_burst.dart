import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import 'play_motion.dart';

/// A one-shot burst of paper confetti.
///
/// Hand-painted rather than pulled from a package: it is about sixty lines,
/// it adds no dependency, and it lets the pieces use the app's own palette so
/// a celebration looks like it belongs to Little Learners.
///
/// Plays once when mounted. To fire it again, give it a new [key].
class ConfettiBurst extends StatefulWidget {
  const ConfettiBurst({
    super.key,
    this.pieces = 34,
    this.duration = const Duration(milliseconds: 1800),
    this.colors,
  });

  final int pieces;
  final Duration duration;
  final List<Color>? colors;

  @override
  State<ConfettiBurst> createState() => _ConfettiBurstState();
}

class _ConfettiBurstState extends State<ConfettiBurst>
    with SingleTickerProviderStateMixin {
  static const _palette = [
    AppColors.honey,
    AppColors.coral,
    AppColors.leaf,
    AppColors.sky,
    AppColors.plum,
    AppColors.rose,
    AppColors.aqua,
    AppColors.lime,
  ];

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  late final List<_Piece> _confetti;

  @override
  void initState() {
    super.initState();
    // Seeded so a rebuild does not reshuffle mid-flight.
    final random = math.Random(widget.pieces * 7919);
    final palette = widget.colors ?? _palette;
    _confetti = List.generate(widget.pieces, (i) {
      return _Piece(
        color: palette[i % palette.length],
        angle: random.nextDouble() * math.pi * 2,
        speed: 0.55 + random.nextDouble() * 0.75,
        spin: (random.nextDouble() - 0.5) * 10,
        size: 7 + random.nextDouble() * 9,
        drift: (random.nextDouble() - 0.5) * 0.5,
      );
    });
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (PlayMotion.reduced(context)) return const SizedBox.shrink();

    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return CustomPaint(
              painter: _ConfettiPainter(_confetti, _controller.value),
              size: Size.infinite,
            );
          },
        ),
      ),
    );
  }
}

class _Piece {
  const _Piece({
    required this.color,
    required this.angle,
    required this.speed,
    required this.spin,
    required this.size,
    required this.drift,
  });

  final Color color;
  final double angle;
  final double speed;
  final double spin;
  final double size;
  final double drift;
}

class _ConfettiPainter extends CustomPainter {
  const _ConfettiPainter(this.pieces, this.t);

  final List<_Piece> pieces;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final origin = Offset(size.width / 2, size.height * 0.38);
    final paint = Paint()..style = PaintingStyle.fill;
    final reach = size.shortestSide * 0.9;

    for (final piece in pieces) {
      // Fired outward, then pulled down — a burst that becomes a fall.
      final distance = reach * piece.speed * Curves.easeOutCubic.transform(t);
      final gravity = size.height * 0.55 * t * t;

      final dx = math.cos(piece.angle) * distance + piece.drift * distance;
      final dy = math.sin(piece.angle) * distance + gravity;

      final opacity = t < 0.75 ? 1.0 : (1 - (t - 0.75) / 0.25).clamp(0.0, 1.0);
      paint.color = piece.color.withValues(alpha: opacity);

      canvas.save();
      canvas.translate(origin.dx + dx, origin.dy + dy);
      canvas.rotate(piece.spin * t);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: piece.size,
            height: piece.size * 0.62,
          ),
          const Radius.circular(2),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) =>
      oldDelegate.t != t;
}
