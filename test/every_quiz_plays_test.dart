import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_learners/services/content/activity_pack_loader.dart';
import 'package:little_learners/services/content/module_quiz_builder.dart';
import 'package:little_learners/views/child_dashboard/module_quiz_page.dart';
import 'package:little_learners/widgets/play/play.dart';

/// Every quiz a pack can build is played from first slide to result.
///
/// Written while hunting a crash report: it is the cheapest way to find out
/// whether a generated quiz throws, without driving the real app through an
/// account, a readiness test and a profile first. Lowering the question
/// minimum turned four dead trophies live, and these are the runs that proves
/// each of them survives being answered.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final path in [
    ActivityPackLoader.age2Path,
    ActivityPackLoader.age3Path,
    ActivityPackLoader.age4Path,
  ]) {
    testWidgets('every quiz plays through: $path', (tester) async {
      final pack = (await ActivityPackLoader().load(path: path)).pack!;
      for (final m in pack.modules) {
        final quiz = ModuleQuizBuilder.build(m);
        if (quiz.isEmpty) continue;

        await tester.pumpWidget(MaterialApp(
          home: ModuleQuizPage(quiz: quiz, accent: PlayColors.grape),
        ));
        await tester.pump(const Duration(milliseconds: 600));

        for (var q = 0; q < quiz.length; q++) {
          // Answer whatever the first option is, then advance.
          final tiles = find.byType(Squishy);
          expect(tiles, findsWidgets,
              reason: 'age ${pack.age} ${m.key} q$q drew no answers');
          await tester.tap(tiles.first, warnIfMissed: false);
          await tester.pump(const Duration(milliseconds: 600));

          final next = find.textContaining(RegExp('Next|See my result'));
          if (next.evaluate().isNotEmpty) {
            await tester.tap(next.first, warnIfMissed: false);
            await tester.pump(const Duration(milliseconds: 600));
          }
        }
        await tester.pump(const Duration(milliseconds: 1200));

        final err = tester.takeException();
        expect(err, isNull,
            reason: 'age ${pack.age} ${m.key} quiz threw: $err');
      }
    });
  }
}
