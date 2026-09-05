import 'package:flutter/foundation.dart';

import 'activity_audio.dart';

/// Fires the reward and retry feedback for an activity.
///
/// Sound and animation are driven from one call on purpose. They were separate
/// before, and the failure mode was a component that played applause without
/// the confetti — or a new component that quietly shipped with neither. A
/// single [celebrate] keeps every module feeling the same.
///
/// The pulses are plain counters that the animation widgets listen to; a
/// component never touches an [AnimationController] itself.
class ActivityFeedbackController {
  ActivityFeedbackController({this.audio});

  /// Optional so the widgets can be exercised in tests without a player.
  final ActivityAudio? audio;

  final ValueNotifier<int> correctPulse = ValueNotifier<int>(0);
  final ValueNotifier<int> tryAgainPulse = ValueNotifier<int>(0);

  bool _disposed = false;

  /// Right answer: applause plus a confetti burst.
  Future<void> celebrate() async {
    if (_disposed) return;
    correctPulse.value++;
    await audio?.playCorrect();
  }

  /// Wrong answer: the gentle cue, never a buzzer.
  Future<void> tryAgain() async {
    if (_disposed) return;
    tryAgainPulse.value++;
    await audio?.playWrong();
  }

  void dispose() {
    _disposed = true;
    correctPulse.dispose();
    tryAgainPulse.dispose();
  }
}
