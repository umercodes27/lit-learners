import 'package:flutter_test/flutter_test.dart';
import 'package:little_learners/core/localization/urdu_letters.dart';
import 'package:little_learners/models/activity_data.dart';
import 'package:little_learners/services/content/activity_pack_loader.dart';

/// An Urdu round has to teach the letter its word actually uses.
///
/// The age-4 pack shipped three wrong pairings: مسجد taught as ج, بارش as ع —
/// a letter that does not occur in بارش at all — and کتاب as ب, which is its
/// last letter rather than its first. The word-builder spelled دل as
/// دال + یے + لام, a word that does not exist. All of it reached the child
/// twice, because the module's quiz is derived from these same rounds.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final packs = <int, String>{
    2: ActivityPackLoader.age2Path,
    3: ActivityPackLoader.age3Path,
    4: ActivityPackLoader.age4Path,
  };

  for (final entry in packs.entries) {
    test('age ${entry.key}: a word is paired with the letter it begins with',
        () async {
      final pack = (await ActivityPackLoader().load(path: entry.value)).pack!;
      final wrong = <String>[];

      for (final module in pack.modules.where((m) => m.key == 'urdu')) {
        for (final level in module.levels) {
          final data = level.data;
          if (data is! IdentifyAndTapData) continue;

          for (final item in data.items) {
            final word = item.promptText;
            if (word == null || !UrduLetters.isUrduScript(word)) continue;

            final answer = item.options
                .where((option) => option.isCorrect)
                .firstOrNull
                ?.label;
            final glyph = UrduLetters.glyphFor(answer ?? '');
            if (glyph == null) continue;

            if (!word.startsWith(glyph)) {
              wrong.add('${level.key}: "$word" is taught as $glyph '
                  '($answer), but it begins with ${word[0]}');
            }
          }
        }
      }

      expect(wrong, isEmpty,
          reason: 'age ${entry.key} teaches the wrong letter:\n'
              '${wrong.join('\n')}');
    });

    test('age ${entry.key}: letter tiles spell the word they build', () async {
      final pack = (await ActivityPackLoader().load(path: entry.value)).pack!;
      final wrong = <String>[];

      for (final module in pack.modules) {
        for (final level in module.levels) {
          final data = level.data;
          if (data is! WordBuilderData) continue;

          for (final item in data.items) {
            final spelled =
                item.tiles.map((tile) => UrduLetters.display(tile)).join();
            if (spelled != item.word) {
              wrong.add('${level.key}: ${item.tiles} spells "$spelled", '
                  'not "${item.word}"');
            }
          }
        }
      }

      expect(wrong, isEmpty,
          reason: 'age ${entry.key} builds a word out of the wrong letters:\n'
              '${wrong.join('\n')}');
    });
  }

  // The level titles promise a range. Age 3's second tracing level said
  // "ج سے ی" and went ج چ ح خ د ی — twenty-four letters short, so the child
  // traced five and the level ended.
  test('age 3 traces the Urdu alphabet it claims to', () async {
    final pack =
        (await ActivityPackLoader().load(path: ActivityPackLoader.age3Path))
            .pack!;
    final letters = <String>[];
    for (final level in pack.moduleByKey('urdu')!.levels) {
      final data = level.data;
      if (data is TracingData) {
        // A pack names letters in Latin; the child sees the script.
        letters.addAll(
            data.items.map((item) => UrduLetters.display(item.glyph)));
      }
    }

    // ا through ی, the letters a child is taught to write.
    expect(letters.length, greaterThanOrEqualTo(35),
        reason: 'only ${letters.length} letters are traced in age 3');
    for (final glyph in ['ا', 'ب', 'د', 'ر', 'س', 'ع', 'ک', 'ل', 'م', 'ی']) {
      expect(letters, contains(glyph), reason: '$glyph is never traced');
    }
  });
}
