import 'package:flutter/material.dart';

import '../../core/theme/age2_skin.dart';

/// Everything a two-year-old touches.
///
/// Presses in under the finger and springs back on release, and it does that
/// for *every* tap — before anything knows whether the answer was right. The
/// acknowledgement is the point: at this age a tap that produces no immediate
/// change reads as a broken screen, and the child taps harder rather than
/// waiting for the applause.
///
/// Enforces [Age2Surfaces.minTapTarget] as a floor, so no component can
/// accidentally ship a target too small to hit.
class PlayfulTapTarget extends StatefulWidget {
  const PlayfulTapTarget({
    required this.child,
    super.key,
    this.onTap,
    this.background,
    this.borderColor,
    this.borderWidth = 3,
    this.padding = const EdgeInsets.all(18),
    this.minSize,
    this.semanticLabel,
  });

  final Widget child;

  /// Null leaves the target inert but still fully drawn — used while a round
  /// is resolving, so the screen never appears to lose its buttons.
  final VoidCallback? onTap;

  final Color? background;
  final Color? borderColor;
  final double borderWidth;
  final EdgeInsets padding;
  final double? minSize;
  final String? semanticLabel;

  @override
  State<PlayfulTapTarget> createState() => _PlayfulTapTargetState();
}

class _PlayfulTapTargetState extends State<PlayfulTapTarget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _press = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 90),
    reverseDuration: const Duration(milliseconds: 320),
    lowerBound: 0,
    upperBound: 1,
  );

  late final Animation<double> _scale = _press.drive(
    Tween<double>(begin: 1, end: 0.93).chain(
      // Springs back with a little overshoot, which is what makes the release
      // feel like a button rather than a dimmer.
      CurveTween(curve: Curves.easeOut),
    ),
  );

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  void _down(_) {
    if (widget.onTap == null) return;
    _press.forward();
  }

  void _up([_]) {
    if (!_press.isDismissed) _press.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final palette = Age2Skin.of(context);
    final size = widget.minSize ?? Age2Surfaces.minTapTarget;

    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _down,
        onTapUp: _up,
        onTapCancel: _up,
        onTap: widget.onTap,
        child: ScaleTransition(
          scale: _scale,
          child: Container(
            constraints: BoxConstraints(minWidth: size, minHeight: size),
            padding: widget.padding,
            decoration: BoxDecoration(
              color: widget.background ?? palette.surface,
              borderRadius: Age2Surfaces.radius,
              border: Border.all(
                color: widget.borderColor ?? palette.accent.withValues(alpha: 0.35),
                width: widget.borderWidth,
              ),
              boxShadow: Age2Surfaces.lift(tint: palette.accent),
            ),
            child: Center(child: widget.child),
          ),
        ),
      ),
    );
  }
}
