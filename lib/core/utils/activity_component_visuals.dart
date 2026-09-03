import 'package:flutter/material.dart';

import '../../models/activity_data.dart';

/// A picture and a plain-words label for each kind of play.
///
/// A toddler navigates by the shape rather than the word, so the icon has to
/// say something about the action: a hand for tapping, a pencil stroke for
/// tracing, arrows for dragging one thing onto another. It lives here so the
/// age-pack browser and the dashboard's module list label the same activity
/// identically — meeting one icon in two places is what makes it learnable.
class ActivityComponentVisuals {
  const ActivityComponentVisuals._();

  static IconData iconFor(ActivityComponent component) {
    return switch (component) {
      ActivityComponent.twoChoiceTap => Icons.touch_app_rounded,
      ActivityComponent.identifyAndTap => Icons.search_rounded,
      ActivityComponent.tapToCount => Icons.filter_5_rounded,
      ActivityComponent.shadowMatch => Icons.contrast_rounded,
      ActivityComponent.puzzle => Icons.extension_rounded,
      ActivityComponent.oddOneOut => Icons.psychology_alt_rounded,
      ActivityComponent.storyInteractive => Icons.auto_stories_rounded,
      ActivityComponent.listenAndSee => Icons.hearing_rounded,
      ActivityComponent.tracing => Icons.gesture_rounded,
      ActivityComponent.dragAndMatch => Icons.compare_arrows_rounded,
      ActivityComponent.sortIntoZones => Icons.inbox_rounded,
      ActivityComponent.patternComplete => Icons.auto_awesome_motion_rounded,
      ActivityComponent.unknown => Icons.hourglass_empty_rounded,
    };
  }

  /// What the child will be doing, for the adult reading over their shoulder.
  static String labelFor(ActivityComponent component) {
    return switch (component) {
      ActivityComponent.twoChoiceTap => 'Tap the right one',
      ActivityComponent.identifyAndTap => 'Find it and tap',
      ActivityComponent.tapToCount => 'Count along',
      ActivityComponent.shadowMatch => 'Match the shadow',
      ActivityComponent.puzzle => 'Build the picture',
      ActivityComponent.oddOneOut => 'Spot the odd one',
      ActivityComponent.storyInteractive => 'Listen to a story',
      ActivityComponent.listenAndSee => 'Listen and look',
      ActivityComponent.tracing => 'Trace the shape',
      ActivityComponent.dragAndMatch => 'Drag to match',
      ActivityComponent.sortIntoZones => 'Sort into groups',
      ActivityComponent.patternComplete => 'Finish the pattern',
      ActivityComponent.unknown => 'Coming soon',
    };
  }
}
