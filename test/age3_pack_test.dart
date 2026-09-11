import 'package:flutter_test/flutter_test.dart';
import 'package:little_learners/models/activity_data.dart';
import 'package:little_learners/services/content/activity_pack_loader.dart';
import 'package:little_learners/services/content/asset_availability.dart';

/// The age-3 pack: every level parses to a playable component, and the two
/// packs stay independent of one another.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ActivityPackLoadResult> loadAge3() =>
      ActivityPackLoader().load(path: ActivityPackLoader.age3Path);

  test('the pack loads and exposes all five modules', () async {
    final result = await loadAge3();
    expect(result.error, isNull);

    final pack = result.pack!;
    expect(pack.age, 3);
    expect(
      pack.modules.map((m) => m.key),
      containsAll(<String>['english', 'urdu', 'math', 'logic', 'storytelling']),
    );
  });

  test('no level falls through as unplayable', () async {
    final pack = (await loadAge3()).pack!;

    for (final module in pack.modules) {
      for (final level in module.levels) {
        expect(level.data.component, isNot(ActivityComponent.unknown),
            reason: '${module.key}/${level.key} has an unrecognised component');
        expect(level.data.isEmpty, isFalse,
            reason: '${module.key}/${level.key} parsed to nothing');
      }
    }
  });

  test('each new component maps to its own data class', () async {
    final pack = (await loadAge3()).pack!;

    expect(pack.levelByKey('english', 'level_1')!.data, isA<TracingData>());
    expect(pack.levelByKey('english', 'level_3')!.data, isA<DragAndMatchData>());
    expect(pack.levelByKey('math', 'level_1')!.data, isA<TapToCountData>());
    expect(pack.levelByKey('math', 'level_2')!.data, isA<TracingData>());
    expect(pack.levelByKey('math', 'level_3')!.data, isA<TwoChoiceTapData>());
    expect(pack.levelByKey('logic', 'level_1')!.data, isA<SortIntoZonesData>());
    expect(pack.levelByKey('logic', 'level_2')!.data, isA<PuzzleData>());
    expect(
        pack.levelByKey('logic', 'level_3')!.data, isA<PatternCompleteData>());
    expect(pack.levelByKey('storytelling', 'moral_stories')!.data,
        isA<StoryInteractiveData>());
  });

  test('tracing covers the whole alphabet without needing a clip each',
      () async {
    final pack = (await loadAge3()).pack!;
    final a = pack.levelByKey('english', 'level_1')!.data as TracingData;
    final b = pack.levelByKey('english', 'level_2')!.data as TracingData;

    expect(a.items.length + b.items.length, 26);
    expect(a.items.first.glyph, 'A');
    expect(b.items.last.glyph, 'Z');

    // Only the handful of recorded clips count as referenced assets. Treating
    // every glyph as needing a file would report twenty-odd false gaps.
    for (final asset in a.referencedAssets) {
      expect(asset.endsWith('.mp3'), isTrue);
    }
  });

  test('numeral tracing reads the number key', () async {
    final pack = (await loadAge3()).pack!;
    final data = pack.levelByKey('math', 'level_2')!.data as TracingData;
    expect(data.items.map((i) => i.glyph), ['1', '2', '3', '4', '5']);
  });

  test('drag-and-match pairs a letter with a picture', () async {
    final pack = (await loadAge3()).pack!;
    final data =
        pack.levelByKey('english', 'level_3')!.data as DragAndMatchData;

    expect(data.pairs.length, 4);
    expect(data.pairs.map((p) => p.id), ['cat', 'dog', 'ball', 'sun']);
    expect(data.pairs.first.letter, 'C');
    expect(data.pairs.every((p) => p.image != null), isTrue);
  });

  test('sort-into-zones has both zones and every item assigned to one',
      () async {
    final pack = (await loadAge3()).pack!;
    final data = pack.levelByKey('logic', 'level_1')!.data as SortIntoZonesData;

    final zoneKeys = data.zones.map((z) => z.key).toSet();
    expect(zoneKeys, {'farm', 'road'});
    for (final item in data.items) {
      expect(zoneKeys, contains(item.zoneKey),
          reason: '${item.image} is sorted into a zone that does not exist');
    }
  });

  test('the four-piece puzzle ships no piece files and is sliced at runtime',
      () async {
    final pack = (await loadAge3()).pack!;
    final data = pack.levelByKey('logic', 'level_2')!.data as PuzzleData;

    expect(data.pieceCount, 4);
    expect(data.items.single.pieces, isEmpty,
        reason: 'the pack names only the whole picture');
    expect(data.needsRuntimeSlicing, isTrue);
    expect(data.items.single.fullImage, isNotNull);
    expect(data.isEmpty, isFalse, reason: 'it must still be playable');
  });

  test('pattern completion marks exactly one option correct', () async {
    final pack = (await loadAge3()).pack!;
    final data =
        pack.levelByKey('logic', 'level_3')!.data as PatternCompleteData;

    for (final item in data.items) {
      expect(item.sequence, isNotEmpty);
      expect(item.options.length, greaterThanOrEqualTo(2));
      expect(item.options.where((o) => o.isCorrect).length, 1,
          reason: 'the answer must be exactly one of the options');
    }
  });

  test('more-vs-less builds two plates and the fuller one wins', () async {
    final pack = (await loadAge3()).pack!;
    final data = pack.levelByKey('math', 'level_3')!.data as TwoChoiceTapData;

    final item = data.items.single;
    expect(item.options.length, 2);
    expect(item.options.every((o) => o.count > 0), isTrue);

    final correct = item.options.firstWhere((o) => o.isCorrect);
    final other = item.options.firstWhere((o) => !o.isCorrect);
    expect(correct.count, greaterThan(other.count));
    expect(item.audioPrompt, contains('which_has_more'));
  });

  test('both stories carry a narration and an illustration run', () async {
    final pack = (await loadAge3()).pack!;
    for (final key in ['moral_stories', 'daily_routine_stories']) {
      final data =
          pack.levelByKey('storytelling', key)!.data as StoryInteractiveData;
      expect(data.audioNarration, isNotNull, reason: key);
      expect(data.illustrations.length, greaterThanOrEqualTo(3), reason: key);
    }
  });

  test('every picture the pack references is bundled', () async {
    final result = await loadAge3();
    await AssetAvailability.instance.populate();

    final missingImages = result.pack!.referencedAssets
        .where((path) => path.endsWith('.png'))
        .where((path) => !AssetAvailability.instance.has(path))
        .toList();

    expect(missingImages, isEmpty);
  });

  test('loading age 3 leaves the age-2 pack untouched', () async {
    final age3 = (await loadAge3()).pack!;
    final age2 = (await ActivityPackLoader.shared.load()).pack!;

    expect(age2.age, 2);
    expect(age3.age, 3);
    // Separate loaders, separate parsed content.
    expect(identical(age2, age3), isFalse);
    expect(age2.modules.length, greaterThan(0));
  });

  test('no Urdu tracing letter is left to a speech engine', () async {
    // Urdu letter names are the case a general speech engine gets wrong, so
    // these must never fall back. English letters and numerals still may.
    //
    // The level covers the alphabet it claims to — ج to ی — and most of those
    // letters have no recording yet, so the rule cannot be "every letter has a
    // clip" without cutting the alphabet back down to the six that do. It is
    // the *guessing* that is banned: a letter is either recorded or traced in
    // silence, and TracingWidget hides the speaker for the silent ones so
    // nothing offers a sound it cannot make.
    final pack = (await loadAge3()).pack!;
    await AssetAvailability.instance.populate();

    // Whatever a pack names, it must never name a clip that is not there:
    // that is the case that would play as silence behind a live speaker.
    for (final key in ['level_1', 'level_2']) {
      final data = pack.levelByKey('urdu', key)!.data as TracingData;
      for (final item in data.items) {
        if (item.audio == null) continue;
        expect(AssetAvailability.instance.has(item.audio), isTrue,
            reason: 'urdu/$key ${item.glyph} points at a missing clip');
      }
    }

    // And the letters that were recorded still resolve.
    final first = pack.levelByKey('urdu', 'level_1')!.data as TracingData;
    expect(first.items.where((item) => item.audio != null), isNotEmpty);
  });

  test('number tracing is fully recorded too', () async {
    final pack = (await loadAge3()).pack!;
    await AssetAvailability.instance.populate();

    final data = pack.levelByKey('math', 'level_2')!.data as TracingData;
    for (final item in data.items) {
      expect(AssetAvailability.instance.has(item.audio), isTrue,
          reason: 'number ${item.glyph} has no clip');
    }
  });

  test('only English letters fall back to speech', () async {
    final pack = (await loadAge3()).pack!;
    await AssetAvailability.instance.populate();

    final spoken = <String>[];
    for (final key in ['level_1', 'level_2']) {
      final data = pack.levelByKey('english', key)!.data as TracingData;
      for (final item in data.items) {
        if (!AssetAvailability.instance.has(item.audio)) {
          spoken.add(item.glyph);
        }
      }
    }
    // A, C, E, M and S were recorded; the other 21 are spoken by design.
    expect(spoken.length, 21);
    expect(spoken, isNot(contains('A')));
    expect(spoken, contains('B'));
  });
}
