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

    var completed = false;
    await tester.pumpWidget(MaterialApp(
      home: StoryInteractiveWidget(
        data: data,
        audio: ActivityAudio(),
        onCompleted: () => completed = true,
      ),
    ));
    await tester.pump();

    // ...and the screen must not offer a question the child cannot answer.
    expect(find.text('What should you say?'), findsNothing,
        reason: 'an unanswerable prompt should never be shown');
    expect(completed, isFalse, reason: 'sanity: nothing was tapped');
  });
}
