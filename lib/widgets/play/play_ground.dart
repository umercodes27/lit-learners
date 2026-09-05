import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'play_colors.dart';

/// A child screen's background: one solid colour, with flat shapes scattered
/// on it.
///
/// Replaces the white-page-with-a-tint the app used everywhere. A screen for a
/// toddler should *be* a colour — the way a page in a board book is a colour —
/// rather than a white sheet with coloured widgets placed on top.
///
/// No gradient anywhere in here, on purpose. Flat colour is what reads at this
/// age, and it costs nothing to draw.
///
/// The shapes are painted once and never animate. A background that repaints
/// forever is the most expensive and least noticed motion in an app, and it
/// hangs every widget test that calls `pumpAndSettle`.
class PlayGround extends StatelessWidget {
  const PlayGround({
    super.key,
    required this.child,
    required this.color,
    this.shapes = 12,
    this.safeArea = true,
  });

  final Widget child;

  /// The screen's colour. Usually the module's, from [PlayColors.forModuleId].
  final Color color;

  final int shapes;
  final bool safeArea;

  @override
  Widget build(BuildContext context) {
    final content = safeArea ? SafeArea(child: child) : child;

    return ColoredBox(
      color: color,
      child: Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(
            child: CustomPaint(
              painter: _ShapePainter(count: shapes, seed: color.toARGB32()),
              size: Size.infinite,
            ),
          ),
          content,
        ],
      ),
    );
  }
}

/// Circles, squares and triangles in white at low opacity — confetti frozen
/// on the wall behind the content.
class _ShapePainter extends CustomPainter {
  const _ShapePainter({required this.count, required this.seed});

  final int count;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(seed);
    final paint = Paint()..style = PaintingStyle.fill;

    for (var i = 0; i < count; i++) {
      final cx = random.nextDouble() * size.width;
      final cy = random.nextDouble() * size.height;
      final side = 16 + random.nextDouble() * 46;
      final rotation = random.nextDouble() * math.pi;

      // Light shapes on colour, and a couple of dark ones for depth.
      paint.color = random.nextDouble() > 0.78
          ? Colors.black.withValues(alpha: 0.05)
          : Colors.white.withValues(alpha: 0.10 + random.nextDouble() * 0.07);

      canvas.save();
      canvas.translate(cx, cy);
      canvas.rotate(rotation);

      switch (i % 3) {
        case 0:
          canvas.drawCircle(Offset.zero, side / 2, paint);
        case 1:
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(center: Offset.zero, width: side, height: side),
              Radius.circular(side * 0.28),
            ),
            paint,
          );
        default:
          final path = Path()
            ..moveTo(0, -side / 2)
            ..lineTo(side / 2, side / 2)
            ..lineTo(-side / 2, side / 2)
            ..close();
          canvas.drawPath(path, paint);
      }

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ShapePainter oldDelegate) =>
      oldDelegate.seed != seed || oldDelegate.count != count;
}
