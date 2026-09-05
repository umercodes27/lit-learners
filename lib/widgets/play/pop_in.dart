import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'play_motion.dart';

/// Staggered entrance for anything arriving on screen.
///
/// Generalises the idea already hand-rolled in `home_page.dart`, where each
/// module tile dropped into place one after another.
///
/// **Deliberately built on a plain [AnimationController] rather than on
/// `flutter_animate`.** `Animate` schedules an internal `Timer`, and a list
/// item disposed before it fires leaves it pending — which fails every widget
/// test on that screen with "A Timer is still pending even after the widget
/// tree was disposed". `flutter_animate` is still the right tool for one-shot
/// flourishes on long-lived widgets; it is the wrong tool inside a list.
///
/// ```dart
/// for (var i = 0; i < modules.length; i++)
///   PopIn(index: i, child: ModuleCard(module: modules[i]))
/// ```
class PopIn extends StatefulWidget {
  const PopIn({
    super.key,
    required this.child,
    this.index = 0,
    this.slide = true,
  });

  final Widget child;

  /// Position in the list. Later items start later, capped by
  /// [PlayMotion.staggerFor] so the tail of a long list is not left blank.
  final int index;

  /// Rise into place as well as scaling up.
  final bool slide;

  @override
  State<PopIn> createState() => _PopInState();
}

class _PopInState extends State<PopIn> with SingleTickerProviderStateMixin {
  static const _maxSteps = 8;

  late final int _totalMs =
      PlayMotion.staggerFor(_maxSteps).inMilliseconds +
          PlayMotion.enter.inMilliseconds;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: _totalMs),
  )..forward();

  late final Animation<double> _t = CurvedAnimation(
    parent: _controller,
    // The stagger is an interval inside one animation, so there is no timer
    // and nothing to leak when this is disposed mid-flight.
    curve: Interval(
      PlayMotion.staggerFor(widget.index, maxSteps: _maxSteps).inMilliseconds /
          _totalMs,
      (PlayMotion.staggerFor(widget.index, maxSteps: _maxSteps).inMilliseconds +
              PlayMotion.enter.inMilliseconds) /
          _totalMs,
      curve: PlayMotion.enterCurve,
    ),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (PlayMotion.reduced(context)) return widget.child;

    return AnimatedBuilder(
      animation: _t,
      child: widget.child,
      builder: (context, child) {
        final t = _t.value;
        // easeOutBack overshoots past 1, which is the point — but opacity
        // cannot, so it is clamped separately.
        final opacity = t.clamp(0.0, 1.0);
        final scale = 0.82 + 0.18 * t;
        final offset = widget.slide ? (1 - t) * 22 : 0.0;

        return Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: Offset(0, offset),
            child: Transform.scale(scale: scale, child: child),
          ),
        );
      },
    );
  }
}

/// Draws attention to the one thing a child should touch next.
///
/// Deliberately restrained: it waits [after] of stillness, then gives a short
/// wiggle. A permanently wiggling screen tells a toddler nothing, because
/// everything is moving equally.
///
/// This one loops forever by design, so `pumpAndSettle` will hang on a screen
/// that uses it. Use it on a screen with no widget test, or pump fixed
/// durations in the test.
class IdleWiggle extends StatelessWidget {
  const IdleWiggle({
    super.key,
    required this.child,
    this.after = const Duration(seconds: 6),
    this.enabled = true,
  });

  final Widget child;
  final Duration after;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (!enabled || PlayMotion.reduced(context)) return child;

    return child
        .animate(onPlay: (c) => c.repeat())
        // The long rest between repeats is the point: wiggle, then wait,
        // rather than a constant jiggle that becomes background noise.
        .shimmer(
          delay: after,
          duration: 900.ms,
          color: Colors.white.withValues(alpha: 0.45),
        )
        .shakeX(delay: after, hz: 3, amount: 2)
        .then(delay: after);
  }
}
