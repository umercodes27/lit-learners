import 'package:flutter/material.dart';

/// A slow fade-and-rise between age-2 screens.
///
/// The platform default slides a screen in fast and hard from the edge. For a
/// two-year-old that reads as the picture being snatched away, and it is a
/// common reason a child looks up from the screen. This takes more than twice
/// as long, moves a fraction of the distance and never fully hides the outgoing
/// screen, so one activity dissolves into the next.
class GentlePageRoute<T> extends PageRouteBuilder<T> {
  GentlePageRoute({
    required WidgetBuilder builder,
    super.settings,
  }) : super(
          transitionDuration: const Duration(milliseconds: 520),
          reverseTransitionDuration: const Duration(milliseconds: 420),
          pageBuilder: (context, animation, secondaryAnimation) =>
              builder(context),
          transitionsBuilder: (context, animation, secondary, child) {
            final eased = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );
            return FadeTransition(
              opacity: eased,
              child: SlideTransition(
                position: Tween<Offset>(
                  // A hand's width of travel, not a screen's.
                  begin: const Offset(0, 0.06),
                  end: Offset.zero,
                ).animate(eased),
                child: child,
              ),
            );
          },
        );
}
