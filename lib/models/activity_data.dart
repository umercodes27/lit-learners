import 'activity_option.dart';

/// The interaction styles an age pack can ask for.
///
/// The JSON names them in snake_case; [ActivityComponent.fromJson] maps them
/// and falls back to [unknown] rather than throwing, so a pack authored for a
/// newer build still opens — the level just reports that it cannot be played.
enum ActivityComponent {
  twoChoiceTap,
  identifyAndTap,
  tapToCount,
  shadowMatch,
  puzzle,
  oddOneOut,
  storyInteractive,
  listenAndSee,
  tracing,
  dragAndMatch,
  sortIntoZones,
  patternComplete,
  wordBuilder,
  visualMath,
  maze,
  memoryMatch,
  unknown;

  static ActivityComponent fromJson(String? raw) {
    switch (raw) {
      case 'two_choice_tap':
      case 'two-choice-tap':
        return ActivityComponent.twoChoiceTap;
      case 'identify_and_tap':
      case 'identify-and-tap':
        return ActivityComponent.identifyAndTap;
      case 'tap_to_count':
      case 'tap-to-count':
      case 'counting-drag':
        return ActivityComponent.tapToCount;
      case 'shadow_match':
      case 'shadow-match':
        return ActivityComponent.shadowMatch;
      case 'puzzle':
        return ActivityComponent.puzzle;
      case 'odd_one_out':
      case 'odd-one-out':
        return ActivityComponent.oddOneOut;
      case 'story_interactive':
      case 'story-interactive':
        return ActivityComponent.storyInteractive;
      case 'listen_and_see':
      case 'listen-and-see':
        return ActivityComponent.listenAndSee;
      case 'tracing':
        return ActivityComponent.tracing;
      case 'drag_and_match':
      case 'drag-and-match':
        return ActivityComponent.dragAndMatch;
      case 'sort_into_zones':
      case 'sort-into-zones':
        return ActivityComponent.sortIntoZones;
      case 'pattern_complete':
      case 'pattern-complete':
        return ActivityComponent.patternComplete;
      case 'word_builder':
      case 'word-builder':
        return ActivityComponent.wordBuilder;
      case 'visual_math':
      case 'visual-math':
        return ActivityComponent.visualMath;
      case 'maze':
        return ActivityComponent.maze;
      case 'memory_match':
      case 'memory-match':
        return ActivityComponent.memoryMatch;
      default:
        return ActivityComponent.unknown;
    }
  }
}

/// Which side the first item of a level puts its right answer on.
///
/// Derived from the level's title with FNV-1a — a stable hash, unlike
/// [Object.hashCode], which varies between runs and would make the layout and
/// its tests unrepeatable.
bool levelPhase(String seed) {
  var hash = 0x811c9dc5;
  for (final unit in seed.codeUnits) {
    hash = ((hash ^ unit) * 0x01000193) & 0xFFFFFFFF;
  }
  return hash.isOdd;
}

/// Whether item [index] of a level should swap its pair.
///
/// The authored packs list the correct choice first every time (`target` then
/// `distractor`, `big_image` then `small_image`, `correct_shadow` then
/// `wrong_shadow`). Rendered that way a child learns to tap the left-hand box
/// and stops looking at the content.
///
/// Alternating by index rather than hashing the item guarantees the split: a
/// hash can land the same way for every item of a short level — with two to
/// five rounds that is likely, not a corner case — which is exactly the
/// failure being avoided. The level's title only decides which side goes
/// first, so consecutive levels do not all open the same way.
bool flipAt(int index, String levelTitle) =>
    (index + (levelPhase(levelTitle) ? 1 : 0)).isOdd;

/// Orders a right/wrong pair, correct answer first unless [flip].
List<ActivityOption> orderedPair(
  ActivityOption correct,
  ActivityOption wrong, {
  required bool flip,
}) {
  return flip ? [wrong, correct] : [correct, wrong];
}

/// A single playable level's content, already shaped for one component.
///
/// Parsing happens once, at load, so the widgets never touch raw maps and a
/// malformed pack surfaces as an empty level instead of a runtime cast error
/// mid-activity.
sealed class ActivityData {
  const ActivityData({
    required this.title,
    required this.isRtl,
    this.correctSound,
    this.wrongSound,
  });

  /// Reward and retry cues for this level, when it names its own. Null falls
  /// back to the pack-wide pair.
  final String? correctSound;
  final String? wrongSound;

  final String title;

  /// Urdu levels lay out right-to-left. Carried on the data rather than
  /// inferred from the module id so a pack can mix scripts in one module.
  final bool isRtl;

  ActivityComponent get component;

  /// Every asset path this level will try to load, so the loader can report
  /// the missing ones up front instead of failing one tap at a time.
  List<String> get referencedAssets;

  /// True when there is nothing playable here — an unknown component, or a
  /// level whose items all failed to parse.
  bool get isEmpty;

  static ActivityData? fromJson(Map<String, dynamic> json, {bool moduleRtl = false}) {
    final component = ActivityComponent.fromJson(json['component'] as String?);
    final title = json['title'] as String? ?? 'Activity';
    final isRtl = json['rtl'] as bool? ?? moduleRtl;

    switch (component) {
      case ActivityComponent.twoChoiceTap:
        return TwoChoiceTapData.fromJson(json, title: title, isRtl: isRtl);
      case ActivityComponent.identifyAndTap:
        return IdentifyAndTapData.fromJson(json, title: title, isRtl: isRtl);
      case ActivityComponent.tapToCount:
        return TapToCountData.fromJson(json, title: title, isRtl: isRtl);
      case ActivityComponent.shadowMatch:
        return ShadowMatchData.fromJson(json, title: title, isRtl: isRtl);
      case ActivityComponent.puzzle:
        return PuzzleData.fromJson(json, title: title, isRtl: isRtl);
      case ActivityComponent.oddOneOut:
        return OddOneOutData.fromJson(json, title: title, isRtl: isRtl);
      case ActivityComponent.storyInteractive:
        return StoryInteractiveData.fromJson(json, title: title, isRtl: isRtl);
      case ActivityComponent.listenAndSee:
        return ListenAndSeeData.fromJson(json, title: title, isRtl: isRtl);
      case ActivityComponent.tracing:
        return TracingData.fromJson(json, title: title, isRtl: isRtl);
      case ActivityComponent.dragAndMatch:
        return DragAndMatchData.fromJson(json, title: title, isRtl: isRtl);
      case ActivityComponent.sortIntoZones:
        return SortIntoZonesData.fromJson(json, title: title, isRtl: isRtl);
      case ActivityComponent.patternComplete:
        return PatternCompleteData.fromJson(json, title: title, isRtl: isRtl);
      case ActivityComponent.wordBuilder:
        return WordBuilderData.fromJson(json, title: title, isRtl: isRtl);
      case ActivityComponent.visualMath:
        return VisualMathData.fromJson(json, title: title, isRtl: isRtl);
      case ActivityComponent.maze:
        return MazeData.fromJson(json, title: title, isRtl: isRtl);
      case ActivityComponent.memoryMatch:
        return MemoryMatchData.fromJson(json, title: title, isRtl: isRtl);
      case ActivityComponent.unknown:
        return UnsupportedActivityData(
          title: title,
          isRtl: isRtl,
          rawComponent: json['component'] as String? ?? '(none)',
        );
    }
  }

  /// A level may carry its own `feedback` block; most do not and inherit the
  /// pack's.
  static String? correctSoundOf(Map<String, dynamic> json) =>
      _feedback(json)['correct_sound'] as String?;

  static String? wrongSoundOf(Map<String, dynamic> json) =>
      _feedback(json)['wrong_sound'] as String?;

  static Map<String, dynamic> _feedback(Map<String, dynamic> json) {
    final raw = json['feedback'];
    return raw is Map<String, dynamic> ? raw : const {};
  }

  static List<Map<String, dynamic>> _items(Map<String, dynamic> json) {
    final raw = json['items'];
    if (raw is! List) return const [];
    return raw.whereType<Map<String, dynamic>>().toList();
  }
}

/// A level whose `component` this build does not know how to play.
class UnsupportedActivityData extends ActivityData {
  const UnsupportedActivityData({
    required super.title,
    required super.isRtl,
    super.correctSound,
    super.wrongSound,
    required this.rawComponent,
  });

  final String rawComponent;

  @override
  ActivityComponent get component => ActivityComponent.unknown;

  @override
  List<String> get referencedAssets => const [];

  @override
  bool get isEmpty => true;
}

// ---------------------------------------------------------------------------
// two_choice_tap
// ---------------------------------------------------------------------------

/// The two sizes a code-rendered big/small pair is drawn at.
///
/// Far enough apart that the difference is obvious to a two-year-old across
/// the width of a screen — a subtle ratio would make the round a guess.
const double _bigScale = 1;
const double _smallScale = 0.45;

class TwoChoiceTapItem {
  const TwoChoiceTapItem({
    required this.options,
    this.audioPrompt,
    this.promptText,
  });

  /// Accepts three authored shapes:
  ///
  /// * an explicit `options` list;
  /// * `target` / `distractor` letters with a `target_audio`, as the English
  ///   and Urdu letter rounds are written;
  /// * `big_image` / `small_image`, as the size rounds are written.
  ///
  /// The last two name the right answer by position rather than a `correct`
  /// flag, which is why the pair is re-ordered on the way in.
  factory TwoChoiceTapItem.fromJson(
    Map<String, dynamic> json, {
    required bool flip,
  }) {
    final audioPrompt = json['audio_prompt'] as String?;
    final promptText = json['prompt_text'] as String?;

    final explicit = ActivityOption.listFrom(json['options']);
    if (explicit.isNotEmpty) {
      return TwoChoiceTapItem(
        options: explicit,
        audioPrompt: audioPrompt,
        promptText: promptText,
      );
    }

    final target = json['target'] as String?;
    if (target != null) {
      return TwoChoiceTapItem(
        options: orderedPair(
          ActivityOption(
            label: target,
            audio: json['target_audio'] as String?,
            isCorrect: true,
          ),
          ActivityOption(
            label: json['distractor'] as String?,
            audio: json['distractor_audio'] as String?,
          ),
          flip: flip,
        ),
        audioPrompt: audioPrompt,
        promptText: promptText,
      );
    }

    final big = json['big_image'] as String?;
    if (big != null) {
      // The prompts for this round all ask for the big one.
      return TwoChoiceTapItem(
        options: orderedPair(
          ActivityOption(image: big, isCorrect: true),
          ActivityOption(image: json['small_image'] as String?),
          flip: flip,
        ),
        audioPrompt: audioPrompt,
        promptText: promptText,
      );
    }

    // Two plates of the same fruit, one with more on it. The pack gives the
    // counts and a single picture; the widget lays out that many copies.
    final plateA = (json['plate_a_count'] as num?)?.toInt();
    final plateB = (json['plate_b_count'] as num?)?.toInt();
    final plateImage = json['images'] as String? ?? json['image'] as String?;
    if (plateA != null && plateB != null && plateImage != null) {
      final aWins = plateA > plateB;
      return TwoChoiceTapItem(
        options: [
          ActivityOption(image: plateImage, count: plateA, isCorrect: aWins),
          ActivityOption(image: plateImage, count: plateB, isCorrect: !aWins),
        ],
        audioPrompt: audioPrompt,
        promptText: promptText,
      );
    }

    // One picture, drawn at two sizes. The pack sets `render_sizes_in_code`
    // rather than shipping a big and a small file for every animal, so the
    // size difference — the whole point of the round — has to come from here.
    final single = json['image'] as String?;
    if (single != null && (json['render_sizes_in_code'] as bool? ?? false)) {
      return TwoChoiceTapItem(
        options: orderedPair(
          ActivityOption(image: single, isCorrect: true, scale: _bigScale),
          ActivityOption(image: single, scale: _smallScale),
          flip: flip,
        ),
        audioPrompt: audioPrompt,
        promptText: promptText,
      );
    }

    return TwoChoiceTapItem(
      options: const [],
      audioPrompt: audioPrompt,
      promptText: promptText,
    );
  }

  final List<ActivityOption> options;
  final String? audioPrompt;
  final String? promptText;

  List<String> get referencedAssets => [
        if (audioPrompt != null) audioPrompt!,
        for (final option in options) ...option.referencedAssets,
      ];
}

class TwoChoiceTapData extends ActivityData {
  const TwoChoiceTapData({
    required super.title,
    required super.isRtl,
    super.correctSound,
    super.wrongSound,
    required this.items,
  });

  factory TwoChoiceTapData.fromJson(
    Map<String, dynamic> json, {
    required String title,
    required bool isRtl,
  }) {
    return TwoChoiceTapData(
      title: title,
      isRtl: isRtl,
      correctSound: ActivityData.correctSoundOf(json),
      wrongSound: ActivityData.wrongSoundOf(json),
      items: ActivityData._items(json)
          .indexed
          .map((entry) => TwoChoiceTapItem.fromJson(
                entry.$2,
                flip: flipAt(entry.$1, title),
              ))
          .toList(),
    );
  }

  final List<TwoChoiceTapItem> items;

  @override
  ActivityComponent get component => ActivityComponent.twoChoiceTap;

  @override
  List<String> get referencedAssets =>
      [for (final item in items) ...item.referencedAssets];

  @override
  bool get isEmpty => items.isEmpty;
}

// ---------------------------------------------------------------------------
// identify_and_tap
// ---------------------------------------------------------------------------

class IdentifyAndTapItem {
  const IdentifyAndTapItem({
    required this.options,
    this.audioPrompt,
    this.promptImage,
    this.promptText,
  });

  /// Accepts an explicit `options` list, the `correct_letter` / `wrong_letter`
  /// pair the phonics and Urdu rounds use, or the `basket_options` + `color`
  /// shape the shapes-and-colours round uses — where the choices are colour
  /// names and the right one is named separately.
  factory IdentifyAndTapItem.fromJson(
    Map<String, dynamic> json, {
    required bool flip,
  }) {
    final audioPrompt = json['audio_prompt'] as String?;
    final promptImage =
        json['prompt_image'] as String? ?? json['image'] as String?;
    final promptText = json['prompt_text'] as String?;

    List<ActivityOption> options = ActivityOption.listFrom(json['options']);

    if (options.isEmpty) {
      final correctLetter = json['correct_letter'] as String?;
      if (correctLetter != null) {
        options = orderedPair(
          ActivityOption(label: correctLetter, isCorrect: true),
          ActivityOption(label: json['wrong_letter'] as String?),
          flip: flip,
        );
      }
    }

    if (options.isEmpty) {
      final baskets = json['basket_options'];
      final answer = json['color'] as String? ?? json['correct_option'] as String?;
      if (baskets is List && answer != null) {
        options = [
          for (final basket in baskets.whereType<String>())
            ActivityOption(label: basket, isCorrect: basket == answer),
        ];
      }
    }

    return IdentifyAndTapItem(
      options: options,
      audioPrompt: audioPrompt,
      promptImage: promptImage,
      promptText: promptText ?? json['shape'] as String?,
    );
  }

  final List<ActivityOption> options;
  final String? audioPrompt;
  final String? promptImage;
  final String? promptText;

  List<String> get referencedAssets => [
        if (audioPrompt != null) audioPrompt!,
        if (promptImage != null) promptImage!,
        for (final option in options) ...option.referencedAssets,
      ];
}

class IdentifyAndTapData extends ActivityData {
  const IdentifyAndTapData({
    required super.title,
    required super.isRtl,
    super.correctSound,
    super.wrongSound,
    required this.items,
  });

  factory IdentifyAndTapData.fromJson(
    Map<String, dynamic> json, {
    required String title,
    required bool isRtl,
  }) {
    return IdentifyAndTapData(
      title: title,
      isRtl: isRtl,
      correctSound: ActivityData.correctSoundOf(json),
      wrongSound: ActivityData.wrongSoundOf(json),
      items: _roundsFrom(ActivityData._items(json), title: title),
    );
  }

  /// Parses the level's items, and builds the choices when the pack does not
  /// name any.
  ///
  /// Age 4 writes these levels as a list of targets — a sentence and its
  /// picture, a word and its picture, a letter and a word it appears in — with
  /// no wrong answers anywhere. Parsed literally that is a round with nothing
  /// to tap, so a level's own siblings are used as its distractors: the round
  /// for "The Dog runs" offers the dog against the next item's picture. The
  /// content stays the pack's, and a level needs no new artwork to be
  /// playable.
  ///
  /// Only ever reached when *every* item came out empty. A pack that names its
  /// options, as ages 2 and 3 do, parses exactly as before.
  static List<IdentifyAndTapItem> _roundsFrom(
    List<Map<String, dynamic>> raw, {
    required String title,
  }) {
    final parsed = raw.indexed
        .map((entry) => IdentifyAndTapItem.fromJson(
              entry.$2,
              flip: flipAt(entry.$1, title),
            ))
        .toList();

    final needsChoices =
        parsed.isNotEmpty && parsed.every((item) => item.options.isEmpty);
    if (!needsChoices || raw.length < 2) return parsed;

    // What the round asks for, and what the child reads or hears while
    // choosing.
    String? imageOf(Map<String, dynamic> item) => item['image'] as String?;
    String? letterOf(Map<String, dynamic> item) => item['letter'] as String?;
    String? textOf(Map<String, dynamic> item) =>
        item['sentence'] as String? ??
        item['word'] as String? ??
        item['example_word'] as String?;

    final rounds = <IdentifyAndTapItem>[];
    for (var i = 0; i < raw.length; i++) {
      final mine = raw[i];
      final other = raw[(i + 1) % raw.length];
      final flip = flipAt(i, title);
      final audio = mine['audio_prompt'] as String?;
      final text = textOf(mine);

      final image = imageOf(mine);
      if (image != null && imageOf(other) != null) {
        rounds.add(IdentifyAndTapItem(
          // No prompt image: the picture *is* the answer, so showing it above
          // the choices would be showing the child which one to tap.
          options: orderedPair(
            ActivityOption(image: image, isCorrect: true),
            ActivityOption(image: imageOf(other)),
            flip: flip,
          ),
          audioPrompt: audio,
          promptText: text,
        ));
        continue;
      }

      final letter = letterOf(mine);
      if (letter != null && letterOf(other) != null) {
        rounds.add(IdentifyAndTapItem(
          options: orderedPair(
            ActivityOption(label: letter, isCorrect: true),
            ActivityOption(label: letterOf(other)),
            flip: flip,
          ),
          audioPrompt: audio,
          promptText: text,
        ));
      }
    }

    return rounds.isEmpty ? parsed : rounds;
  }

  final List<IdentifyAndTapItem> items;

  @override
  ActivityComponent get component => ActivityComponent.identifyAndTap;

  @override
  List<String> get referencedAssets =>
      [for (final item in items) ...item.referencedAssets];

  @override
  bool get isEmpty => items.isEmpty;
}

// ---------------------------------------------------------------------------
// tap_to_count
// ---------------------------------------------------------------------------

class TapToCountItem {
  const TapToCountItem({
    required this.objectImage,
    required this.targetCount,
    this.audioNumbers = const [],
  });

  factory TapToCountItem.fromJson(Map<String, dynamic> json) {
    final rawNumbers = json['audio_numbers'];
    return TapToCountItem(
      objectImage: json['object_image'] as String? ?? json['objects'] as String?,
      targetCount: (json['target_count'] as num?)?.toInt() ??
          (json['count'] as num?)?.toInt() ??
          0,
      audioNumbers:
          rawNumbers is List ? rawNumbers.whereType<String>().toList() : const [],
    );
  }

  final String? objectImage;
  final int targetCount;

  /// The number sounds for this set, in order, when the pack lists them per
  /// item. Takes precedence over the level's `count_audio_folder`.
  final List<String> audioNumbers;

  /// The sound for the [n]th object counted, 1-based.
  String? audioForCount(int n, {String? folder}) {
    if (n >= 1 && n <= audioNumbers.length) return audioNumbers[n - 1];
    if (folder != null) return '$folder/$n.mp3';
    return null;
  }

  List<String> get referencedAssets => [
        if (objectImage != null) objectImage!,
        ...audioNumbers,
      ];
}

class TapToCountData extends ActivityData {
  const TapToCountData({
    required super.title,
    required super.isRtl,
    super.correctSound,
    super.wrongSound,
    required this.items,
    required this.countAudioFolder,
  });

  factory TapToCountData.fromJson(
    Map<String, dynamic> json, {
    required String title,
    required bool isRtl,
  }) {
    return TapToCountData(
      title: title,
      isRtl: isRtl,
      correctSound: ActivityData.correctSoundOf(json),
      wrongSound: ActivityData.wrongSoundOf(json),
      items: ActivityData._items(json).map(TapToCountItem.fromJson).toList(),
      countAudioFolder: json['count_audio_folder'] as String? ??
          json['audio_numbers_folder'] as String?,
    );
  }

  final List<TapToCountItem> items;

  /// Folder holding `1.mp3` … `5.mp3`. Each tap plays the number reached.
  final String? countAudioFolder;

  /// The number sounds this level will reach, derived from the highest count
  /// asked for, so the audit can flag a missing `4.mp3` before a child taps.
  List<String> get countAudioAssets {
    final folder = countAudioFolder;
    if (folder == null || items.isEmpty) return const [];
    // Items that list their own sounds already contribute them; only the ones
    // relying on the folder need paths derived here.
    final highest = items
        .where((item) => item.audioNumbers.isEmpty)
        .map((item) => item.targetCount)
        .fold<int>(0, (a, b) => a > b ? a : b);
    return [for (var n = 1; n <= highest; n++) '$folder/$n.mp3'];
  }

  @override
  ActivityComponent get component => ActivityComponent.tapToCount;

  @override
  List<String> get referencedAssets => [
        for (final item in items) ...item.referencedAssets,
        ...countAudioAssets,
      ];

  @override
  bool get isEmpty => items.isEmpty;
}

// ---------------------------------------------------------------------------
// shadow_match
// ---------------------------------------------------------------------------

class ShadowMatchItem {
  const ShadowMatchItem({
    required this.options,
    this.objectImage,
    this.audioPrompt,
  });

  /// Accepts an explicit `options` list or the authored
  /// `correct_shadow` / `wrong_shadow` pair.
  factory ShadowMatchItem.fromJson(
    Map<String, dynamic> json, {
    required bool flip,
  }) {
    final objectImage = json['object_image'] as String?;
    var options = ActivityOption.listFrom(json['options']);

    final correctShadow = json['correct_shadow'] as String?;
    if (options.isEmpty && correctShadow != null) {
      options = orderedPair(
        ActivityOption(image: correctShadow, isCorrect: true),
        ActivityOption(image: json['wrong_shadow'] as String?),
        flip: flip,
      );
    }

    return ShadowMatchItem(
      options: options,
      objectImage: objectImage,
      audioPrompt: json['audio_prompt'] as String?,
    );
  }

  final List<ActivityOption> options;
  final String? objectImage;
  final String? audioPrompt;

  List<String> get referencedAssets => [
        if (objectImage != null) objectImage!,
        if (audioPrompt != null) audioPrompt!,
        for (final option in options) ...option.referencedAssets,
      ];
}

class ShadowMatchData extends ActivityData {
  const ShadowMatchData({
    required super.title,
    required super.isRtl,
    super.correctSound,
    super.wrongSound,
    required this.items,
  });

  factory ShadowMatchData.fromJson(
    Map<String, dynamic> json, {
    required String title,
    required bool isRtl,
  }) {
    return ShadowMatchData(
      title: title,
      isRtl: isRtl,
      correctSound: ActivityData.correctSoundOf(json),
      wrongSound: ActivityData.wrongSoundOf(json),
      items: ActivityData._items(json)
          .indexed
          .map((entry) => ShadowMatchItem.fromJson(
                entry.$2,
                flip: flipAt(entry.$1, title),
              ))
          .toList(),
    );
  }

  final List<ShadowMatchItem> items;

  @override
  ActivityComponent get component => ActivityComponent.shadowMatch;

  @override
  List<String> get referencedAssets =>
      [for (final item in items) ...item.referencedAssets];

  @override
  bool get isEmpty => items.isEmpty;
}

// ---------------------------------------------------------------------------
// puzzle
// ---------------------------------------------------------------------------

class PuzzleItem {
  const PuzzleItem({
    required this.pieces,
    this.fullImage,
  });

  /// Accepts a `pieces` list, or the authored `piece_1`, `piece_2`, … keys.
  /// The numbered keys are read in order and stop at the first gap, so a
  /// mis-numbered pack loses the tail rather than silently reordering itself.
  factory PuzzleItem.fromJson(Map<String, dynamic> json) {
    final rawPieces = json['pieces'];
    var pieces =
        rawPieces is List ? rawPieces.whereType<String>().toList() : <String>[];

    if (pieces.isEmpty) {
      for (var n = 1;; n++) {
        final piece = json['piece_$n'] as String?;
        if (piece == null) break;
        pieces.add(piece);
      }
    }

    return PuzzleItem(
      pieces: pieces,
      fullImage: json['full_image'] as String?,
    );
  }

  final List<String> pieces;
  final String? fullImage;

  List<String> get referencedAssets => [
        if (fullImage != null) fullImage!,
        ...pieces,
      ];
}

class PuzzleData extends ActivityData {
  const PuzzleData({
    required super.title,
    required super.isRtl,
    super.correctSound,
    super.wrongSound,
    required this.items,
    required this.pieceCount,
  });

  factory PuzzleData.fromJson(
    Map<String, dynamic> json, {
    required String title,
    required bool isRtl,
  }) {
    final items = ActivityData._items(json).map(PuzzleItem.fromJson).toList();
    // `piece_count` is the level's declared difficulty, but the pieces list is
    // what actually gets rendered. Trust the list when they disagree so a
    // mismatched pack still plays.
    final declared = (json['piece_count'] as num?)?.toInt();
    final actual = items.isEmpty ? 0 : items.first.pieces.length;
    return PuzzleData(
      title: title,
      isRtl: isRtl,
      correctSound: ActivityData.correctSoundOf(json),
      wrongSound: ActivityData.wrongSoundOf(json),
      items: items,
      pieceCount: actual > 0 ? actual : (declared ?? 0),
    );
  }

  final List<PuzzleItem> items;

  /// How many pieces the child drags together.
  final int pieceCount;

  @override
  ActivityComponent get component => ActivityComponent.puzzle;

  @override
  List<String> get referencedAssets =>
      [for (final item in items) ...item.referencedAssets];

  /// True when the pack named a piece count but shipped no piece files, so
  /// the widget has to cut the full picture up itself.
  bool get needsRuntimeSlicing =>
      items.isNotEmpty && items.every((item) => item.pieces.isEmpty);

  @override
  bool get isEmpty => items.isEmpty || pieceCount < 2;
}

// ---------------------------------------------------------------------------
// odd_one_out
// ---------------------------------------------------------------------------

class OddOneOutItem {
  const OddOneOutItem({
    required this.options,
    this.promptText,
    this.audioPrompt,
  });

  /// Accepts an explicit `options` list, or the authored `items` array of
  /// image paths plus the `odd_item_index` that says which one is the answer.
  factory OddOneOutItem.fromJson(Map<String, dynamic> json) {
    var options = ActivityOption.listFrom(json['options']);

    final nested = json['items'];
    final oddIndex = (json['odd_item_index'] as num?)?.toInt();
    if (options.isEmpty && nested is List && oddIndex != null) {
      final images = nested.whereType<String>().toList();
      options = [
        for (var i = 0; i < images.length; i++)
          ActivityOption(image: images[i], isCorrect: i == oddIndex),
      ];
    }

    return OddOneOutItem(
      options: options,
      promptText: json['prompt_text'] as String?,
      audioPrompt: json['audio_prompt'] as String?,
    );
  }

  final List<ActivityOption> options;
  final String? promptText;
  final String? audioPrompt;

  List<String> get referencedAssets => [
        if (audioPrompt != null) audioPrompt!,
        for (final option in options) ...option.referencedAssets,
      ];
}

class OddOneOutData extends ActivityData {
  const OddOneOutData({
    required super.title,
    required super.isRtl,
    super.correctSound,
    super.wrongSound,
    required this.items,
  });

  factory OddOneOutData.fromJson(
    Map<String, dynamic> json, {
    required String title,
    required bool isRtl,
  }) {
    return OddOneOutData(
      title: title,
      isRtl: isRtl,
      correctSound: ActivityData.correctSoundOf(json),
      wrongSound: ActivityData.wrongSoundOf(json),
      items: ActivityData._items(json).map(OddOneOutItem.fromJson).toList(),
    );
  }

  final List<OddOneOutItem> items;

  @override
  ActivityComponent get component => ActivityComponent.oddOneOut;

  @override
  List<String> get referencedAssets =>
      [for (final item in items) ...item.referencedAssets];

  @override
  bool get isEmpty => items.isEmpty;
}

// ---------------------------------------------------------------------------
// story_interactive
// ---------------------------------------------------------------------------

class StoryIllustration {
  const StoryIllustration({
    required this.image,
    required this.startMs,
    this.caption,
  });

  factory StoryIllustration.fromJson(dynamic raw, {required int index}) {
    // Accepts either a bare path or an object with timing, so a simple pack
    // can list images and a richer one can time them to the narration.
    if (raw is String) {
      return StoryIllustration(image: raw, startMs: index * 5000);
    }
    if (raw is Map<String, dynamic>) {
      return StoryIllustration(
        image: raw['image'] as String? ?? '',
        startMs: (raw['start_ms'] as num?)?.toInt() ?? index * 5000,
        caption: raw['caption'] as String?,
      );
    }
    return StoryIllustration(image: '', startMs: index * 5000);
  }

  final String image;
  final int startMs;
  final String? caption;
}

class StoryChoicePoint {
  const StoryChoicePoint({
    required this.options,
    required this.atMs,
    this.promptText,
    this.audioPrompt,
  });

  /// Accepts an explicit `options` list, or the authored `correct_image` — a
  /// single thing to find, as in "Tap the soap!". One option is a real round
  /// at this age: the child still has to recognise it on the screen.
  factory StoryChoicePoint.fromJson(Map<String, dynamic> json) {
    var options = ActivityOption.listFrom(json['options']);

    final correctImage = json['correct_image'] as String?;
    if (options.isEmpty && correctImage != null) {
      options = [ActivityOption(image: correctImage, isCorrect: true)];
    }

    // Age 4 names the answer as a slug and nothing else —
    // `"correct_answer": "please_and_thank_you"`. Read literally that is a
    // question with no answers, which is a story a child cannot get out of.
    // The slug is the answer, so it becomes the option, spelled the way it
    // would be said.
    final correctAnswer = json['correct_answer'] as String?;
    if (options.isEmpty && correctAnswer != null && correctAnswer.isNotEmpty) {
      options = [ActivityOption(label: _spellOut(correctAnswer), isCorrect: true)];
    }

    return StoryChoicePoint(
      options: options,
      atMs: (json['at_ms'] as num?)?.toInt() ?? 0,
      promptText: json['prompt_text'] as String? ?? json['prompt'] as String?,
      audioPrompt: json['audio_prompt'] as String?,
    );
  }

  /// `please_and_thank_you` -> `Please and thank you`.
  static String _spellOut(String slug) {
    final words = slug.replaceAll('_', ' ').trim();
    if (words.isEmpty) return words;
    return '${words[0].toUpperCase()}${words.substring(1)}';
  }

  final List<ActivityOption> options;

  /// When in the narration the story pauses to ask. Zero means "at the end".
  final int atMs;
  final String? promptText;
  final String? audioPrompt;

  List<String> get referencedAssets => [
        if (audioPrompt != null) audioPrompt!,
        for (final option in options) ...option.referencedAssets,
      ];
}

class StoryInteractiveData extends ActivityData {
  const StoryInteractiveData({
    required super.title,
    required super.isRtl,
    super.correctSound,
    super.wrongSound,
    required this.illustrations,
    this.audioNarration,
    this.choicePoint,
  });

  factory StoryInteractiveData.fromJson(
    Map<String, dynamic> json, {
    required String title,
    required bool isRtl,
  }) {
    final rawSequence = json['illustration_sequence'];
    final illustrations = <StoryIllustration>[];
    if (rawSequence is List) {
      for (var i = 0; i < rawSequence.length; i++) {
        illustrations.add(StoryIllustration.fromJson(rawSequence[i], index: i));
      }
    }
    final rawChoice = json['choice_point'];
    return StoryInteractiveData(
      title: title,
      isRtl: isRtl,
      correctSound: ActivityData.correctSoundOf(json),
      wrongSound: ActivityData.wrongSoundOf(json),
      illustrations: illustrations,
      audioNarration: json['audio_narration'] as String?,
      choicePoint: rawChoice is Map<String, dynamic>
          ? StoryChoicePoint.fromJson(rawChoice)
          : null,
    );
  }

  final List<StoryIllustration> illustrations;
  final String? audioNarration;
  final StoryChoicePoint? choicePoint;

  @override
  ActivityComponent get component => ActivityComponent.storyInteractive;

  @override
  List<String> get referencedAssets => [
        if (audioNarration != null) audioNarration!,
        for (final illustration in illustrations)
          if (illustration.image.isNotEmpty) illustration.image,
        ...?choicePoint?.referencedAssets,
      ];

  @override
  bool get isEmpty => illustrations.isEmpty;
}

// ---------------------------------------------------------------------------
// listen_and_see
// ---------------------------------------------------------------------------

class ListenAndSeeItem {
  const ListenAndSeeItem({
    this.word,
    this.image,
    this.audio,
  });

  factory ListenAndSeeItem.fromJson(Map<String, dynamic> json) {
    return ListenAndSeeItem(
      word: json['word'] as String?,
      image: json['image'] as String?,
      audio: json['audio'] as String? ?? json['audio_prompt'] as String?,
    );
  }

  final String? word;
  final String? image;
  final String? audio;

  List<String> get referencedAssets => [
        if (image != null) image!,
        if (audio != null) audio!,
      ];
}

/// A sight-word card: a picture, the word, and the word said aloud.
///
/// The only component with nothing to get wrong — the child listens and moves
/// on at their own pace. It exists because the age-2 pack's English level 3 is
/// authored as `listen-and-see`, and dropping it would have left that level
/// unplayable.
class ListenAndSeeData extends ActivityData {
  const ListenAndSeeData({
    required super.title,
    required super.isRtl,
    super.correctSound,
    super.wrongSound,
    required this.items,
  });

  factory ListenAndSeeData.fromJson(
    Map<String, dynamic> json, {
    required String title,
    required bool isRtl,
  }) {
    return ListenAndSeeData(
      title: title,
      isRtl: isRtl,
      correctSound: ActivityData.correctSoundOf(json),
      wrongSound: ActivityData.wrongSoundOf(json),
      items: ActivityData._items(json).map(ListenAndSeeItem.fromJson).toList(),
    );
  }

  final List<ListenAndSeeItem> items;

  @override
  ActivityComponent get component => ActivityComponent.listenAndSee;

  @override
  List<String> get referencedAssets =>
      [for (final item in items) ...item.referencedAssets];

  @override
  bool get isEmpty => items.isEmpty;
}

// ---------------------------------------------------------------------------
// tracing
// ---------------------------------------------------------------------------

class TracingItem {
  const TracingItem({required this.glyph, this.audio});

  factory TracingItem.fromJson(Map<String, dynamic> json) {
    return TracingItem(
      // A tracing level is either letters or numerals; the pack names the key
      // accordingly and both mean "the thing to draw".
      glyph: json['letter'] as String? ?? json['number'] as String? ?? '',
      audio: json['audio'] as String?,
    );
  }

  /// What the child traces — `A`, `Alif`, `7`.
  final String glyph;

  /// A recorded clip, when one exists. Most glyphs have none and are spoken
  /// by the device instead.
  final String? audio;

  /// The tracing rounds one authored item turns into.
  ///
  /// Age 4 pairs the cases — `{"letter_upper": "A", "letter_lower": "a"}` —
  /// because a child who can draw A has not yet met a. Rather than teach the
  /// widget about pairs, the pair is unrolled here into two ordinary rounds,
  /// capital first: the same engine draws both, and the progress stars count
  /// what the child actually traces. Every other pack yields one round, as
  /// before.
  static Iterable<TracingItem> allFrom(Map<String, dynamic> json) {
    final upper = json['letter_upper'] as String?;
    final lower = json['letter_lower'] as String?;
    if (upper == null && lower == null) return [TracingItem.fromJson(json)];

    final audio = json['audio'] as String?;
    return [
      for (final glyph in [upper, lower])
        if (glyph != null && glyph.isNotEmpty)
          TracingItem(glyph: glyph, audio: audio),
    ];
  }
}

/// Trace a letter or numeral drawn from a font, following guide arrows.
///
/// Carries no artwork at all: the outline comes from the same fonts the rest
/// of the app already ships, which is what lets one level cover A-Z without
/// twenty-six image files. The recorded [TracingItem.audio] is optional for
/// the same reason — anything without a clip is spoken aloud by the device.
class TracingData extends ActivityData {
  const TracingData({
    required super.title,
    required super.isRtl,
    super.correctSound,
    super.wrongSound,
    required this.items,
    this.rewardSound,
  });

  factory TracingData.fromJson(
    Map<String, dynamic> json, {
    required String title,
    required bool isRtl,
  }) {
    return TracingData(
      title: title,
      isRtl: isRtl,
      correctSound: ActivityData.correctSoundOf(json),
      wrongSound: ActivityData.wrongSoundOf(json),
      items: ActivityData._items(json).expand(TracingItem.allFrom).toList(),
      rewardSound: json['reward_sound'] as String?,
    );
  }

  final List<TracingItem> items;
  final String? rewardSound;

  @override
  ActivityComponent get component => ActivityComponent.tracing;

  /// Only the clips that exist. A glyph with no recording is not a missing
  /// asset — it is spoken instead — so it must not be reported as one.
  @override
  List<String> get referencedAssets => [
        for (final item in items)
          if (item.audio != null) item.audio!,
        if (rewardSound != null) rewardSound!,
      ];

  @override
  bool get isEmpty => items.isEmpty;
}

// ---------------------------------------------------------------------------
// drag_and_match
// ---------------------------------------------------------------------------

class DragMatchPair {
  const DragMatchPair({
    required this.id,
    required this.letter,
    this.image,
  });

  factory DragMatchPair.fromJson(Map<String, dynamic> json, int index) {
    return DragMatchPair(
      id: json['id_pair'] as String? ?? 'pair_$index',
      letter: json['letter'] as String? ?? '',
      image: json['image'] as String?,
    );
  }

  /// Ties a letter to its picture. The pack's `id_pair` is what makes a drop
  /// right or wrong, rather than comparing paths.
  final String id;
  final String letter;
  final String? image;

  List<String> get referencedAssets => [if (image != null) image!];
}

/// Drag each letter onto the picture that starts with it.
class DragAndMatchData extends ActivityData {
  const DragAndMatchData({
    required super.title,
    required super.isRtl,
    super.correctSound,
    super.wrongSound,
    required this.pairs,
  });

  factory DragAndMatchData.fromJson(
    Map<String, dynamic> json, {
    required String title,
    required bool isRtl,
  }) {
    final raw = ActivityData._items(json);
    return DragAndMatchData(
      title: title,
      isRtl: isRtl,
      correctSound: ActivityData.correctSoundOf(json),
      wrongSound: ActivityData.wrongSoundOf(json),
      pairs: [
        for (var i = 0; i < raw.length; i++) DragMatchPair.fromJson(raw[i], i),
      ],
    );
  }

  final List<DragMatchPair> pairs;

  @override
  ActivityComponent get component => ActivityComponent.dragAndMatch;

  @override
  List<String> get referencedAssets =>
      [for (final pair in pairs) ...pair.referencedAssets];

  @override
  bool get isEmpty => pairs.isEmpty;
}

// ---------------------------------------------------------------------------
// sort_into_zones
// ---------------------------------------------------------------------------

class SortZone {
  const SortZone({required this.key, required this.background});

  final String key;
  final String? background;
}

class SortItem {
  const SortItem({required this.image, required this.zoneKey});

  factory SortItem.fromJson(Map<String, dynamic> json) {
    return SortItem(
      image: json['item'] as String? ?? json['image'] as String?,
      zoneKey: json['correct_zone'] as String? ?? '',
    );
  }

  final String? image;
  final String zoneKey;
}

/// Drag each thing into the place it belongs.
class SortIntoZonesData extends ActivityData {
  const SortIntoZonesData({
    required super.title,
    required super.isRtl,
    super.correctSound,
    super.wrongSound,
    required this.items,
    required this.zones,
  });

  factory SortIntoZonesData.fromJson(
    Map<String, dynamic> json, {
    required String title,
    required bool isRtl,
  }) {
    final rawZones = json['zones'];
    final zones = <SortZone>[];
    if (rawZones is Map<String, dynamic>) {
      for (final entry in rawZones.entries) {
        zones.add(SortZone(
          key: entry.key,
          background: entry.value is String ? entry.value as String : null,
        ));
      }
    }
    return SortIntoZonesData(
      title: title,
      isRtl: isRtl,
      correctSound: ActivityData.correctSoundOf(json),
      wrongSound: ActivityData.wrongSoundOf(json),
      items: ActivityData._items(json).map(SortItem.fromJson).toList(),
      zones: zones,
    );
  }

  final List<SortItem> items;
  final List<SortZone> zones;

  @override
  ActivityComponent get component => ActivityComponent.sortIntoZones;

  @override
  List<String> get referencedAssets => [
        for (final item in items)
          if (item.image != null) item.image!,
        for (final zone in zones)
          if (zone.background != null) zone.background!,
      ];

  /// Needs somewhere to drop as well as something to drag.
  @override
  bool get isEmpty => items.isEmpty || zones.length < 2;
}

// ---------------------------------------------------------------------------
// pattern_complete
// ---------------------------------------------------------------------------

class PatternItem {
  const PatternItem({
    required this.sequence,
    required this.options,
  });

  factory PatternItem.fromJson(Map<String, dynamic> json) {
    final rawSequence = json['sequence'];
    final sequence = rawSequence is List
        ? rawSequence.whereType<String>().toList()
        : <String>[];

    final answer = json['correct_answer'] as String?;
    var options = ActivityOption.listFrom(json['options']);

    if (options.isEmpty) {
      // The age-3 pack lists options as bare paths and names the answer
      // separately, rather than flagging one of them.
      final raw = json['options'];
      if (raw is List) {
        options = [
          for (final path in raw.whereType<String>())
            ActivityOption(image: path, isCorrect: path == answer),
        ];
      }
    } else if (answer != null && !options.any((o) => o.isCorrect)) {
      options = [
        for (final option in options)
          ActivityOption(
            label: option.label,
            image: option.image,
            audio: option.audio,
            isCorrect: option.image == answer,
          ),
      ];
    }

    return PatternItem(sequence: sequence, options: options);
  }

  /// The run so far. The child picks what comes next.
  final List<String> sequence;
  final List<ActivityOption> options;

  List<String> get referencedAssets => [
        ...sequence,
        for (final option in options) ...option.referencedAssets,
      ];
}

/// Finish the pattern.
class PatternCompleteData extends ActivityData {
  const PatternCompleteData({
    required super.title,
    required super.isRtl,
    super.correctSound,
    super.wrongSound,
    required this.items,
  });

  factory PatternCompleteData.fromJson(
    Map<String, dynamic> json, {
    required String title,
    required bool isRtl,
  }) {
    return PatternCompleteData(
      title: title,
      isRtl: isRtl,
      correctSound: ActivityData.correctSoundOf(json),
      wrongSound: ActivityData.wrongSoundOf(json),
      items: ActivityData._items(json).map(PatternItem.fromJson).toList(),
    );
  }

  final List<PatternItem> items;

  @override
  ActivityComponent get component => ActivityComponent.patternComplete;

  @override
  List<String> get referencedAssets =>
      [for (final item in items) ...item.referencedAssets];

  @override
  bool get isEmpty => items.isEmpty;
}


// ---------------------------------------------------------------------------
// word_builder
// ---------------------------------------------------------------------------

/// One word to assemble, and the tiles it is assembled from.
///
/// The pack writes English words as their letters (`["C","A","T"]`) and Urdu
/// words as romanised letter names (`["Alif","Bay"]`), the same convention the
/// tracing levels use. Names are kept as the identity and turned into script
/// at the point of drawing, so a tile shows ا and never the word "Alif".
class WordBuilderItem {
  const WordBuilderItem({required this.word, required this.tiles});

  factory WordBuilderItem.fromJson(Map<String, dynamic> json) {
    final raw = json['letter_tiles'];
    return WordBuilderItem(
      word: json['word'] as String? ?? '',
      tiles: raw is List
          ? raw.whereType<String>().where((tile) => tile.isNotEmpty).toList()
          : const [],
    );
  }

  /// The word as the pack writes it, used for the spoken prompt.
  final String word;

  /// The tiles in their solved order. The widget shuffles them for display;
  /// this list is the answer key.
  final List<String> tiles;

  bool get isPlayable => tiles.length >= 2;
}

/// Drag letter tiles into blank slots to build a word.
///
/// Carries no artwork: tiles and slots are drawn from the fonts the app
/// already ships, which is what lets the same component serve a 3-letter
/// English word and a 2-letter Urdu one. Right-to-left assembly comes from
/// [isRtl], so Urdu fills from the right without a second widget.
class WordBuilderData extends ActivityData {
  const WordBuilderData({
    required super.title,
    required super.isRtl,
    super.correctSound,
    super.wrongSound,
    required this.items,
  });

  factory WordBuilderData.fromJson(
    Map<String, dynamic> json, {
    required String title,
    required bool isRtl,
  }) {
    return WordBuilderData(
      title: title,
      isRtl: isRtl,
      correctSound: ActivityData.correctSoundOf(json),
      wrongSound: ActivityData.wrongSoundOf(json),
      items: ActivityData._items(json)
          .map(WordBuilderItem.fromJson)
          .where((item) => item.isPlayable)
          .toList(),
    );
  }

  final List<WordBuilderItem> items;

  @override
  ActivityComponent get component => ActivityComponent.wordBuilder;

  /// Nothing to load. The word is spoken by the device, and the tiles are
  /// glyphs.
  @override
  List<String> get referencedAssets => const [];

  @override
  bool get isEmpty => items.isEmpty;
}

// ---------------------------------------------------------------------------
// visual_math
// ---------------------------------------------------------------------------

/// One side of a sum: how many of a picture to draw.
class VisualMathOperand {
  const VisualMathOperand({required this.count, required this.image});

  factory VisualMathOperand.fromJson(Map<String, dynamic> json) {
    return VisualMathOperand(
      count: (json['count'] as num?)?.toInt() ?? 0,
      image: json['image'] as String? ?? '',
    );
  }

  final int count;
  final String image;
}

enum VisualMathOperation { add, subtract }

/// A sum shown as two groups of things rather than as digits.
class VisualMathItem {
  const VisualMathItem({
    required this.first,
    required this.second,
    required this.operation,
    required this.answer,
    required this.options,
  });

  factory VisualMathItem.fromJson(Map<String, dynamic> json) {
    final first = VisualMathOperand.fromJson(
      json['operand_1'] as Map<String, dynamic>? ?? const {},
    );
    final second = VisualMathOperand.fromJson(
      json['operand_2'] as Map<String, dynamic>? ?? const {},
    );
    final operation = (json['operation'] as String?) == 'subtract'
        ? VisualMathOperation.subtract
        : VisualMathOperation.add;
    final answer = (json['correct_answer'] as num?)?.toInt() ??
        (operation == VisualMathOperation.add
            ? first.count + second.count
            : first.count - second.count);

    return VisualMathItem(
      first: first,
      second: second,
      operation: operation,
      answer: answer,
      options: _optionsFor(answer),
    );
  }

  /// The pack gives the answer but no wrong answers, so the near misses are
  /// built here: a child who is counting should be able to get it right, and a
  /// child who is guessing should not have a one-in-two chance. Neighbours are
  /// used rather than random numbers because ±1 is exactly the mistake worth
  /// catching, and the order is fixed by value so the same sum always looks
  /// the same.
  static List<int> _optionsFor(int answer) {
    final options = <int>{answer};
    for (final delta in [1, -1, 2, -2, 3]) {
      if (options.length == 3) break;
      final candidate = answer + delta;
      if (candidate >= 0) options.add(candidate);
    }
    final ordered = options.toList()..sort();
    return ordered;
  }

  final VisualMathOperand first;
  final VisualMathOperand second;
  final VisualMathOperation operation;
  final int answer;

  /// Three choices including [answer], ordered smallest first.
  final List<int> options;

  bool get isPlayable => first.image.isNotEmpty && second.image.isNotEmpty;
}

/// Add or take away, counted off two groups of pictures.
class VisualMathData extends ActivityData {
  const VisualMathData({
    required super.title,
    required super.isRtl,
    super.correctSound,
    super.wrongSound,
    required this.items,
  });

  factory VisualMathData.fromJson(
    Map<String, dynamic> json, {
    required String title,
    required bool isRtl,
  }) {
    return VisualMathData(
      title: title,
      isRtl: isRtl,
      correctSound: ActivityData.correctSoundOf(json),
      wrongSound: ActivityData.wrongSoundOf(json),
      items: ActivityData._items(json)
          .map(VisualMathItem.fromJson)
          .where((item) => item.isPlayable)
          .toList(),
    );
  }

  final List<VisualMathItem> items;

  @override
  ActivityComponent get component => ActivityComponent.visualMath;

  @override
  List<String> get referencedAssets => [
        for (final item in items) ...[item.first.image, item.second.image],
      ];

  @override
  bool get isEmpty => items.isEmpty;
}

// ---------------------------------------------------------------------------
// maze
// ---------------------------------------------------------------------------

/// How big a generated maze is, and so how hard.
enum MazeDifficulty {
  easy(5),
  medium(7),
  hard(9);

  const MazeDifficulty(this.size);

  /// Cells per side. Odd on purpose: the generator carves walls between cells,
  /// which needs an odd grid to end on a wall.
  final int size;

  static MazeDifficulty fromJson(String? raw) => switch (raw) {
        'easy' => MazeDifficulty.easy,
        'hard' => MazeDifficulty.hard,
        _ => MazeDifficulty.medium,
      };
}

/// One maze to walk, described by size rather than by a drawn layout.
class MazeItem {
  const MazeItem({
    required this.difficulty,
    required this.character,
    required this.seed,
  });

  factory MazeItem.fromJson(Map<String, dynamic> json, {required int index}) {
    return MazeItem(
      difficulty: MazeDifficulty.fromJson(json['difficulty'] as String?),
      character: json['character_image'] as String? ?? '',
      // Fixed rather than random so a child who leaves and comes back gets the
      // maze they were solving, and so the widget can be tested at all.
      seed: 1789 + index * 97,
    );
  }

  final MazeDifficulty difficulty;

  /// The sprite dragged through the maze — an existing picture, so a maze
  /// costs no new artwork.
  final String character;

  final int seed;

  bool get isPlayable => character.isNotEmpty;
}

/// Drag a character from one corner of a generated maze to the other.
class MazeData extends ActivityData {
  const MazeData({
    required super.title,
    required super.isRtl,
    super.correctSound,
    super.wrongSound,
    required this.items,
  });

  factory MazeData.fromJson(
    Map<String, dynamic> json, {
    required String title,
    required bool isRtl,
  }) {
    final raw = ActivityData._items(json);
    return MazeData(
      title: title,
      isRtl: isRtl,
      correctSound: ActivityData.correctSoundOf(json),
      wrongSound: ActivityData.wrongSoundOf(json),
      items: [
        for (var i = 0; i < raw.length; i++) MazeItem.fromJson(raw[i], index: i),
      ].where((item) => item.isPlayable).toList(),
    );
  }

  final List<MazeItem> items;

  @override
  ActivityComponent get component => ActivityComponent.maze;

  @override
  List<String> get referencedAssets => [
        for (final item in items) item.character,
      ];

  @override
  bool get isEmpty => items.isEmpty;
}

// ---------------------------------------------------------------------------
// memory_match
// ---------------------------------------------------------------------------

/// One board of face-down cards.
class MemoryMatchItem {
  const MemoryMatchItem({required this.faces, required this.columns});

  factory MemoryMatchItem.fromJson(Map<String, dynamic> json) {
    final raw = json['card_pairs'];
    final faces = raw is List
        ? raw.whereType<String>().where((path) => path.isNotEmpty).toList()
        : <String>[];
    return MemoryMatchItem(
      faces: faces,
      columns: _columnsOf(json['grid_size'] as String?, faces.length * 2),
    );
  }

  /// `"4x3"` means four across. Falls back to a column count that keeps the
  /// board close to square, so a pack that omits the size still lays out.
  static int _columnsOf(String? raw, int cardCount) {
    final match = RegExp(r'^(\d+)\s*[xX]\s*(\d+)$').firstMatch(raw ?? '');
    if (match != null) return int.parse(match.group(1)!);
    if (cardCount <= 4) return 2;
    if (cardCount <= 12) return 4;
    return 5;
  }

  /// One path per pair; each is dealt twice.
  final List<String> faces;
  final int columns;

  bool get isPlayable => faces.length >= 2;
}

/// Turn two cards at a time and remember where the pictures were.
class MemoryMatchData extends ActivityData {
  const MemoryMatchData({
    required super.title,
    required super.isRtl,
    super.correctSound,
    super.wrongSound,
    required this.items,
  });

  factory MemoryMatchData.fromJson(
    Map<String, dynamic> json, {
    required String title,
    required bool isRtl,
  }) {
    return MemoryMatchData(
      title: title,
      isRtl: isRtl,
      correctSound: ActivityData.correctSoundOf(json),
      wrongSound: ActivityData.wrongSoundOf(json),
      items: ActivityData._items(json)
          .map(MemoryMatchItem.fromJson)
          .where((item) => item.isPlayable)
          .toList(),
    );
  }

  final List<MemoryMatchItem> items;

  @override
  ActivityComponent get component => ActivityComponent.memoryMatch;

  @override
  List<String> get referencedAssets => [
        for (final item in items) ...item.faces,
      ];

  @override
  bool get isEmpty => items.isEmpty;
}
