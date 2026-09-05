import 'package:flutter/material.dart';

/// Motion vocabulary for the child-facing app.
///
/// One place for every duration and curve, so the whole app moves like a
/// single toy rather than like a dozen separately-tuned widgets. This is the
/// motion counterpart to `AppColors`.
///
/// The guiding rule for ages 1-4: **motion directs attention, it does not
/// compete for it.** An idle attractor runs on the one thing a child should
/// touch next, never on everything at once — a screen where everything wiggles
/// tells a toddler nothing about where to look.
class PlayMotion {
  const PlayMotion._();

  /// Finger goes down. Deliberately faster than the release: the response has
  /// to feel like it happened *because* of the touch, not after it.
  static const pressDown = Duration(milliseconds: 90);

  /// Finger comes up and the widget springs back past its resting size.
  static const springBack = Duration(milliseconds: 420);

  /// Something arriving on screen.
  static const enter = Duration(milliseconds: 500);

  /// A full breath of the slow idle float.
  static const idleFloat = Duration(milliseconds: 2600);

  /// A celebratory pop — a star landing, a card growing.
  static const pop = Duration(milliseconds: 460);

  /// Screen-to-screen.
  static const route = Duration(milliseconds: 420);

  /// Per-item delay when a list or grid arrives, multiplied by the index.
  static const stagger = Duration(milliseconds: 70);

  /// How small a button gets while held.
  static const pressedScale = 0.94;

  /// Overshoot on the way back, so it reads as rubber rather than as a fade.
  static const springCurve = Curves.elasticOut;
  static const enterCurve = Curves.easeOutBack;
  static const settleCurve = Curves.easeOutCubic;
  static const floatCurve = Curves.easeInOut;

  /// Corner radius for child-facing surfaces. Far rounder than the 18px the
  /// grown-up screens use — hard corners read as "document".
  static const radius = 28.0;
  static const radiusLarge = 34.0;

  /// Smallest thing a 1-4 year old should be asked to hit. Their aim is bad
  /// and their fingers are small but imprecise, so this is well above the 48px
  /// Material minimum, which is sized for adults.
  static const minTouchTarget = 72.0;

  /// Primary actions on a child screen.
  static const primaryTouchTarget = 96.0;

  /// Whether the platform or the user has asked for calmer motion.
  ///
  /// Child screens stay gently alive rather than going fully static — a
  /// completely still screen gives a toddler no signal at all — but every
  /// looping and decorative animation stops.
  static bool reduced(BuildContext context) {
    return MediaQuery.maybeDisableAnimationsOf(context) ?? false;
  }

  /// Entrance delay for the item at [index], capped so the tail of a long
  /// list does not sit blank while a child waits.
  static Duration staggerFor(int index, {int maxSteps = 8}) {
    final steps = index < 0 ? 0 : (index > maxSteps ? maxSteps : index);
    return stagger * steps;
  }
}
