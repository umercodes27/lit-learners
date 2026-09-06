import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/age2_skin.dart';

/// The koala who turns up on every age-2 screen.
///
/// Reuses the guide artwork the rest of the app already knows, so a child meets
/// the same face in the activity pack as everywhere else. Familiarity is the
/// whole job here: a constant companion across modules is what makes five
/// subjects feel like one place rather than five apps.
///
/// It breathes — a slow, small bob — because a perfectly still character reads
/// as a sticker, and a moving one reads as someone keeping you company.
class Age2Mascot extends StatefulWidget {
  const Age2Mascot({
    super.key,
    this.size = 62,
    this.animate = true,
  });

  static const _portrait = 'assets/images/koala/koala_guide_portrait.png';

  final double size;

  /// Off for the tiny header instance on dense screens, and in tests.
  final bool animate;

  @override
  State<Age2Mascot> createState() => _Age2MascotState();
}

class _Age2MascotState extends State<Age2Mascot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bob = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Honour the platform's reduce-motion setting: a perpetual bob is exactly
    // the kind of idle movement that switch exists to stop. It also keeps the
    // mascot out of the way of `pumpAndSettle`, which never settles while an
    // animation repeats.
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final shouldBob = widget.animate && !reduceMotion;

    if (shouldBob && !_bob.isAnimating) {
      _bob.repeat();
    } else if (!shouldBob && _bob.isAnimating) {
      _bob.stop();
    }
  }

  @override
  void dispose() {
    _bob.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = Age2Skin.of(context);

    final face = Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: palette.accent.withValues(alpha: 0.5), width: 3),
        boxShadow: Age2Surfaces.lift(tint: palette.accent),
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(
        Age2Mascot._portrait,
        fit: BoxFit.cover,
        // The mascot is decoration; a missing file must never take a screen
        // down, so it degrades to a friendly blank badge.
        errorBuilder: (context, error, stack) => Icon(
          Icons.pets_rounded,
          size: widget.size * 0.5,
          color: palette.accent,
        ),
      ),
    );

    if (!widget.animate) return face;

    return AnimatedBuilder(
      animation: _bob,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, math.sin(_bob.value * math.pi * 2) * 3),
        child: child,
      ),
      child: face,
    );
  }
}

/// The mascot with a word or two beside it, for the top of a screen.
class Age2MascotBanner extends StatelessWidget {
  const Age2MascotBanner({
    required this.message,
    super.key,
    this.textDirection,
  });

  final String message;
  final TextDirection? textDirection;

  @override
  Widget build(BuildContext context) {
    final palette = Age2Skin.of(context);

    return Row(
      textDirection: textDirection,
      children: [
        const Age2Mascot(size: 58),
        const SizedBox(width: 12),
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.9),
              borderRadius: Age2Surfaces.radius,
              border: Border.all(
                color: palette.accent.withValues(alpha: 0.28),
                width: 2,
              ),
            ),
            child: Text(
              message,
              textDirection: textDirection,
              style: Age2Text.label,
            ),
          ),
        ),
      ],
    );
  }
}
