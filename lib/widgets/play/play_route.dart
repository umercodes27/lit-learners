import 'package:flutter/material.dart';

import 'play_motion.dart';

/// Screen transitions that pop rather than slide.
///
/// Every route in the app is a `MaterialPageRoute`, which gives the stock
/// platform push — correct for a banking app, invisible to a two-year-old.
/// This grows the new screen in from slightly small while fading, so a screen
/// change reads as *something arriving* rather than as a page turn.
///
/// Drop-in replacement:
///
/// ```dart
/// return PlayPageRoute<void>(
///   settings: settings,
///   builder: (_) => const HomePage(),
/// );
/// ```
class PlayPageRoute<T> extends PageRouteBuilder<T> {
  PlayPageRoute({
    required WidgetBuilder builder,
    super.settings,
    super.fullscreenDialog,
  }) : super(
          transitionDuration: PlayMotion.route,
          reverseTransitionDuration: const Duration(milliseconds: 300),
          pageBuilder: (context, animation, secondaryAnimation) =>
              builder(context),
          transitionsBuilder: (context, animation, secondary, child) {
            // Respect the platform's reduced-motion setting: a plain fade
            // still reads as a change without the movement.
            if (PlayMotion.reduced(context)) {
              return FadeTransition(opacity: animation, child: child);
            }

            final entering = CurvedAnimation(
              parent: animation,
              curve: PlayMotion.enterCurve,
              reverseCurve: Curves.easeIn,
            );

            return FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: const Interval(0, 0.6),
              ),
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.88, end: 1).animate(entering),
                child: child,
              ),
            );
          },
        );
}
