import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_learners/models/activity_data.dart';
import 'package:little_learners/services/content/activity_pack_loader.dart';
import 'package:little_learners/widgets/activities/activity_audio.dart';
import 'package:little_learners/widgets/activities/story_interactive_widget.dart';

/// The question a story stops to ask.
///
/// The bug: age 4 names the answer as a slug and no options, the screen opened
/// the choice panel anyway, and the panel drew no buttons — so "What should
/// you say?" appeared with nothing to tap and no way to finish the story.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Drives a story to its question. With no narration the widget runs a
  /// fallback timeline and asks at the end of it.
  Future<void> openChoiceOn(
    WidgetTester tester,
    StoryInteractiveData data, {
    VoidCallback? onCompleted,
  }) async {
    await tester.pumpWidget(MaterialApp(
      home: StoryInteractiveWidget(
        data: data,
        audio: _SilentAudio(),
        onCompleted: onCompleted,
      ),
    ));
    await tester.pump();
    // The fallback timeline is a periodic timer, so it has to be stepped
    // rather than jumped: one long pump fires it once and the story never
    // reaches its question.
    for (var i = 0; i < 90; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
  }

  StoryInteractiveData mannersStory() => StoryInteractiveData(
        title: 'Manners',
        isRtl: false,
        illustrations: const [
          StoryIllustration(
            image: 'assets/age4/img/story/manners_1.png',
            startMs: 0,
          ),
        ],
        choicePoint: StoryChoicePoint.fromJson(const {
          'prompt': 'What should you say?',
          'correct_answer': 'please_and_thank_you',
        }),
      );


  test('a slug answer becomes something to tap, spelled as it is said', () {
    final choice = StoryChoicePoint.fromJson(const {
      'prompt': 'What should you say?',
      'correct_answer': 'please_and_thank_you',
    });

    expect(choice.options, hasLength(1));
    expect(choice.options.single.label, 'Please and thank you');
    expect(choice.options.single.isCorrect, isTrue);
    expect(choice.promptText, 'What should you say?');
  });

  test('the age-4 manners story now has an answer on it', () async {
    final pack =
        (await ActivityPackLoader().load(path: ActivityPackLoader.age4Path))
            .pack!;
    final data = pack
        .levelByKey('storytelling', 'social_emotional_learning')!
        .data as StoryInteractiveData;

    expect(data.choicePoint, isNotNull);
    expect(data.choicePoint!.options, isNotEmpty,
        reason: 'a prompt with no options is a dead end');
  });

  // Belt and braces: whatever a pack says, the story has to be finishable.
  testWidgets('a choice point with no options does not strand the story',
      (tester) async {
    final data = StoryInteractiveData(
      title: 'Manners',
      isRtl: false,
      illustrations: const [
        StoryIllustration(
          image: 'assets/age4/img/story/manners_1.png',
          startMs: 0,
        ),
      ],
      choicePoint: StoryChoicePoint.fromJson(const {
        'prompt': 'What should you say?',
        // Neither options, nor correct_image, nor correct_answer.
      }),
    );

    // The parse leaves it empty...
    expect(data.choicePoint!.options, isEmpty);

    await openChoiceOn(tester, data);

    // ...and the story runs to its end instead of stopping on a question the
    // child cannot answer.
    expect(find.text('What should you say?'), findsNothing,
        reason: 'an unanswerable prompt should never be shown');
    expect(find.text('The end!'), findsOneWidget,
        reason: 'the story must still be finishable');
  });

  // The button used to be laid out in an unbounded Row at glyph size, so a
  // sentence-length answer ran off both edges of the phone.
  testWidgets('a sentence-long answer fits on a phone', (tester) async {
    tester.view.physicalSize = const Size(360, 690);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await openChoiceOn(tester, mannersStory());

    expect(find.text('Please and thank you'), findsOneWidget);
    expect(tester.takeException(), isNull,
        reason: 'the answer button overflowed the screen');

    final button = tester.getSize(find.text('Please and thank you'));
    expect(button.width, lessThanOrEqualTo(360),
        reason: 'the label is wider than the phone');
  });

  // "When the student gives the correct answer the story should move on."
  testWidgets('answering correctly carries the story on by itself',
      (tester) async {
    var completed = 0;
    await openChoiceOn(tester, mannersStory(), onCompleted: () => completed++);

    await tester.tap(find.text('Please and thank you'));
    await tester.pump();

    // Celebration, then the end screen, then the hand-off — no tap needed.
    await tester.pump(const Duration(milliseconds: 1600));
    expect(find.text('The end!'), findsOneWidget,
        reason: 'the reward should be seen before moving on');

    await tester.pump(const Duration(milliseconds: 2400));
    expect(completed, 1, reason: 'the story should have moved on by itself');

    // And the hand-off happens once, however the child gets there.
    await tester.pump(const Duration(seconds: 2));
    expect(completed, 1);
  });
}

/// Audio that answers instantly.
///
/// The real [ActivityAudio] talks to audioplayers, which has no platform side
/// under `flutter test`: its futures never complete, so a screen that awaits
/// one stalls forever. A story awaits `stopPrompt` before it opens its
/// question, so without this the question never appears — and a test asserting
/// the question is absent would pass for the wrong reason.
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
