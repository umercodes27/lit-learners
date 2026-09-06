import 'package:flutter_test/flutter_test.dart';
import 'package:little_learners/models/activity_data.dart';
import 'package:little_learners/services/content/activity_pack_loader.dart';
import 'package:little_learners/services/content/asset_availability.dart';
import 'package:little_learners/services/content/module_activity_bridge.dart';

/// The age-4 pack: every level parses to a playable component, the pictures it
/// shares with the younger packs are its own copies, and a four-year-old is no
/// longer served the age-3 curriculum.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ActivityPackLoadResult> loadAge4() =>
      ActivityPackLoader().load(path: ActivityPackLoader.age4Path);

  test('the pack loads and exposes all five modules', () async {
    final result = await loadAge4();
    expect(result.error, isNull);

    final pack = result.pack!;
    expect(pack.age, 4);
    expect(
      pack.modules.map((m) => m.key),
      containsAll(<String>['english', 'urdu', 'math', 'logic', 'storytelling']),
    );
  });

  test('no level falls through as unplayable', () async {
    final pack = (await loadAge4()).pack!;

    for (final module in pack.modules) {
      for (final level in module.levels) {
        expect(level.data.component, isNot(ActivityComponent.unknown),
            reason: '${module.key}/${level.key} has an unrecognised component');
        expect(level.data.isEmpty, isFalse,
            reason: '${module.key}/${level.key} parsed to nothing');
      }
    }
  });

  test('each level maps to the component it asks for', () async {
    final pack = (await loadAge4()).pack!;

    expect(pack.levelByKey('english', 'level_1')!.data, isA<TracingData>());
    expect(pack.levelByKey('english', 'level_2')!.data, isA<WordBuilderData>());
    expect(
      pack.levelByKey('english', 'level_3')!.data,
      isA<IdentifyAndTapData>(),
    );
    expect(pack.levelByKey('urdu', 'level_1')!.data, isA<IdentifyAndTapData>());
    expect(pack.levelByKey('urdu', 'level_2')!.data, isA<WordBuilderData>());
    expect(pack.levelByKey('urdu', 'level_3')!.data, isA<IdentifyAndTapData>());
    expect(pack.levelByKey('math', 'level_1')!.data, isA<TapToCountData>());
    expect(pack.levelByKey('math', 'level_2')!.data, isA<TracingData>());
    expect(pack.levelByKey('math', 'level_3')!.data, isA<VisualMathData>());
    expect(
      pack.levelByKey('logic', 'level_1')!.data,
      isA<PatternCompleteData>(),
    );
    expect(pack.levelByKey('logic', 'level_2')!.data, isA<MazeData>());
    expect(pack.levelByKey('logic', 'level_3')!.data, isA<MemoryMatchData>());
  });

  // The pack pairs the cases in one authored item. A child who can draw A has
  // not met a, so both have to be traced.
  test('an upper/lower pair becomes two tracing rounds, capital first',
      () async {
    final pack = (await loadAge4()).pack!;
    final data = pack.levelByKey('english', 'level_1')!.data as TracingData;

    expect(data.items.map((item) => item.glyph).take(4),
        ['A', 'a', 'B', 'b']);
    // Five authored pairs, ten rounds.
    expect(data.items, hasLength(10));
  });

  test('number tracing still reads a bare numeral', () async {
    final pack = (await loadAge4()).pack!;
    final data = pack.levelByKey('math', 'level_2')!.data as TracingData;

    expect(data.items.map((item) => item.glyph), ['6', '7', '8', '9', '10']);
  });

  // Distractors are built rather than authored, so this is what stops a sum
  // from offering the right answer twice or a negative count.
  test('a sum offers three distinct, non-negative choices including the answer',
      () async {
    final pack = (await loadAge4()).pack!;
    final data = pack.levelByKey('math', 'level_3')!.data as VisualMathData;

    for (final item in data.items) {
      expect(item.options, contains(item.answer));
      expect(item.options.toSet(), hasLength(item.options.length));
      expect(item.options.every((option) => option >= 0), isTrue);
      expect(item.options, hasLength(3));
    }
  });

  test('the memory board deals every face twice into a 4-wide grid', () async {
    final pack = (await loadAge4()).pack!;
    final data = pack.levelByKey('logic', 'level_3')!.data as MemoryMatchData;

    final board = data.items.single;
    expect(board.faces, hasLength(6));
    expect(board.columns, 4);
  });

  test('the maze is generated, so it names a sprite and no layout', () async {
    final pack = (await loadAge4()).pack!;
    final data = pack.levelByKey('logic', 'level_2')!.data as MazeData;

    final maze = data.items.single;
    expect(maze.character, endsWith('duck.png'));
    expect(maze.difficulty, MazeDifficulty.medium);
    // Odd, so walls sit between cells.
    expect(maze.difficulty.size.isOdd, isTrue);
  });

  // The whole point of copying the shared pictures in: age 4 must not reach
  // into another pack's folder for them.
  test('no picture is missing, and none is borrowed from another pack',
      () async {
    final result = await loadAge4();

    final missingImages = result.missingAssets
        .where((path) => path.endsWith('.png') || path.endsWith('.jpg'))
        .toList();
    expect(missingImages, isEmpty,
        reason: 'age 4 references pictures the bundle does not have: '
            '$missingImages');

    final pack = result.pack!;
    for (final module in pack.modules) {
      for (final level in module.levels) {
        for (final asset in level.data.referencedAssets) {
          if (!asset.endsWith('.png')) continue;
          expect(asset, startsWith('assets/age4/'),
              reason: '${module.key}/${level.key} reaches outside its pack');
          expect(AssetAvailability.instance.has(asset), isTrue,
              reason: '$asset is referenced but not bundled');
        }
      }
    }
  });

  // The reward and retry cues every level plays, and the number clips that
  // were already recorded. Without these age 4 would be the one pack that
  // gives no applause.
  test('the recorded sounds it does have resolve to its own folder', () async {
    await loadAge4();

    for (final path in [
      'assets/age4/audio/sfx/applause.mp3',
      'assets/age4/audio/sfx/try_again_gentle.mp3',
      'assets/age4/audio/stories/audio_book_story.mp3',
      'assets/age4/audio/stories/manners_safety.mp3',
      'assets/age4/audio/num/1.mp3',
      'assets/age4/audio/num/5.mp3',
    ]) {
      expect(AssetAvailability.instance.has(path), isTrue, reason: path);
    }
  });

  // Everything still reported missing is audio nobody has recorded. It is
  // listed here rather than waved through, so that recording any of it is a
  // visible change to this test rather than a silent one.
  test('what is still missing is only unrecorded speech, which TTS covers',
      () async {
    final result = await loadAge4();

    expect(
      result.missingAssets.every((path) => path.endsWith('.mp3')),
      isTrue,
      reason: 'something other than audio is missing: ${result.missingAssets}',
    );

    // Sentences, Urdu words, and the numbers past the five that were recorded.
    for (final path in result.missingAssets) {
      expect(
        path.contains('/sentence_') ||
            path.contains('/word_') ||
            path.contains('/num/'),
        isTrue,
        reason: '$path is missing but is not something TTS speaks',
      );
    }
  });

  test('a four-year-old is routed to the age-4 pack, not the age-3 one', () {
    expect(ModuleActivityBridge.packAgeFor(4), 4);
    expect(
      ModuleActivityBridge.packPathFor(4),
      ActivityPackLoader.age4Path,
    );

    // Unchanged for the younger ages.
    expect(ModuleActivityBridge.packAgeFor(2), 2);
    expect(ModuleActivityBridge.packAgeFor(3), 3);
    expect(ModuleActivityBridge.packPathFor(2), ActivityPackLoader.age2Path);
    expect(ModuleActivityBridge.packPathFor(3), ActivityPackLoader.age3Path);
  });
}
