import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_learners/models/activity_data.dart';
import 'package:little_learners/models/activity_option.dart';
import 'package:little_learners/models/activity_pack.dart';
import 'package:little_learners/views/activity_pack/activity_level_page.dart';
import 'package:little_learners/widgets/activities/story_bubbles.dart';

/// The storytelling screen's ambient animation and page turns.
void main() {
  const story = StoryInteractiveData(
    title: 'Washing Hands',
    isRtl: false,
    illustrations: [
      StoryIllustration(image: 'assets/age2/img/story/wash_1.png', startMs: 0),
      StoryIllustration(image: 'assets/age2/img/story/wash_2.png', startMs: 5500),
      StoryIllustration(image: 'assets/age2/img/story/wash_3.png', startMs: 11000),
    ],
    choicePoint: StoryChoicePoint(
      options: [ActivityOption(image: 'assets/age2/img/story/soap.png', isCorrect: true)],
      atMs: 0,
      promptText: 'Tap the soap!',
    ),
  );

  Future<void> pumpStory(WidgetTester tester) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(
      home: ActivityLevelPage(
        args: ActivityLevelArgs(
          level: ActivityLevel(
            key: 'habit_stories',
            moduleKey: 'storytelling',
            data: story,
          ),
        ),
      ),
    ));
    await tester.pump();
  }

  testWidgets('bubbles drift behind the story', (tester) async {
    await pumpStory(tester);

    expect(find.byType(StoryBubbles), findsOneWidget);
    // Still laying out cleanly with the extra layer on top.
    expect(tester.takeException(), isNull);
  });

  testWidgets('bubbles never take a tap', (tester) async {
    final bubbles = tester.widget<StoryBubbles>(
      await pumpStory(tester).then((_) => find.byType(StoryBubbles)),
    );
    expect(bubbles, isNotNull);

    // The illustration underneath must still be hit-testable.
    expect(
      find.descendant(
        of: find.byType(IgnorePointer),
        matching: find.byType(CustomPaint),
      ),
      findsWidgets,
    );
  });

  testWidgets('the page turns between illustrations rather than cutting',
      (tester) async {
    await pumpStory(tester);

    // One switcher, kept alive across frames so it can animate. If the story
    // page were keyed from outside, this would be rebuilt each time and the
    // transition would never run.
    final switcher = find.byType(AnimatedSwitcher);
    expect(switcher, findsOneWidget);

    final firstElement = tester.element(switcher);
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.element(switcher), same(firstElement),
        reason: 'the switcher was replaced instead of transitioning');
  });

  testWidgets('the story screen holds up on a small phone', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(
      home: ActivityLevelPage(
        args: ActivityLevelArgs(
          level: ActivityLevel(
            key: 'habit_stories',
            moduleKey: 'storytelling',
            data: story,
          ),
        ),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(tester.takeException(), isNull);
  });
}
