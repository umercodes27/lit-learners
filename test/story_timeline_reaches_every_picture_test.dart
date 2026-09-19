import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_learners/models/activity_data.dart';
import 'package:little_learners/widgets/activities/activity_audio.dart';
import 'package:little_learners/widgets/activities/activity_stage.dart';
import 'package:little_learners/widgets/activities/story_interactive_widget.dart';

/// However long the voice lasts, every picture gets shown.
///
/// The silent timeline used to stop at twenty seconds flat, and a five-picture
/// story times its last picture at exactly twenty — so that picture appeared
/// for no time at all. Age 3's "My Day" was the story that had five; it has
/// since been taken out of the pack, but the timeline still has to hold for
/// any story authored that long, which is why the pictures here are the
/// test's own rather than a pack's.
///
/// In its own file deliberately. Run after the tests that read the narration
/// files off the bundle, this hung for the full ten-minute timeout while
/// passing on its own.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a five-picture story reaches its fifth picture', (tester) async {
    // Five pictures on the pack's default spacing: 0, 5s, 10s, 15s, 20s.
    // No narration, because the picture timeline is what is under test.
    const data = StoryInteractiveData(
      title: 'A long day',
      isRtl: false,
      illustrations: [
        StoryIllustration(image: 'assets/age3/img/story/one.png', startMs: 0),
        StoryIllustration(
            image: 'assets/age3/img/story/two.png', startMs: 5000),
        StoryIllustration(
            image: 'assets/age3/img/story/three.png', startMs: 10000),
        StoryIllustration(
            image: 'assets/age3/img/story/four.png', startMs: 15000),
        StoryIllustration(
            image: 'assets/age3/img/story/five.png', startMs: 20000),
      ],
    );

    await tester.pumpWidget(MaterialApp(
      home: StoryInteractiveWidget(data: data, audio: _SilentAudio()),
    ));
    await tester.pump();

    // The timeline is a periodic timer, so it has to be stepped rather than
    // jumped: one long pump fires it once.
    var reached = 0;
    for (var i = 0; i < 100; i++) {
      await tester.pump(const Duration(milliseconds: 250));
      final stage = tester.any(find.byType(ActivityStage))
          ? tester.widget<ActivityStage>(find.byType(ActivityStage))
          : null;
      final index = stage?.roundIndex;
      if (index != null && index > reached) reached = index;
    }

    expect(reached, 4,
        reason: 'the story stopped on picture ${reached + 1} of 5');
  });
}

/// Audio that answers instantly.
///
/// The real [ActivityAudio] talks to audioplayers, which has no platform side
/// under `flutter test`: its futures never complete, so a screen that awaits
/// one stalls forever.
class _SilentAudio extends ActivityAudio {
  @override
  Future<void> playPrompt(String? assetPath) async {}

  @override
  Future<void> playCorrect() async {}

  @override
  Future<void> playWrong() async {}

  @override
  Future<void> stopPrompt() async {}

  @override
  Future<void> dispose() async {}
}
