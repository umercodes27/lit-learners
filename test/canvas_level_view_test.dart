import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_learners/core/theme/app_theme.dart';
import 'package:little_learners/models/canvas_work.dart';
import 'package:little_learners/models/content_item.dart';
import 'package:little_learners/models/learning_level.dart';
import 'package:little_learners/viewmodels/level_activity_viewmodel.dart';
import 'package:little_learners/views/child_dashboard/canvas_level_view.dart';
import 'package:little_learners/widgets/play/play.dart';
import 'package:provider/provider.dart';

void main() {
  group('DrawingLevelView', () {
    testWidgets('a step can only be finished after new marks are made',
        (tester) async {
      await tester.pumpWidget(_host(DrawingLevelView(
        level: _drawingLevel(),
        onFinish: (_) {},
      )));

      expect(find.text('Draw on the page to finish this step.'), findsOneWidget);
      expect(_button(tester, 'I finished this step').onPressed, isNull);

      await _scribble(tester);

      expect(_button(tester, 'I finished this step').onPressed, isNotNull);

      await tester.tap(find.text('I finished this step'));
      await tester.pumpAndSettle();

      expect(find.text('Next step'), findsOneWidget);
    });

    testWidgets('the picture is kept across steps but each step needs new ink',
        (tester) async {
      await tester.pumpWidget(_host(DrawingLevelView(
        level: _drawingLevel(),
        onFinish: (_) {},
      )));

      await _scribble(tester);
      await tester.tap(find.text('I finished this step'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next step'));
      await tester.pumpAndSettle();

      // Second prompt: the earlier strokes are still on the page, but they do
      // not count towards this step.
      expect(find.text('Draw the sky at the top of your page.'), findsNothing);
      expect(find.text('Draw a house under the sky.'), findsOneWidget);
      expect(_button(tester, 'I finished this step').onPressed, isNull);

      await _scribble(tester, from: const Offset(180, 320));

      expect(_button(tester, 'I finished this step').onPressed, isNotNull);
    });

    testWidgets('every drawing tool is offered', (tester) async {
      await tester.pumpWidget(_host(DrawingLevelView(
        level: _drawingLevel(),
        onFinish: (_) {},
      )));

      expect(find.text('Pen'), findsOneWidget);
      expect(find.text('Pencil'), findsOneWidget);
      expect(find.text('Brush'), findsOneWidget);
      expect(find.text('Marker'), findsOneWidget);
      expect(find.text('Eraser'), findsOneWidget);
    });
  });

  group('TracingLevelView', () {
    testWidgets('shows the letter and its guide, and waits for a trace',
        (tester) async {
      await _pumpTracing(tester);

      expect(find.text('A'), findsOneWidget);
      expect(find.text('Trace the letter A.'), findsOneWidget);
      expect(find.text('Trace along the dots, then tap done.'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      // The eraser is offered, the highlighter is not: it would not help here.
      expect(find.text('Eraser'), findsOneWidget);
      expect(find.text('Marker'), findsNothing);

      // Nothing on screen grades the child: that is the parent's job later.
      expect(find.textContaining('%'), findsNothing);
      expect(_button(tester, 'I finished this letter').onPressed, isNull);
    });

    testWidgets('a traced letter can be finished and unlocks the next one',
        (tester) async {
      await _pumpTracing(tester);

      await _scribble(tester);

      expect(_button(tester, 'I finished this letter').onPressed, isNotNull);

      await tester.tap(find.text('I finished this letter'));
      await tester.pumpAndSettle();

      expect(find.text('Next letter'), findsOneWidget);
      expect(find.text('I finished this letter'), findsNothing);
    });

    testWidgets('starting over clears the page and locks done again',
        (tester) async {
      await _pumpTracing(tester);
      await _scribble(tester);

      await tester.tap(find.text('Start over'));
      await tester.pumpAndSettle();

      expect(_button(tester, 'I finished this letter').onPressed, isNull);
    });

    testWidgets('every letter is handed over for a grown-up to mark',
        (tester) async {
      List<CanvasWork>? submitted;
      await _pumpTracing(tester, onFinish: (work) => submitted = work);

      await _scribble(tester);
      await tester.tap(find.text('I finished this letter'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next letter'));
      // One frame to schedule the next glyph's fitting, then real time for the
      // rasterising it does, before the canvas can settle.
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(_settle));
      await tester.pumpAndSettle();

      expect(find.text('B'), findsOneWidget);

      await _scribble(tester, from: const Offset(160, 320));
      await tester.tap(find.text('I finished this letter'));
      await tester.pumpAndSettle();

      expect(find.text('Show a grown-up'), findsOneWidget);

      await tester.tap(find.text('Show a grown-up'));
      await tester.pumpAndSettle();

      // Both pages survive, each with the guide it was traced over, so the
      // parent sees every letter rather than only the last one.
      expect(submitted, isNotNull);
      expect(submitted!.map((work) => work.title), ['Letter A', 'Letter B']);
      expect(submitted!.every((work) => work.guide != null), isTrue);
      expect(submitted!.every((work) => work.hasInk), isTrue);
    });
  });
}

const _settle = Duration(milliseconds: 400);

Widget _host(Widget child) {
  return MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(
      body: ChangeNotifierProvider<LevelActivityViewModel>(
        create: (_) => LevelActivityViewModel(
          child is TracingLevelView ? _tracingLevel() : _drawingLevel(),
        ),
        child: child,
      ),
    ),
  );
}

Future<void> _pumpTracing(
  WidgetTester tester, {
  CanvasWorkSubmitted? onFinish,
}) async {
  await tester.pumpWidget(_host(TracingLevelView(
    level: _tracingLevel(),
    onFinish: onFinish ?? (_) {},
  )));
  // Fitting the glyph rasterises it, which needs real async time.
  await tester.runAsync(() => Future<void>.delayed(_settle));
  await tester.pumpAndSettle();
}

Future<void> _scribble(
  WidgetTester tester, {
  Offset from = const Offset(150, 300),
}) async {
  await tester.dragFrom(from, const Offset(60, 40));
  await tester.pumpAndSettle();
}

PlayButton _button(WidgetTester tester, String label) {
  return tester.widget<PlayButton>(
    find.ancestor(
      of: find.text(label),
      matching: find.byType(PlayButton),
    ),
  );
}

LearningLevel _drawingLevel() {
  return const LearningLevel(
    id: 'drawing-test',
    moduleId: 'drawing',
    stage: 4,
    levelNumber: 1,
    title: 'Picture Prompts',
    subtitle: 'Build a picture',
    type: LevelType.drawing,
    passingScore: 60,
    isBundled: true,
    contentItems: [
      ContentItem(
        title: 'Sky',
        prompt: 'Draw the sky at the top of your page.',
        displayText: 'Sky',
        visualLabel: 'Sky drawing prompt',
      ),
      ContentItem(
        title: 'House',
        prompt: 'Draw a house under the sky.',
        displayText: 'House',
        visualLabel: 'House drawing prompt',
      ),
    ],
  );
}

LearningLevel _tracingLevel() {
  return const LearningLevel(
    id: 'tracing-test',
    moduleId: 'english',
    stage: 3,
    levelNumber: 1,
    title: 'Trace A B',
    subtitle: 'Trace',
    type: LevelType.tracing,
    passingScore: 50,
    isBundled: true,
    contentItems: [
      ContentItem(
        title: 'Letter A',
        prompt: 'Trace the letter A.',
        displayText: 'A',
        visualLabel: 'Dotted letter A',
      ),
      ContentItem(
        title: 'Letter B',
        prompt: 'Trace the letter B.',
        displayText: 'B',
        visualLabel: 'Dotted letter B',
      ),
    ],
  );
}
