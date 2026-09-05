import '../../models/activity_data.dart';
import '../../models/activity_option.dart';
import '../../models/activity_pack.dart';
import '../../models/module_quiz.dart';

/// Builds a module's closing quiz out of the activities the child just played.
///
/// Nothing here is authored. Asking a content team to write a quiz for every
/// module of every age pack is a second curriculum to keep in step with the
/// first, and it would drift the moment a level changed. Instead the quiz is
/// derived: a pack round already states a question and marks one option
/// correct, which is exactly what a quiz slide needs.
///
/// Only rounds with a real right answer are usable. Tracing, puzzles and the
/// sight-word cards have nothing to get wrong, so they contribute nothing and
/// a module made only of those gets no quiz at all.
class ModuleQuizBuilder {
  const ModuleQuizBuilder._();

  /// Assembles the quiz for [module], or an empty quiz when its activities
  /// cannot supply [ModuleQuiz.minQuestions] usable questions.
  static ModuleQuiz build(ActivityModule module) {
    final perLevel = <List<ModuleQuizQuestion>>[];

    for (final level in module.levels) {
      final seeds = _seedsFor(level.data);
      final questions = <ModuleQuizQuestion>[];

      for (var index = 0; index < seeds.length; index++) {
        final question = seeds[index].toQuestion(
          id: '${module.key}-${level.key}-$index',
          isRtl: level.data.isRtl,
        );
        if (question != null) questions.add(question);
      }

      if (questions.isNotEmpty) perLevel.add(questions);
    }

    final picked = _spreadAcrossLevels(perLevel, ModuleQuiz.targetQuestions);
    if (picked.length < ModuleQuiz.minQuestions) {
      return const ModuleQuiz.empty();
    }

    return ModuleQuiz(moduleTitle: module.title, questions: picked);
  }

  /// Takes one question from each level before taking a second from any, so a
  /// five-slide quiz covers the whole module instead of drilling into whichever
  /// level happened to have the most rounds.
  static List<ModuleQuizQuestion> _spreadAcrossLevels(
    List<List<ModuleQuizQuestion>> perLevel,
    int limit,
  ) {
    final picked = <ModuleQuizQuestion>[];
    var round = 0;
    var tookOne = true;

    while (picked.length < limit && tookOne) {
      tookOne = false;
      for (final level in perLevel) {
        if (picked.length >= limit) break;
        if (round >= level.length) continue;
        picked.add(level[round]);
        tookOne = true;
      }
      round++;
    }

    return picked;
  }

  /// The rounds that can become a question, per component.
  ///
  /// A round is usable when it offers a choice and names a winner. Components
  /// absent from this switch — tracing, puzzle, drag-and-match, sort-into-zones,
  /// listen-and-see, story and counting — are either open-ended or scored by
  /// something other than picking an option.
  static List<_QuizSeed> _seedsFor(ActivityData data) {
    return switch (data) {
      TwoChoiceTapData d => [
          for (final item in d.items)
            _QuizSeed(
              prompt: item.promptText,
              fallbackPrompt: 'Which one is right?',
              options: item.options,
            ),
        ],
      IdentifyAndTapData d => [
          for (final item in d.items)
            _QuizSeed(
              prompt: item.promptText,
              fallbackPrompt: 'Tap the right one.',
              promptImage: item.promptImage,
              options: item.options,
            ),
        ],
      OddOneOutData d => [
          for (final item in d.items)
            _QuizSeed(
              prompt: item.promptText,
              fallbackPrompt: 'Which one does not belong?',
              options: item.options,
            ),
        ],
      ShadowMatchData d => [
          for (final item in d.items)
            _QuizSeed(
              prompt: null,
              fallbackPrompt: 'Which shadow matches?',
              promptImage: item.objectImage,
              options: item.options,
            ),
        ],
      PatternCompleteData d => [
          for (final item in d.items)
            _QuizSeed(
              prompt: null,
              fallbackPrompt: 'What comes next?',
              options: item.options,
            ),
        ],
      DragAndMatchData d => _dragMatchSeeds(d),
      SortIntoZonesData d => _sortIntoZonesSeeds(d),
      TapToCountData d => _tapToCountSeeds(d),
      _ => const [],
    };
  }

  /// A counting round becomes "how many do you see?", with the picture drawn
  /// as many times as the round asks the child to count.
  static List<_QuizSeed> _tapToCountSeeds(TapToCountData data) {
    return [
      for (final item in data.items)
        if (item.objectImage != null && item.targetCount > 0)
          _QuizSeed(
            prompt: null,
            fallbackPrompt: 'How many do you see?',
            promptImage: item.objectImage,
            promptRepeat: item.targetCount,
            options: _countOptions(item.targetCount),
          ),
    ];
  }

  /// Three numbers around [answer], in order, never dropping below one. Kept
  /// adjacent so the child has to count rather than eliminate a wild guess.
  static List<ActivityOption> _countOptions(int answer) {
    final numbers = <int>{answer};
    for (var delta = 1; numbers.length < 3; delta++) {
      if (answer - delta >= 1) numbers.add(answer - delta);
      if (numbers.length < 3) numbers.add(answer + delta);
    }

    final sorted = numbers.toList()..sort();
    return [
      for (final number in sorted)
        ActivityOption(label: '$number', isCorrect: number == answer),
    ];
  }

  /// A drag-and-match round is a matching question in disguise: each pair ties
  /// one letter to one picture, so the other pairs' pictures are ready-made
  /// wrong answers.
  ///
  /// Without this the age-3 pack has almost no quiz at all - it is mostly
  /// tracing and dragging, and only one round in the whole file is a plain
  /// tap-the-right-one.
  static List<_QuizSeed> _dragMatchSeeds(DragAndMatchData data) {
    final pairs = data.pairs
        .where((pair) => pair.image != null && pair.letter.isNotEmpty)
        .toList();
    if (pairs.length < 2) return const [];

    return [
      for (final pair in pairs)
        _QuizSeed(
          prompt: 'Which picture goes with ${pair.letter}?',
          fallbackPrompt: 'Which picture matches?',
          options: [
            for (final candidate in _withDistractors(pairs, pair))
              ActivityOption(
                image: candidate.image,
                isCorrect: candidate.id == pair.id,
              ),
          ],
        ),
    ];
  }

  /// The answer plus up to three others, in pack order. Four squares is as
  /// much as a small child can weigh at once, and as much as the option grid
  /// shows without scrolling.
  static List<DragMatchPair> _withDistractors(
    List<DragMatchPair> pairs,
    DragMatchPair answer,
  ) {
    if (pairs.length <= 4) return pairs;
    final others = pairs.where((pair) => pair.id != answer.id).take(3);
    return [
      for (final pair in pairs)
        if (pair.id == answer.id || others.contains(pair)) pair,
    ];
  }

  /// A sort round already knows which zone each thing belongs in, so "where
  /// does this go?" is the question the activity was asking anyway.
  static List<_QuizSeed> _sortIntoZonesSeeds(SortIntoZonesData data) {
    final zones = data.zones;
    if (zones.length < 2) return const [];

    return [
      for (final item in data.items)
        if (item.image != null &&
            zones.any((zone) => zone.key == item.zoneKey))
          _QuizSeed(
            prompt: null,
            fallbackPrompt: 'Where does this go?',
            promptImage: item.image,
            options: [
              for (final zone in zones)
                ActivityOption(
                  // A zone is drawn by its backdrop where the pack supplies
                  // one, and named otherwise.
                  label: zone.background == null ? _zoneLabel(zone.key) : null,
                  image: zone.background,
                  isCorrect: zone.key == item.zoneKey,
                ),
            ],
          ),
    ];
  }

  static String _zoneLabel(String key) => key
      .split(RegExp(r'[_\-]'))
      .where((word) => word.isNotEmpty)
      .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');
}

/// A pack round on its way to becoming a quiz slide.
class _QuizSeed {
  const _QuizSeed({
    required this.prompt,
    required this.fallbackPrompt,
    required this.options,
    this.promptImage,
    this.promptRepeat = 1,
  });

  /// The pack's own wording, when it has one. Many rounds ask the question
  /// only in audio, which a quiz slide cannot show.
  final String? prompt;
  final String fallbackPrompt;
  final String? promptImage;
  final int promptRepeat;
  final List<ActivityOption> options;

  /// Null when the round has nothing to test: fewer than two choices, or no
  /// option marked correct.
  ModuleQuizQuestion? toQuestion({required String id, required bool isRtl}) {
    if (options.length < 2) return null;

    final correctIndex = options.indexWhere((option) => option.isCorrect);
    if (correctIndex < 0) return null;

    // An option the child cannot see is not a choice. The big-versus-small
    // round points both options at one picture and separates them by scale,
    // which a static quiz slide cannot convey, so it is skipped here.
    final renderable = options.every(
      (option) => option.label != null || option.image != null,
    );
    if (!renderable) return null;
    if (options.any((option) => option.scale != 1)) return null;

    final text = prompt?.trim();
    return ModuleQuizQuestion(
      id: id,
      prompt: text == null || text.isEmpty ? fallbackPrompt : text,
      promptImage: promptImage,
      promptRepeat: promptRepeat,
      options: options,
      correctIndex: correctIndex,
      isRtl: isRtl,
    );
  }
}
