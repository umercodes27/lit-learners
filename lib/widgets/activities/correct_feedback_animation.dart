import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

/// A confetti burst for a right answer.
///
/// Drawn with a [CustomPainter] rather than a package or a bundled animation
/// file: the whole effect is a few dozen rectangles under gravity, and keeping
/// it in code means no new dependency and no asset to ship per age pack.
///
/// Plays whenever [pulse] changes, so one instance can celebrate every round
/// of a level. It is purely decorative — wrapped in [IgnorePointer] so it can
/// never swallow a tap, and it renders nothing at all when idle.
class CorrectFeedbackAnimation extends StatefulWidget {
  /// Identifies the painted layer, so a test can tell the burst apart from
  /// the many other [CustomPaint]s Material puts on screen.
  static const paintKey = ValueKey<String>('correct-feedback-confetti');

  const CorrectFeedbackAnimation({
    required this.pulse,
    super.key,
    this.duration = const Duration(milliseconds: 1500),
    this.pieceCount = 54,
  });

  /// Bump this to fire the burst. The value doubles as the random seed, so a
  /// replay of the same round looks the same and a new round looks different.
  final ValueListenable<int> pulse;

  final Duration duration;
  final int pieceCount;

  @override
  State<CorrectFeedbackAnimation> createState() =>
      _CorrectFeedbackAnimationState();
}

class _CorrectFeedbackAnimationState extends State<CorrectFeedbackAnimation>
    with SingleTickerProviderStateMixin {
  static const _colors = <Color>[
    AppColors.honey,
    AppColors.coral,
    AppColors.lime,
    AppColors.sky,
    AppColors.plum,
    AppColors.aqua,
    AppColors.rose,
    AppColors.leaf,
  ];

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  List<_ConfettiPiece> _pieces = const [];

  @override
  void initState() {
    super.initState();
    widget.pulse.addListener(_onPulse);
  }

  @override
  void didUpdateWidget(CorrectFeedbackAnimation oldWidget) {
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
    setState(() => _pieces = _buildPieces(widget.pulse.value));
    _controller.forward(from: 0);
  }

  List<_ConfettiPiece> _buildPieces(int seed) {
    final random = math.Random(seed);
    return List.generate(widget.pieceCount, (index) {
      // Fan the burst upward and outward: straight-down pieces read as a
      // dropped handful rather than a popper.
      final angle = -math.pi / 2 + (random.nextDouble() - 0.5) * math.pi * 1.15;
      return _ConfettiPiece(
        angle: angle,
        speed: 0.45 + random.nextDouble() * 0.75,
        width: 6 + random.nextDouble() * 7,
        height: 9 + random.nextDouble() * 9,
        color: _colors[random.nextInt(_colors.length)],
        spin: (random.nextDouble() - 0.5) * 14,
        drift: (random.nextDouble() - 0.5) * 0.35,
        isRound: random.nextBool(),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          // Gone entirely when idle or finished, rather than lingering as a
          // transparent layer over the next round.
          if (!_controller.isAnimating || _pieces.isEmpty) {
            return const SizedBox.expand();
          }
          return CustomPaint(
            key: CorrectFeedbackAnimation.paintKey,
            size: Size.infinite,
            painter: _ConfettiPainter(
              pieces: _pieces,
              progress: _controller.value,
            ),
          );
        },
      ),
    );
  }
}

@immutable
class _ConfettiPiece {
  const _ConfettiPiece({
    required this.angle,
    required this.speed,
    required this.width,
    required this.height,
    required this.color,
    required this.spin,
    required this.drift,
    required this.isRound,
  });

  final double angle;
  final double speed;
  final double width;
  final double height;
  final Color color;
  final double spin;

  /// Sideways wander, so pieces do not fall on rails.
  final double drift;
  final bool isRound;
}

class _ConfettiPainter extends CustomPainter {
  const _ConfettiPainter({required this.pieces, required this.progress});

  final List<_ConfettiPiece> pieces;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final origin = Offset(size.width / 2, size.height * 0.42);
    final reach = size.shortestSide;
    final paint = Paint()..style = PaintingStyle.fill;

    // Pieces shoot out, gravity takes over, then everything fades in the last
    // third so the screen is clear before the next round starts.
    final fade = progress < 0.66 ? 1.0 : 1 - (progress - 0.66) / 0.34;

    for (final piece in pieces) {
      final travel = piece.speed * reach;
      final dx = math.cos(piece.angle) * travel * progress +
          piece.drift * reach * progress * progress;
      final dy = math.sin(piece.angle) * travel * progress +
          1.65 * reach * progress * progress;

      final centre = origin + Offset(dx, dy);
      if (centre.dy > size.height + 40) continue;

      paint.color = piece.color.withValues(alpha: fade.clamp(0.0, 1.0));

      canvas.save();
      canvas.translate(centre.dx, centre.dy);
      canvas.rotate(piece.spin * progress);
      if (piece.isRound) {
        canvas.drawCircle(Offset.zero, piece.width / 2, paint);
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset.zero,
              width: piece.width,
              height: piece.height,
            ),
            const Radius.circular(2),
          ),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.pieces != pieces;
}
