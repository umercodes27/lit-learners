import 'package:flutter_test/flutter_test.dart';
import 'package:little_learners/core/localization/urdu_letters.dart';
import 'package:little_learners/models/activity_data.dart';
import 'package:little_learners/services/content/activity_pack_loader.dart';

/// Nothing in an Urdu module reaches a child in Latin script.
///
/// The packs name letters in Latin on purpose — `"letter": "Bay"` is an
/// identifier, and [UrduLetters] turns it into ب at the point of drawing. What
/// must never happen is Latin text going *straight to the screen*: a level
/// titled "Tracing Huroof (Alif to Se)", or a vocabulary round that shows the
/// word "Seb" instead of سیب. The point of the Urdu module is the script.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final packs = <int, String>{
    2: ActivityPackLoader.age2Path,
    3: ActivityPackLoader.age3Path,
    4: ActivityPackLoader.age4Path,
  };

  /// Latin letters. Digits and punctuation are fine — a title may carry a
  /// numeral, and the script itself never uses A-Z.
  final latin = RegExp(r'[A-Za-z]');

  for (final entry in packs.entries) {
    test('age ${entry.key}: the Urdu module is written in Urdu', () async {
      final pack = (await ActivityPackLoader().load(path: entry.value)).pack!;
      final urdu = pack.modules.where((m) => m.key == 'urdu');
      expect(urdu, isNotEmpty, reason: 'age ${entry.key} has no Urdu module');

      final offenders = <String>[];

      for (final module in urdu) {
        if (latin.hasMatch(module.title)) {
          offenders.add('module title: "${module.title}"');
        }

        for (final level in module.levels) {
          if (latin.hasMatch(level.title)) {
            offenders.add('${level.key} title: "${level.title}"');
          }

          // Prompts are read aloud and shown. A letter *name* is allowed to
          // reach an option label, because that is what UrduLetters converts;
          // a prompt is not converted and is shown as written.
          final data = level.data;
          if (data is IdentifyAndTapData) {
            for (final item in data.items) {
              final text = item.promptText;
              if (text != null && latin.hasMatch(text)) {
                offenders.add('${level.key} prompt: "$text"');
              }
            }
          }
          if (data is WordBuilderData) {
            for (final item in data.items) {
              if (latin.hasMatch(item.word)) {
                offenders.add('${level.key} word: "${item.word}"');
              }
            }
          }
        }
      }

      expect(offenders, isEmpty,
          reason: 'age ${entry.key} shows Latin text in the Urdu module:\n'
              '${offenders.join('\n')}');
    });
  }

  // The other half of the rule: a letter name is an identifier and must still
  // resolve to script, or the tiles would show "Alif".
  test('every Urdu letter a pack names resolves to a glyph', () async {
    for (final entry in packs.entries) {
      final pack = (await ActivityPackLoader().load(path: entry.value)).pack!;
      for (final module in pack.modules.where((m) => m.key == 'urdu')) {
        for (final level in module.levels) {
          final data = level.data;
          if (data is! WordBuilderData) continue;
          for (final item in data.items) {
            for (final tile in item.tiles) {
              expect(UrduLetters.glyphFor(tile), isNotNull,
                  reason: 'age ${entry.key} ${level.key} tile "$tile" has no '
                      'Urdu glyph, so it would be drawn in Latin');
            }
          }
        }
      }
    }
  });
}
