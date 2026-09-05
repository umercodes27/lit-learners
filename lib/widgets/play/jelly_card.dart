import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import 'play_motion.dart';

/// A chunky, brightly-outlined surface for child screens.
///
/// Replaces the Material [Card] the app was built from. A `Card` is a document
/// device: hairline border, tiny radius, subtle elevation. This is a toy
/// device — a thick coloured edge and a hard offset shadow underneath, so it
/// reads as a physical block a child could pick up.
///
/// The optional [float] gives it a slow idle drift. Use it sparingly; see the
/// note in [PlayMotion] about motion competing for attention.
class JellyCard extends StatefulWidget {
  const JellyCard({
    super.key,
    required this.child,
    required this.color,
    this.padding = const EdgeInsets.all(16),
    this.radius = PlayMotion.radius,
    this.float = false,
    this.floatSeed = 0,
    this.filled = false,
    this.borderWidth = 3,
  });

  final Widget child;

  /// The card's colour world. Pass `ModuleVisuals.colorFor(category)` so a
  /// module keeps one identity everywhere it appears.
  final Color color;

  final EdgeInsetsGeometry padding;
  final double radius;

  /// Slow vertical drift, for cards that are waiting to be chosen.
  final bool float;

  /// Offsets the drift so a grid of cards does not bob in unison.
  final int floatSeed;

  /// Solid colour instead of a white panel with a coloured edge.
  final bool filled;

  final double borderWidth;

  @override
  State<JellyCard> createState() => _JellyCardState();
}

class _JellyCardState extends State<JellyCard>
    with SingleTickerProviderStateMixin {
  AnimationController? _floatController;

  @override
  void initState() {
    super.initState();
    if (widget.float) _startFloat();
  }

  void _startFloat() {
    _floatController ??= AnimationController(
      vsync: this,
      duration: PlayMotion.idleFloat,
    )..repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant JellyCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.float && _floatController == null) _startFloat();
    if (!widget.float) {
      _floatController?.dispose();
      _floatController = null;
    }
  }

  @override
  void dispose() {
    _floatController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final surface = _surface();
    final controller = _floatController;

    if (controller == null || PlayMotion.reduced(context)) return surface;

    // RepaintBoundary matters here: a grid of floating cards on a budget
    // Android phone will repaint the whole subtree otherwise.
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, child) {
          final phase = (controller.value + widget.floatSeed * 0.17) % 1.0;
          final eased = PlayMotion.floatCurve.transform(phase);
          return Transform.translate(
            offset: Offset(0, math.sin(eased * math.pi * 2) * 4),
            child: child,
          );
        },
        child: surface,
      ),
    );
  }

  Widget _surface() {
    final color = widget.color;
    final background = widget.filled
        ? color
        : Color.alphaBlend(color.withValues(alpha: 0.07), AppColors.panel);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(widget.radius),
        border: Border.all(
          color: widget.filled
              ? Colors.white.withValues(alpha: 0.55)
              : color.withValues(alpha: 0.45),
          width: widget.borderWidth,
        ),
        boxShadow: [
          // A hard offset shadow rather than a soft blur. Soft elevation reads
          // as "material surface"; a solid drop reads as a chunky object.
          BoxShadow(
            color: color.withValues(alpha: 0.30),
            offset: const Offset(0, 6),
            blurRadius: 0,
          ),
          BoxShadow(
            color: color.withValues(alpha: 0.18),
            offset: const Offset(0, 10),
            blurRadius: 18,
          ),
        ],
      ),
      child: Padding(padding: widget.padding, child: widget.child),
    );
  }
}
