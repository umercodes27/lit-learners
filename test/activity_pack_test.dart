import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_learners/models/activity_data.dart';
import 'package:little_learners/models/activity_option.dart';
import 'package:little_learners/models/activity_pack.dart';
import 'package:little_learners/services/content/activity_pack_loader.dart';
import 'package:little_learners/services/content/asset_availability.dart';

/// Serves a pack from memory so the tests do not depend on the real bundle.
class _FakeBundle extends CachingAssetBundle {
  _FakeBundle(this.files);

  final Map<String, String> files;

  @override
  Future<ByteData> load(String key) async {
    final value = files[key];
    if (value == null) throw Exception('missing asset $key');
    final bytes = utf8.encode(value);
    return ByteData.view(Uint8List.fromList(bytes).buffer);
  }
}

const _packJson = '''
{
  "age": 2,
  "phase": "Test Phase",
  "modules": {
    "english": {
      "title": "English",
      "level_2": {
        "component": "two_choice_tap",
        "title": "Second",
        "items": [
          {
            "audio_prompt": "assets/p/there.mp3",
            "options": [
              { "label": "A", "audio": "assets/p/gone.mp3", "correct": true },
              { "label": "B", "correct": false }
            ]
          }
        ]
      },
      "level_1": {
        "component": "identify_and_tap",
        "title": "First",
        "items": [
          {
            "prompt_image": "assets/p/cat.png",
            "options": [ { "label": "C", "correct": true } ]
          }
        ]
      }
    },
    "urdu": {
      "title": "Urdu",
      "rtl": true,
      "level_1": {
        "component": "puzzle",
        "title": "Pieces",
        "piece_count": 4,
        "items": [
          { "full_image": "assets/p/whole.png", "pieces": ["assets/p/a.png", "assets/p/b.png"] }
        ]
      }
    },
    "math": {
      "level_1": {
        "component": "tap_to_count",
        "title": "Counting",
        "count_audio_folder": "assets/p/num",
        "items": [ { "object_image": "assets/p/apple.png", "target_count": 3 } ]
      },
      "level_2": {
        "component": "brand_new_thing",
        "title": "Future"
      }
    },
    "storytelling": {
      "level_1": {
        "component": "story_interactive",
        "title": "Story",
        "audio_narration": "assets/p/tale.mp3",
        "illustration_sequence": [
          { "image": "assets/p/s1.png", "start_ms": 0 },
          "assets/p/s2.png"
        ],
        "choice_point": {
          "at_ms": 900,
          "prompt_text": "Which?",
          "options": [ { "image": "assets/p/soap.png", "correct": true } ]
        }
      }
    }
  },
  "feedback": {
    "correct_sound": "assets/p/yay.mp3",
    "wrong_sound": "assets/p/aw.mp3"
  }
}
''';

void main() {
  group('ActivityPack parsing', () {
    late ActivityPack pack;

    setUp(() {
      pack = ActivityPack.fromJson(
        jsonDecode(_packJson) as Map<String, dynamic>,
      );
    });

    test('reads the pack header and every module', () {
      expect(pack.age, 2);
      expect(pack.phase, 'Test Phase');
      expect(
        pack.modules.map((module) => module.key),
        containsAll(<String>['english', 'urdu', 'math', 'storytelling']),
      );
    });

    test('orders levels numerically rather than by map order', () {
      final english = pack.moduleByKey('english')!;
      expect(english.levels.map((level) => level.key), ['level_1', 'level_2']);
    });

    test('falls back to a title-cased key when a module has no title', () {
      expect(pack.moduleByKey('math')!.title, 'Math');
    });

    test('maps each component to its own data class', () {
      expect(
        pack.levelByKey('english', 'level_2')!.data,
        isA<TwoChoiceTapData>(),
      );
      expect(
        pack.levelByKey('english', 'level_1')!.data,
        isA<IdentifyAndTapData>(),
      );
      expect(pack.levelByKey('urdu', 'level_1')!.data, isA<PuzzleData>());
      expect(pack.levelByKey('math', 'level_1')!.data, isA<TapToCountData>());
      expect(
        pack.levelByKey('storytelling', 'level_1')!.data,
        isA<StoryInteractiveData>(),
      );
    });

    test('an unknown component parses as unsupported instead of throwing', () {
      final data = pack.levelByKey('math', 'level_2')!.data;
      expect(data, isA<UnsupportedActivityData>());
      expect((data as UnsupportedActivityData).rawComponent, 'brand_new_thing');
      expect(data.isEmpty, isTrue);
    });

    test('a module-level rtl flag reaches its levels', () {
      expect(pack.levelByKey('urdu', 'level_1')!.data.isRtl, isTrue);
      expect(pack.levelByKey('english', 'level_1')!.data.isRtl, isFalse);
    });

    test('puzzle piece count follows the pieces actually listed', () {
      // The pack claims four but ships two; the widget can only draw two.
      final puzzle = pack.levelByKey('urdu', 'level_1')!.data as PuzzleData;
      expect(puzzle.pieceCount, 2);
    });

    test('tap-to-count derives the number sounds it will need', () {
      final counting = pack.levelByKey('math', 'level_1')!.data as TapToCountData;
      expect(counting.countAudioAssets, [
        'assets/p/num/1.mp3',
        'assets/p/num/2.mp3',
        'assets/p/num/3.mp3',
      ]);
    });

    test('a story illustration may be a bare path or a timed object', () {
      final story =
          pack.levelByKey('storytelling', 'level_1')!.data as StoryInteractiveData;
      expect(story.illustrations.map((frame) => frame.image),
          ['assets/p/s1.png', 'assets/p/s2.png']);
      expect(story.illustrations.first.startMs, 0);
      expect(story.choicePoint!.atMs, 900);
    });

    test('referencedAssets gathers paths from every corner of the pack', () {
      expect(
        pack.referencedAssets,
        containsAll(<String>[
          'assets/p/there.mp3', // prompt
          'assets/p/gone.mp3', // option audio
          'assets/p/cat.png', // prompt image
          'assets/p/a.png', // puzzle piece
          'assets/p/num/3.mp3', // derived counting audio
          'assets/p/soap.png', // story choice option
          'assets/p/yay.mp3', // pack feedback
        ]),
      );
    });
  });

  group('authored age-2 item shapes', () {
    ActivityData parse(String component, String itemsJson) {
      final pack = ActivityPack.fromJson(jsonDecode('''
        { "modules": { "m": { "level_1": {
          "component": "$component", "title": "T", "items": $itemsJson
        } } } }
      ''') as Map<String, dynamic>);
      return pack.levelByKey('m', 'level_1')!.data;
    }

    test('two-choice-tap reads target / distractor letters', () {
      final data = parse('two-choice-tap',
              '[{"target":"A","distractor":"B","target_audio":"assets/a.mp3"}]')
          as TwoChoiceTapData;
      final options = data.items.single.options;
      expect(options.map((o) => o.label), containsAll(<String>['A', 'B']));
      final correct = options.firstWhere((o) => o.isCorrect);
      expect(correct.label, 'A');
      expect(correct.audio, 'assets/a.mp3');
    });

    test('two-choice-tap reads big / small images, big being correct', () {
      final data = parse('two-choice-tap',
              '[{"object":"ball","big_image":"assets/big.png","small_image":"assets/small.png"}]')
          as TwoChoiceTapData;
      final correct =
          data.items.single.options.firstWhere((option) => option.isCorrect);
      expect(correct.image, 'assets/big.png');
    });

    test('the correct answer alternates sides down a level', () {
      // A child who taps the same box every round must not be able to score.
      final data = parse('two-choice-tap', '''
        [
          {"target":"A","distractor":"B"},
          {"target":"C","distractor":"D"},
          {"target":"E","distractor":"F"},
          {"target":"M","distractor":"N"},
          {"target":"S","distractor":"T"}
        ]
      ''') as TwoChoiceTapData;

      final sides =
          data.items.map((item) => item.options.first.isCorrect).toList();
      expect(sides.toSet(), {true, false}, reason: 'both sides must be used');
      for (var i = 1; i < sides.length; i++) {
        expect(sides[i], isNot(sides[i - 1]),
            reason: 'round $i should swap sides');
      }
    });

    test('every two-option round in the shipped pack alternates', () {
      // The guarantee has to hold for the short levels too — two-item levels
      // are where a hash-based shuffle would most easily land one-sided.
      for (final component in ['two-choice-tap', 'identify-and-tap']) {
        final data = parse(component, '''
          [
            {"target":"A","distractor":"B","correct_letter":"A","wrong_letter":"B"},
            {"target":"C","distractor":"D","correct_letter":"C","wrong_letter":"D"}
          ]
        ''');
        final options = switch (data) {
          TwoChoiceTapData d => d.items.map((i) => i.options).toList(),
          IdentifyAndTapData d => d.items.map((i) => i.options).toList(),
          _ => <List<ActivityOption>>[],
        };
        final sides = options.map((o) => o.first.isCorrect).toSet();
        expect(sides, {true, false}, reason: '$component stayed one-sided');
      }
    });

    test('identify-and-tap reads correct_letter / wrong_letter and image', () {
      final data = parse('identify-and-tap',
              '[{"image":"assets/duck.png","correct_letter":"D","wrong_letter":"M"}]')
          as IdentifyAndTapData;
      final item = data.items.single;
      expect(item.promptImage, 'assets/duck.png');
      expect(item.options.firstWhere((o) => o.isCorrect).label, 'D');
      expect(item.options.length, 2);
    });

    test('identify-and-tap reads basket_options with the colour as answer', () {
      final data = parse('identify-and-tap',
              '[{"shape":"circle","color":"red","basket_options":["red","blue"],"image":"assets/c.png"}]')
          as IdentifyAndTapData;
      final item = data.items.single;
      // The pack names only the shape. On its own "circle" is not a question,
      // and it was being shown to the child as though it were; the choices are
      // colours, so the colour is what the round asks about.
      expect(item.promptText, 'What colour is the circle?');
      expect(item.options.map((o) => o.label), ['red', 'blue']);
      expect(item.options.firstWhere((o) => o.isCorrect).label, 'red');
    });

    test('tap-to-count reads count and a per-item audio list', () {
      final data = parse('tap-to-count',
              '[{"object_image":"assets/star.png","count":3,"audio_numbers":["assets/1.mp3","assets/2.mp3","assets/3.mp3"]}]')
          as TapToCountData;
      final item = data.items.single;
      expect(item.targetCount, 3);
      expect(item.audioForCount(2), 'assets/2.mp3');
      // Beyond the list and with no folder to fall back on.
      expect(item.audioForCount(4), isNull);
      expect(item.audioForCount(4, folder: 'assets/num'), 'assets/num/4.mp3');
    });

    test('shadow-match reads correct_shadow / wrong_shadow', () {
      final data = parse('shadow-match',
              '[{"object_image":"assets/cat.png","correct_shadow":"assets/sc.png","wrong_shadow":"assets/sd.png"}]')
          as ShadowMatchData;
      final item = data.items.single;
      expect(item.objectImage, 'assets/cat.png');
      expect(item.options.firstWhere((o) => o.isCorrect).image, 'assets/sc.png');
    });

    test('puzzle reads numbered piece_1 / piece_2 keys in order', () {
      final data = parse('puzzle',
              '[{"full_image":"assets/apple.png","piece_1":"assets/h1.png","piece_2":"assets/h2.png"}]')
          as PuzzleData;
      expect(data.items.single.pieces, ['assets/h1.png', 'assets/h2.png']);
      expect(data.pieceCount, 2);
    });

    test('odd-one-out reads an items array plus odd_item_index', () {
      final data = parse('odd-one-out',
              '[{"items":["assets/a.png","assets/b.png","assets/c.png"],"odd_item_index":2}]')
          as OddOneOutData;
      final options = data.items.single.options;
      expect(options.length, 3);
      expect(options[2].isCorrect, isTrue);
      expect(options.where((o) => o.isCorrect).length, 1);
    });

    test('listen-and-see reads word, image and audio', () {
      final data = parse('listen-and-see',
              '[{"word":"CAT","image":"assets/cat.png","audio":"assets/word.mp3"}]')
          as ListenAndSeeData;
      final item = data.items.single;
      expect(item.word, 'CAT');
      expect(item.audio, 'assets/word.mp3');
      expect(data.isEmpty, isFalse);
    });

    test('a story choice point may name only the correct image', () {
      final pack = ActivityPack.fromJson(jsonDecode('''
        { "modules": { "s": { "habit_stories": {
          "component": "story-interactive",
          "title": "Washing Hands",
          "audio_narration": "assets/n.mp3",
          "illustration_sequence": ["assets/w1.png", "assets/w2.png"],
          "choice_point": { "prompt": "Tap the soap!", "correct_image": "assets/soap.png" }
        } } } }
      ''') as Map<String, dynamic>);
      final level = pack.levelByKey('s', 'habit_stories')!;
      final data = level.data as StoryInteractiveData;

      expect(level.displayLabel, 'Habit Stories');
      expect(data.illustrations.length, 2);
      expect(data.choicePoint!.promptText, 'Tap the soap!');
      expect(data.choicePoint!.options.single.image, 'assets/soap.png');
      expect(data.choicePoint!.options.single.isCorrect, isTrue);
    });

    test('a level may carry its own feedback sounds', () {
      final pack = ActivityPack.fromJson(jsonDecode('''
        { "modules": { "m": { "level_1": {
          "component": "two-choice-tap", "title": "T",
          "items": [{"target":"A","distractor":"B"}],
          "feedback": { "correct_sound": "assets/yay.mp3", "wrong_sound": "assets/aw.mp3" }
        } } } }
      ''') as Map<String, dynamic>);
      final data = pack.levelByKey('m', 'level_1')!.data;
      expect(data.correctSound, 'assets/yay.mp3');
      expect(data.wrongSound, 'assets/aw.mp3');
      expect(pack.referencedAssets, contains('assets/yay.mp3'));
    });

    test('a non-level key in a module is skipped, not parsed as a level', () {
      final pack = ActivityPack.fromJson(jsonDecode('''
        { "modules": { "logic": {
          "note": "Included per client spec",
          "level_1": { "component": "puzzle", "title": "P",
                       "items": [{"piece_1":"assets/a.png","piece_2":"assets/b.png"}] }
        } } }
      ''') as Map<String, dynamic>);
      expect(pack.moduleByKey('logic')!.levels.length, 1);
    });
  });

  group('ActivityPackLoader asset audit', () {
    test('reports referenced assets the bundle does not have', () async {
      final bundle = _FakeBundle({'pack.json': _packJson});
      // Everything the pack asks for except the two below.
      AssetAvailability.instance.debugSeed({
        'assets/p/there.mp3',
        'assets/p/cat.png',
        'assets/p/whole.png',
        'assets/p/a.png',
        'assets/p/b.png',
        'assets/p/apple.png',
        'assets/p/num/1.mp3',
        'assets/p/num/2.mp3',
        'assets/p/num/3.mp3',
        'assets/p/tale.mp3',
        'assets/p/s1.png',
        'assets/p/s2.png',
        'assets/p/soap.png',
        'assets/p/yay.mp3',
        'assets/p/aw.mp3',
      });

      final result =
          await ActivityPackLoader(bundle: bundle).load(path: 'pack.json');

      expect(result.hasPack, isTrue);
      expect(result.error, isNull);
      expect(result.missingAssets, ['assets/p/gone.mp3']);
    });

    test('rebases pack-relative asset paths into the pack folder', () async {
      // Authored the way the age-3 file is, against a bare `assets/` root.
      const authored = '''
      {
        "age": 2,
        "modules": {
          "english": {
            "level_1": {
              "component": "identify_and_tap",
              "title": "Rebase",
              "items": [
                {
                  "audio_prompt": "assets/audio/en/here.mp3",
                  "prompt_image": "assets/img/cat.png",
                  "options": [ { "image": "assets/img/nope.png", "correct": true } ]
                }
              ]
            }
          }
        }
      }
      ''';

      final bundle = _FakeBundle({'assets/age2/pack.json': authored});
      // The media actually lives one level down, under the pack's folder.
      AssetAvailability.instance.debugSeed({
        'assets/age2/audio/en/here.mp3',
        'assets/age2/img/cat.png',
      });

      final result = await ActivityPackLoader(bundle: bundle)
          .load(path: 'assets/age2/pack.json');

      final data =
          result.pack!.levelByKey('english', 'level_1')!.data as IdentifyAndTapData;
      expect(data.items.single.audioPrompt, 'assets/age2/audio/en/here.mp3');
      expect(data.items.single.promptImage, 'assets/age2/img/cat.png');
      // Nothing to rebase onto, so it stays put and is reported as missing.
      expect(data.items.single.options.single.image, 'assets/img/nope.png');
      expect(result.missingAssets, ['assets/img/nope.png']);
    });

    test('repairs a right-file-wrong-folder path and reports the repair',
        () async {
      const authored = '''
      {
        "modules": { "urdu": { "level_1": {
          "component": "identify-and-tap", "title": "Nuqta",
          "items": [
            { "image": "assets/img/ur/bay_shape.png", "correct_letter": "Bay", "wrong_letter": "Pay" },
            { "image": "assets/img/nowhere.png", "correct_letter": "A", "wrong_letter": "B" }
          ]
        } } }
      }
      ''';
      final bundle = _FakeBundle({'assets/age2/pack.json': authored});
      // The real file sits at img/, not img/ur/.
      AssetAvailability.instance.debugSeed({'assets/age2/img/bay_shape.png'});

      final result = await ActivityPackLoader(bundle: bundle)
          .load(path: 'assets/age2/pack.json');

      expect(result.repairedAssets, {
        'assets/img/ur/bay_shape.png': 'assets/age2/img/bay_shape.png',
      });
      // A name that matches nothing is still reported as missing.
      expect(result.missingAssets, ['assets/img/nowhere.png']);

      final data =
          result.pack!.levelByKey('urdu', 'level_1')!.data as IdentifyAndTapData;
      expect(data.items.first.promptImage, 'assets/age2/img/bay_shape.png');
    });

    test('an ambiguous file name is left alone rather than guessed', () async {
      const authored = '''
      {
        "modules": { "m": { "level_1": {
          "component": "identify-and-tap", "title": "T",
          "items": [{ "image": "assets/img/cat.png", "correct_letter": "C", "wrong_letter": "D" }]
        } } }
      }
      ''';
      final bundle = _FakeBundle({'assets/age2/pack.json': authored});
      // Two plausible homes for the same name — a repair would be a coin flip.
      AssetAvailability.instance.debugSeed({
        'assets/age2/img/a/cat.png',
        'assets/age2/img/b/cat.png',
      });

      final result = await ActivityPackLoader(bundle: bundle)
          .load(path: 'assets/age2/pack.json');

      expect(result.repairedAssets, isEmpty);
      expect(result.missingAssets, ['assets/img/cat.png']);
    });

    test('a broken pack file is reported, not thrown', () async {
      final bundle = _FakeBundle({'pack.json': 'this is not json'});
      final result =
          await ActivityPackLoader(bundle: bundle).load(path: 'pack.json');

      expect(result.hasPack, isFalse);
      expect(result.error, contains('pack.json'));
    });
  });
}
