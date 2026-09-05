import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_learners/core/routing/app_router.dart';
import 'package:little_learners/core/theme/app_theme.dart';
import 'package:little_learners/data/seed_content.dart';
import 'package:little_learners/models/canvas_work.dart';
import 'package:little_learners/models/content_item.dart';
import 'package:little_learners/models/drawing_stroke.dart';
import 'package:little_learners/models/learning_level.dart';
import 'package:little_learners/models/parent_mark.dart';
import 'package:little_learners/viewmodels/active_child_session.dart';
import 'package:little_learners/views/marking/parent_marking_page.dart';
import 'package:little_learners/widgets/play/play.dart';
import 'package:provider/provider.dart';

void main() {
  group('ParentMark', () {
    // The whole grading scale rests on this: whatever level a parent is
    // marking, exactly one of the four choices sends the child back.
    test('only "needs practice" fails, on every canvas level in the app', () {
      final canvasLevels = seedLevels.where(
        (level) =>
            level.type == LevelType.drawing || level.type == LevelType.tracing,
      );

      expect(canvasLevels, isNotEmpty);
      for (final level in canvasLevels) {
        final failing = ParentMark.values
            .where((mark) => !mark.passes(level.passingScore))
            .toList();

        expect(
          failing,
          [ParentMark.needsPractice],
          reason: '${level.id} passes at ${level.passingScore}%',
        );
      }
    });

    test('each grade is worth one more star than the last', () {
      expect(
        ParentMark.values.map((mark) => mark.stars),
        [0, 1, 2, 3],
      );
    });

    // The marking screen prints a star count beside each grade, so it has to
    // agree with what the progress repository actually awards.
    test('the promised stars match the progress rules', () {
      const passingScore = 70; // the strictest canvas level in the app

      for (final mark in ParentMark.values) {
        final stars = mark.score < passingScore
            ? 0
            : mark.score >= 90
                ? 3
                : mark.score >= 75
                    ? 2
                    : 1;

        expect(mark.stars, stars, reason: mark.label);
      }
    });
  });

  group('ParentMarkingPage', () {
    testWidgets('shows every page the child finished', (tester) async {
      await tester.pumpWidget(_host(work: [_work('Letter A'), _work('B')]));
      await _open(tester);

      expect(find.text('Letter A'), findsOneWidget);
      expect(find.text('B'), findsOneWidget);
    });

    testWidgets('offers all four grades', (tester) async {
      await tester.pumpWidget(_host(work: [_work('Letter A')]));
      await _open(tester);

      for (final mark in ParentMark.values) {
        await _scrollTo(tester, find.text(mark.label));
        expect(find.text(mark.label), findsOneWidget);
      }
    });

    testWidgets('no mark can be saved until one is chosen', (tester) async {
      await tester.pumpWidget(_host(work: [_work('Letter A')]));
      await _open(tester);
      await _scrollTo(tester, find.text('Save this mark'));

      expect(_saveButton(tester).onPressed, isNull);

      await tester.tap(find.text(ParentMark.greatWork.label));
      await tester.pumpAndSettle();

      expect(_saveButton(tester).onPressed, isNotNull);
    });

    testWidgets('the chosen grade goes back to the level that asked for it',
        (tester) async {
      ParentMark? returned;
      await tester.pumpWidget(_host(
        work: [_work('Letter A')],
        onPopped: (mark) => returned = mark,
      ));
      await _open(tester);
      await _scrollTo(tester, find.text('Save this mark'));

      await tester.tap(find.text(ParentMark.perfect.label));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save this mark'));
      await tester.pumpAndSettle();

      expect(returned, ParentMark.perfect);
    });

    testWidgets('the passing rule for this level is spelled out',
        (tester) async {
      await tester.pumpWidget(_host(work: [_work('Letter A')]));
      await _open(tester);
      await _scrollTo(tester, find.textContaining('below 60%'));

      expect(find.textContaining('below 60%'), findsOneWidget);
    });
  });
}

/// Hosts the page on a route that can be popped, so the returned grade is
/// observable the same way the level player observes it.
Widget _host({
  required List<CanvasWork> work,
  void Function(ParentMark? mark)? onPopped,
}) {
  final level = _level();

  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => ActiveChildSession()),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      home: Builder(
        builder: (context) {
          return Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  final mark = await Navigator.of(context).push<ParentMark>(
                    MaterialPageRoute<ParentMark>(
                      builder: (_) => ParentMarkingPage(
                        args: ParentMarkingArgs(level: level, work: work),
                      ),
                    ),
                  );
                  onPopped?.call(mark);
                },
                child: const Text('open'),
              ),
            ),
          );
        },
      ),
    ),
  );
}

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

/// The grades sit below the fold on the 600px test surface, so anything past
/// the first one has to be scrolled into view before it is built.
Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    120,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

PlayButton _saveButton(WidgetTester tester) {
  return tester.widget<PlayButton>(
    find.ancestor(
      of: find.text('Save this mark'),
      matching: find.byType(PlayButton),
    ),
  );
}

CanvasWork _work(String title) {
  final stroke = DrawingStroke(
    tool: DrawingTool.pen,
    color: const Color(0xFF000000),
    width: 8,
  )
    ..add(const Offset(20, 20))
    ..add(const Offset(80, 90));

  return CanvasWork(
    title: title,
    prompt: 'Trace it.',
    canvasSize: const Size(200, 240),
    strokes: [stroke],
  );
}

LearningLevel _level() {
  return const LearningLevel(
    id: 'tracing-test',
    moduleId: 'tracing',
    stage: 3,
    levelNumber: 1,
    title: 'Trace A B',
    subtitle: 'Trace',
    type: LevelType.tracing,
    passingScore: 60,
    isBundled: true,
    contentItems: [
      ContentItem(
        title: 'Letter A',
        prompt: 'Trace the letter A.',
        displayText: 'A',
        visualLabel: 'Dotted letter A',
      ),
    ],
  );
}
