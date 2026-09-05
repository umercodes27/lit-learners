import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/audio/app_sounds.dart';
import '../../services/audio/sound_controller.dart';
import 'play_motion.dart';

/// Makes anything squish when a finger lands on it and spring back when it
/// lifts.
///
/// The most important widget in the child-facing app. At one to four years old
/// the joy is cause and effect — *I touched it and it moved* — and until now
/// nothing in this app reacted to a touch at all. Wrapping a tappable in
/// [Squishy] is what turns a screen from a page into a toy.
///
/// Wrap the widget, do not restyle it:
///
/// ```dart
/// Squishy(
///   onTap: () => open(module),
///   child: ModuleCard(module: module),
/// )
/// ```
///
/// A null [onTap] disables the squish along with the tap, so a disabled
/// control stays honestly inert.
class Squishy extends StatefulWidget {
  const Squishy({
    super.key,
    required this.child,
    required this.onTap,
    this.onLongPress,
    this.scale = PlayMotion.pressedScale,
    this.haptic = true,
    this.sound = Sfx.tap,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// How far it compresses. Lower for big surfaces, higher for small ones.
  final double scale;

  /// Fires a light impact on press.
  final bool haptic;

  /// What this makes when it is tapped.
  ///
  /// Every tappable in the app already passes through [Squishy], which makes
  /// this the one place the whole app gets a tap sound. Pass a different [Sfx]
  /// for a control that should say something else, or null for one that
  /// answers with its own sound a moment later — a quiz card, for instance,
  /// where a tap chirp on top of the correct-answer chime is just mud.
  final Sfx? sound;

  final String? semanticLabel;

  @override
  State<Squishy> createState() => _SquishyState();
}

class _SquishyState extends State<Squishy> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: PlayMotion.pressDown,
    reverseDuration: PlayMotion.springBack,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _enabled => widget.onTap != null || widget.onLongPress != null;

  void _press() {
    if (!_enabled) return;
    _controller.forward();
  }

  void _release() {
    if (!_enabled) return;
    // elasticOut on the way back is what makes it read as rubber rather than
    // as a fade. Applied on reverse only, so the press itself stays crisp.
    _controller.reverse();
  }

  void _handleTap() {
    if (widget.haptic) HapticFeedback.lightImpact();
    // Unlock before playing, not after. A browser only allows audio inside a
    // gesture handler, and this is one — so the very first tap makes a sound
    // instead of being the silent one that buys the rest.
    AppSound.instance.unlock();
    final sound = widget.sound;
    if (sound != null) AppSound.play(sound);
    widget.onTap?.call();
  }

  void _handleLongPress() {
    if (widget.onLongPress == null) return;
    if (widget.haptic) HapticFeedback.mediumImpact();
    AppSound.instance.unlock();
    widget.onLongPress!.call();
  }

  @override
  Widget build(BuildContext context) {
    // Reduced motion keeps the tap and the haptic, drops the movement.
    if (PlayMotion.reduced(context)) {
      return _wrapSemantics(
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap == null ? null : _handleTap,
          onLongPress: widget.onLongPress == null ? null : _handleLongPress,
          child: widget.child,
        ),
      );
    }

    return _wrapSemantics(
      GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _press(),
        onTapUp: (_) => _release(),
        onTapCancel: _release,
        onTap: widget.onTap == null ? null : _handleTap,
        onLongPress: widget.onLongPress == null ? null : _handleLongPress,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final t = _controller.status == AnimationStatus.reverse ||
                    _controller.status == AnimationStatus.dismissed
                ? PlayMotion.springCurve.transform(_controller.value)
                : _controller.value;
            final scale = 1 - (1 - widget.scale) * t.clamp(0.0, 1.4);
            return Transform.scale(scale: scale, child: child);
          },
          child: widget.child,
        ),
      ),
    );
  }

  Widget _wrapSemantics(Widget child) {
    if (widget.semanticLabel == null) return child;
    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: ExcludeSemantics(child: child),
    );
  }
}
