import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_learners/models/content_item.dart';
import 'package:little_learners/models/learning_level.dart';
import 'package:little_learners/views/child_dashboard/widgets/level_map.dart';

void main() {
  test('every subject gets a road of its own', () {
    const modules = [
      'english',
      'math',
      'urdu',
      'logic',
      'story',
      'drawing',
      'tracing',
      'video',
    ];

    final roads = <String>{};
    for (final id in modules) {
      final shape = MapShape.forModule(id);
      roads.add(
        '${shape.amplitude}/${shape.frequency}/${shape.phase}/${shape.spacing}',
      );
    }

    // The whole point of deriving the shape from the id: two subjects should
    // not be the same road in two colours.
    expect(roads, hasLength(modules.length));
  });

  test('a module keeps the same road every time it is opened', () {
    final first = MapShape.forModule('english');
    final second = MapShape.forModule('english');

    expect(first.amplitude, second.amplitude);
    expect(first.frequency, second.frequency);
    expect(first.phase, second.phase);
    expect(first.spacing, second.spacing);
  });

  test('however far the road swings, a stop still fits on screen', () {
    const width = 358.0;
    const stopWidth = 196.0;

    for (final id in ['english', 'math', 'urdu', 'story', 'tracing']) {
      final points = MapShape.forModule(id).pointsFor(
        count: 8,
        width: width,
        inset: stopWidth,
        topPadding: 62,
        mirror: false,
      );

      for (final point in points) {
        expect(point.dx - stopWidth / 2, greaterThanOrEqualTo(-0.01),
            reason: id);
        expect(point.dx + stopWidth / 2, lessThanOrEqualTo(width + 0.01),
            reason: id);
      }
    }
  });

  test('Urdu runs the other way', () {
    const width = 358.0;
    final ltr = MapShape.forModule('urdu').pointsFor(
      count: 4, width: width, inset: 196, topPadding: 62, mirror: false,
    );
    final rtl = MapShape.forModule('urdu').pointsFor(
      count: 4, width: width, inset: 196, topPadding: 62, mirror: true,
    );

    for (var i = 0; i < ltr.length; i++) {
      expect(rtl[i].dx, closeTo(width - ltr[i].dx, 0.001));
      expect(rtl[i].dy, ltr[i].dy);
    }
  });

  testWidgets('a stop prints its caption instead of portion and steps',
      (tester) async {
    await _pumpMap(tester, caption: 'Trace the shape');

    expect(find.text('Trace the shape'), findsOneWidget);
    // The line a seeded stop would have shown from the same level.
    expect(find.textContaining('2 steps'), findsNothing);
  });

  testWidgets('without a caption a stop still counts its own steps',
      (tester) async {
    await _pumpMap(tester);

    expect(find.textContaining('2 steps'), findsOneWidget);
  });

  testWidgets('the trophy is tappable only when something waits behind it',
      (tester) async {
    var taps = 0;
    await _pumpMap(tester, onGoalTap: () => taps++, goalLabel: 'Quiz time');

    await tester.tap(find.bySemanticsLabel('Quiz time'));
    await tester.pumpAndSettle();
    expect(taps, 1);

    // With no callback the marker goes back to being decoration.
    await _pumpMap(tester);
    expect(find.bySemanticsLabel('Quiz time'), findsNothing);
  });
}

Future<void> _pumpMap(
  WidgetTester tester, {
  String? caption,
  VoidCallback? onGoalTap,
  String? goalLabel,
}) async {
  tester.view.physicalSize = const Size(390, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: LevelMap(
            moduleId: 'english',
            accent: Colors.amber,
            textDirection: TextDirection.ltr,
            onOpen: (_) {},
            onDownload: (_) {},
            onLocked: (_) {},
            onGoalTap: onGoalTap,
            goalLabel: goalLabel,
            stops: [
              LevelStopData(
                level: _level,
                stars: 0,
                completed: false,
                canOpen: true,
                canDownload: false,
                lockReason: '',
                caption: caption,
              ),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

const _level = LearningLevel(
  id: 'level-1',
  moduleId: 'english',
  stage: 1,
  levelNumber: 1,
  title: 'Meet A',
  subtitle: 'Look and listen.',
  type: LevelType.flashcards,
  passingScore: 1,
  isBundled: true,
  contentItems: [
    ContentItem(
      title: 'A',
      prompt: 'Say A',
      displayText: 'A',
      visualLabel: 'Apple',
    ),
    ContentItem(
      title: 'B',
      prompt: 'Say B',
      displayText: 'B',
      visualLabel: 'Ball',
    ),
  ],
);
