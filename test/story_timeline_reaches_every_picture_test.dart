import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_learners/models/activity_data.dart';
import 'package:little_learners/services/content/activity_pack_loader.dart';
import 'package:little_learners/widgets/activities/activity_audio.dart';
import 'package:little_learners/widgets/activities/activity_stage.dart';
import 'package:little_learners/widgets/activities/story_interactive_widget.dart';

/// However long the voice lasts, every picture gets shown.
///
/// "My Day" is the longest picture sequence in the app — five, timed out to
/// twenty seconds — and the timeline used to stop at twenty flat, so the fifth
/// picture appeared for no time at all.
///
/// In its own file deliberately. Run after the tests that read the narration
/// files off the bundle, this hung for the full ten-minute timeout while
/// passing on its own.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a five-picture story reaches its fifth picture', (tester) async {
    final pack =
        (await ActivityPackLoader().load(path: ActivityPackLoader.age3Path))
            .pack!;
    final authored = pack
        .levelByKey('storytelling', 'daily_routine_stories')!
        .data as StoryInteractiveData;

    expect(authored.illustrations, hasLength(5));

    // The pack's own pictures, on the silent timeline. Deliberately not its
    // narration: whether a clip counts as present is ambient — AssetAvailability
    // is a singleton — and what is under test here is the picture timeline.
    final data = StoryInteractiveData(
      title: authored.title,
      isRtl: authored.isRtl,
      illustrations: authored.illustrations,
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
