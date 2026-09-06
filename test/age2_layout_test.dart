import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_learners/models/activity_data.dart';
import 'package:little_learners/models/activity_option.dart';
import 'package:little_learners/models/activity_pack.dart';
import 'package:little_learners/views/activity_pack/activity_level_page.dart';

/// Guards the age-2 screens against laying out at the wrong size.
///
/// The bug these exist for: the level page stacked the activity behind a small
/// back button without [StackFit.expand], so the stack took the button's size
/// and the entire activity was crammed into a seventy-pixel strip — audible,
/// but invisible. Nothing else caught it, because every other test renders a
/// component directly rather than through the page that hosts it.
void main() {
  ActivityLevel level(ActivityData data) => ActivityLevel(
        key: 'level_1',
        moduleKey: 'english',
        data: data,
      );

  const twoChoice = TwoChoiceTapData(
    title: 'Letter Choice (2 Options)',
    isRtl: false,
    items: [
      TwoChoiceTapItem(
        options: [
          ActivityOption(label: 'A', isCorrect: true),
          ActivityOption(label: 'M'),
        ],
      ),
      TwoChoiceTapItem(
        options: [
          ActivityOption(label: 'C', isCorrect: true),
          ActivityOption(label: 'E'),
        ],
      ),
    ],
  );

  /// Sizes a real device or window would actually present.
  const sizes = <String, Size>{
    'phone portrait': Size(390, 844),
    'small phone': Size(320, 640),
    'tablet': Size(834, 1112),
    'short landscape window': Size(1280, 620),
  };

  for (final entry in sizes.entries) {
    testWidgets('the level page lays out cleanly on ${entry.key}',
        (tester) async {
      tester.view.physicalSize = entry.value;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(MaterialApp(
        home: ActivityLevelPage(args: ActivityLevelArgs(level: level(twoChoice))),
      ));
      await tester.pump();

      expect(tester.takeException(), isNull,
          reason: 'overflowed or threw on ${entry.key}');
    });
  }

  testWidgets('the activity fills the page rather than a corner of it',
      (tester) async {
    const size = Size(390, 844);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      home: ActivityLevelPage(args: ActivityLevelArgs(level: level(twoChoice))),
    ));
    await tester.pump();

    // The title has to sit out in the page, not inside a squeezed strip. A
    // back button is about 70 wide, which is what the broken layout collapsed
    // to, so anything comfortably past that proves the stack expanded.
    final titleWidth =
        tester.getSize(find.text('Letter Choice (2 Options)')).width;
    expect(titleWidth, greaterThan(150),
        reason: 'the activity was squeezed into the back button of a strip');

    // Both answers are on screen and reachable.
    for (final label in ['A', 'M']) {
      final centre = tester.getCenter(find.text(label));
      expect(centre.dx, greaterThan(0));
      expect(centre.dx, lessThan(size.width));
      expect(centre.dy, greaterThan(0));
      expect(centre.dy, lessThan(size.height));
    }
  });

  testWidgets('answer targets stay big enough to hit', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      home: ActivityLevelPage(args: ActivityLevelArgs(level: level(twoChoice))),
    ));
    await tester.pump();

    // Even on the narrowest phone, an answer must clear the 80-pixel floor the
    // design calls for.
    for (final label in ['A', 'M']) {
      final box = tester.getSize(
        find.ancestor(
          of: find.text(label),
          matching: find.byType(Container),
        ).first,
      );
      expect(box.width, greaterThanOrEqualTo(80));
      expect(box.height, greaterThanOrEqualTo(80));
    }
  });
}
