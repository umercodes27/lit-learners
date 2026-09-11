import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_learners/services/content/activity_pack_loader.dart';
import 'package:little_learners/services/content/asset_availability.dart';
import 'package:little_learners/services/content/module_quiz_builder.dart';
import 'package:little_learners/widgets/activities/puzzle_widget.dart';

/// The second round of faults reported from the packs, each pinned so it
/// cannot come back.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final packs = <int, String>{
    2: ActivityPackLoader.age2Path,
    3: ActivityPackLoader.age3Path,
    4: ActivityPackLoader.age4Path,
  };

  group('a right answer is heard, not just seen', () {
    // Only two levels in each pack named a reward sound and no pack named one
    // for itself, so `pack.correctSound` was null and every other level in the
    // app answered a correct tap with silence. Reported against Logic, the
    // memory game, counting, categorisation and stories — all the same cause.
    for (final entry in packs.entries) {
      test('age ${entry.key} has a reward and a retry sound', () async {
        final pack = (await ActivityPackLoader().load(path: entry.value)).pack!;
        await AssetAvailability.instance.populate();

        expect(pack.correctSound, isNotNull,
            reason: 'age ${entry.key} names no reward sound, so every level '
                'that does not name its own is silent');
        expect(pack.wrongSound, isNotNull);
        expect(AssetAvailability.instance.has(pack.correctSound), isTrue,
            reason: '${pack.correctSound} is not in the bundle');
        expect(AssetAvailability.instance.has(pack.wrongSound), isTrue,
            reason: '${pack.wrongSound} is not in the bundle');
      });
    }

    test('every sound a pack names is actually in the bundle', () async {
      for (final entry in packs.entries) {
        final pack = (await ActivityPackLoader().load(path: entry.value)).pack!;
        await AssetAvailability.instance.populate();

        final missing = pack.referencedAssets
            .where((path) => path.endsWith('.mp3') || path.endsWith('.wav'))
            .where((path) => path.contains('/sfx/'))
            .where((path) => !AssetAvailability.instance.has(path))
            .toList();

        // try_again_gentle.mp3 was named by four levels and has never existed.
        expect(missing, isEmpty,
            reason: 'age ${entry.key} names sounds that are not there: '
                '$missing');
      }
    });
  });

  group('a quiz slide can be answered', () {
    for (final entry in packs.entries) {
      test('age ${entry.key}: no question has two identical answers',
          () async {
        final pack = (await ActivityPackLoader().load(path: entry.value)).pack!;
        final broken = <String>[];

        for (final module in pack.modules) {
          final quiz = ModuleQuizBuilder.build(module);
          for (final question in quiz.questions) {
            // The more-versus-less round draws the same apple on both plates
            // and differs only in how many, so a slide that ignored the count
            // showed two identical answers and could not be answered at all.
            final seen = <String>{};
            for (final option in question.options) {
              final key = '${option.label}|${option.image}|${option.count}';
              if (!seen.add(key)) {
                broken.add('${module.key}: "${question.prompt}" offers the '
                    'same answer twice ($key)');
              }
            }
          }
        }

        expect(broken, isEmpty, reason: broken.join('\n'));
      });

      test('age ${entry.key}: a counting question never names its answer',
          () async {
        final pack = (await ActivityPackLoader().load(path: entry.value)).pack!;

        for (final module in pack.modules) {
          for (final question in ModuleQuizBuilder.build(module).questions) {
            final answer = question.options[question.correctIndex].label;
            if (answer == null || int.tryParse(answer) == null) continue;
            // "Where is 3?" over three numbers is not a counting question any
            // more, it is a reading test with the answer written on it.
            expect(question.prompt.contains(answer), isFalse,
                reason: '${module.key} gives the answer away: '
                    '"${question.prompt}" -> $answer');
          }
        }
      });
    }

    // "Which one is right?" over a C and a D, with `where_is_C.mp3` sitting
    // unused in the bundle.
    test('the age-2 letter quiz asks which letter, in the recorded voice',
        () async {
      final pack =
          (await ActivityPackLoader().load(path: ActivityPackLoader.age2Path))
              .pack!;
      await AssetAvailability.instance.populate();

      final quiz = ModuleQuizBuilder.build(pack.moduleByKey('english')!);
      expect(quiz.isEmpty, isFalse);

      final asked = quiz.questions.firstWhere(
        (question) => question.prompt.startsWith('Where is'),
        orElse: () => throw StateError(
            'no question names its letter: '
            '${quiz.questions.map((q) => q.prompt).toList()}'),
      );
      final answer = asked.options[asked.correctIndex].label;
      expect(asked.prompt, 'Where is $answer?');

      // And at least one slide plays the clip the pack already recorded.
      final voiced = quiz.questions
          .where((question) => question.audioPrompt != null)
          .where((question) =>
              AssetAvailability.instance.has(question.audioPrompt))
          .toList();
      expect(voiced, isNotEmpty,
          reason: 'the quiz asks silently even though the pack records '
              'where_is_A.mp3 and where_is_C.mp3');
    });

    test('a shape question names the shape', () async {
      final pack =
          (await ActivityPackLoader().load(path: ActivityPackLoader.age3Path))
              .pack!;
      final quiz = ModuleQuizBuilder.build(pack.moduleByKey('logic')!);

      // "What comes next?" over a row of shapes, reported at both age 2 and
      // age 3 as something a toddler cannot act on.
      expect(
        quiz.questions.map((question) => question.prompt),
        contains('Where is the blue square?'),
      );
    });
  });

  // The pieces were cut with Align's fractional factors, which are ignored
  // under tight constraints — and a board slot is a tight 136-square. So all
  // four pieces of the age-3 duck drew the whole duck.
  testWidgets('a puzzle piece shows one piece, not the whole picture',
      (tester) async {
    const columns = 2;
    const rows = 2;

    final offsets = <Offset>{};
    for (var index = 0; index < columns * rows; index++) {
      await tester.pumpWidget(MaterialApp(
        home: Center(
          child: SizedBox(
            width: 120,
            height: 120,
            child: PuzzlePieceView(
              piece: PuzzlePiece.slice(
                fullImage: 'assets/age3/img/duck.png',
                index: index,
                columns: columns,
                rows: rows,
              ),
            ),
          ),
        ),
      ));
      await tester.pump();

      final positioned = tester.widget<Positioned>(find.byType(Positioned));
      offsets.add(Offset(positioned.left!, positioned.top!));

      // The picture is laid out across the whole grid, not squeezed into one
      // cell — that is what makes the window show a quarter of it.
      expect(positioned.width, 120.0 * columns);
      expect(positioned.height, 120.0 * rows);
    }

    expect(offsets, hasLength(columns * rows),
        reason: 'pieces share a window, so they draw the same part of the '
            'picture: $offsets');
  });
}
