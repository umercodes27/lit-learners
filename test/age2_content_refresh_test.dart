import 'package:flutter_test/flutter_test.dart';
import 'package:little_learners/core/localization/urdu_letters.dart';
import 'package:little_learners/models/activity_data.dart';
import 'package:little_learners/services/content/activity_pack_loader.dart';
import 'package:little_learners/services/content/asset_availability.dart';

/// Pins the refreshed age-2 pack: the new item counts, the new letter names,
/// and the big/small round that draws one picture at two sizes.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every level carries the expanded item count', () async {
    final pack = (await ActivityPackLoader().load()).pack!;

    int items(String module, String level) {
      final data = pack.levelByKey(module, level)!.data;
      return switch (data) {
        TwoChoiceTapData d => d.items.length,
        IdentifyAndTapData d => d.items.length,
        OddOneOutData d => d.items.length,
        ListenAndSeeData d => d.items.length,
        _ => 0,
      };
    }

    expect(items('english', 'level_3'), 6, reason: 'sight words');
    expect(items('math', 'level_3'), 6, reason: 'big vs small');
    expect(items('urdu', 'level_2'), 8, reason: 'nuqta groups');
    expect(items('urdu', 'level_3'), 7, reason: 'urdu words');
    expect(items('logic', 'level_3'), 5, reason: 'odd one out');
  });

  test('the code-rendered big/small rounds build two sized options', () async {
    final pack = (await ActivityPackLoader().load()).pack!;
    final data = pack.levelByKey('math', 'level_3')!.data as TwoChoiceTapData;

    // The last four use one image at two sizes rather than two files.
    for (final item in data.items.sublist(2)) {
      expect(item.options.length, 2);

      final big = item.options.firstWhere((o) => o.isCorrect);
      final small = item.options.firstWhere((o) => !o.isCorrect);

      expect(big.image, isNotNull);
      expect(small.image, big.image,
          reason: 'both choices should be the same picture');
      expect(big.scale, greaterThan(small.scale),
          reason: 'the correct answer must be the visibly bigger one');
      // A difference a toddler can actually see across a screen.
      expect(big.scale / small.scale, greaterThanOrEqualTo(1.8));
    }
  });

  test('the first two big/small rounds still use their own artwork', () async {
    final pack = (await ActivityPackLoader().load()).pack!;
    final data = pack.levelByKey('math', 'level_3')!.data as TwoChoiceTapData;

    for (final item in data.items.take(2)) {
      final images = item.options.map((o) => o.image).toSet();
      expect(images.length, 2, reason: 'elephant and ball ship two files');
      expect(item.options.every((o) => o.scale == 1), isTrue,
          reason: 'separate files need no scaling');
    }
  });

  test('the new Urdu letter names all resolve to script', () async {
    for (final name in ['Say', 'Che', 'Khay', 'Seen', 'Kaf', 'Gaaf', 'Jeem', 'Hay']) {
      expect(UrduLetters.glyphFor(name), isNotNull,
          reason: '$name has no glyph, so the card would show its Latin name');
    }
    expect(UrduLetters.glyphFor('Say'), 'ث');
    expect(UrduLetters.glyphFor('Kaf'), 'ک');
  });

  test('the Urdu titles stay in Urdu after the refresh', () async {
    final pack = (await ActivityPackLoader().load()).pack!;
    for (final key in ['level_1', 'level_2', 'level_3']) {
      final title = pack.levelByKey('urdu', key)!.title;
      expect(UrduLetters.isUrduScript(title), isTrue,
          reason: '$key reverted to a Latin title: $title');
    }
  });

  test('nothing the pack references is missing any more', () async {
    final result = await ActivityPackLoader().load();
    expect(result.missingAssets, isEmpty);
  });

  test('every Urdu nuqta round has its own prompt clip', () async {
    final pack = (await ActivityPackLoader().load()).pack!;
    final data = pack.levelByKey('urdu', 'level_2')!.data as IdentifyAndTapData;

    // Eight rounds, eight distinct recordings — a duplicated clip would mean
    // two letters being taught with the same spoken prompt.
    final prompts = data.items.map((item) => item.audioPrompt).toList();
    expect(prompts.length, 8);
    expect(prompts.whereType<String>().length, 8,
        reason: 'a round is missing its prompt');
    expect(prompts.toSet().length, 8, reason: 'a prompt clip is reused');
  });

  test('the age-2 puzzle still uses its shipped piece files', () async {
    // Age 3 added runtime slicing for packs that ship only a full picture.
    // Age 2 ships cut pieces and must keep using them.
    final pack = (await ActivityPackLoader().load()).pack!;
    final data = pack.levelByKey('logic', 'level_2')!.data as PuzzleData;

    expect(data.pieceCount, 2);
    expect(data.items.single.pieces.length, 2);
    expect(data.needsRuntimeSlicing, isFalse);
  });

  test('every image the pack references is bundled', () async {
    final result = await ActivityPackLoader().load();
    await AssetAvailability.instance.populate();

    final missingImages = result.pack!.referencedAssets
        .where((path) => path.endsWith('.png'))
        .where((path) => !AssetAvailability.instance.has(path))
        .toList();

    expect(missingImages, isEmpty);
  });
}
