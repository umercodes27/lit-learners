import '../../core/localization/urdu_letters.dart';
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
              fallbackPrompt: item.options.any((option) => option.count > 1)
                  ? _Ask.whichMore
                  : _Ask.whichOne,
              options: item.options,
              audioPrompt: item.audioPrompt,
            ),
        ],
      IdentifyAndTapData d => [
          for (final item in d.items)
            _QuizSeed(
              prompt: item.promptText,
              fallbackPrompt: _Ask.tapRight,
              promptImage: item.promptImage,
              options: item.options,
              audioPrompt: item.audioPrompt,
            ),
        ],
      OddOneOutData d => [
          for (final item in d.items)
            _QuizSeed(
              prompt: item.promptText,
              fallbackPrompt: _Ask.oddOne,
              options: item.options,
              audioPrompt: item.audioPrompt,
            ),
        ],
      ShadowMatchData d => [
          for (final item in d.items)
            _QuizSeed(
              prompt: null,
              fallbackPrompt: _Ask.whichShadow,
              promptImage: item.objectImage,
              options: item.options,
              audioPrompt: item.audioPrompt,
            ),
        ],
      PatternCompleteData d => [
          for (final item in d.items)
            _QuizSeed(
              prompt: null,
              fallbackPrompt: _Ask.whatNext,
              options: item.options,
            ),
        ],
      // A sum is already a multiple-choice question — it has an answer and
      // three numbers to pick from — so it makes the most direct quiz slide in
      // the file.
      VisualMathData d => [
          for (final item in d.items)
            _QuizSeed(
              prompt: null,
              fallbackPrompt: item.operation == VisualMathOperation.add
                  ? _Ask.howManyAltogether
                  : _Ask.howManyLeft,
              options: [
                for (final option in item.options)
                  ActivityOption(
                    label: '$option',
                    isCorrect: option == item.answer,
                  ),
              ],
            ),
        ],
      // The question a story already stopped to ask. Without this the
      // storytelling module had no quiz in any pack, so its trophy was never
      // more than decoration.
      StoryInteractiveData d => [
          if (d.choicePoint != null && d.choicePoint!.options.length >= 2)
            _QuizSeed(
              prompt: d.choicePoint!.promptText,
              fallbackPrompt: _Ask.whichOne,
              options: d.choicePoint!.options,
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
            fallbackPrompt: _Ask.howMany,
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
          prompt: _Ask.goesWith(pair.letter),
          fallbackPrompt: _Ask.whichPicture,
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
            fallbackPrompt: _Ask.whereGoes,
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
    this.audioPrompt,
  });

  /// The pack's own wording, when it has one. Many rounds ask the question
  /// only in audio, which a quiz slide cannot show.
  /// Both wordings of the stock question. Which one is asked is decided by the
  /// level, not by the seed, because only the level knows its script.
  final _Ask fallbackPrompt;

  final String? prompt;
  final String? promptImage;
  final int promptRepeat;
  final List<ActivityOption> options;

  /// The round's own recording, reused so the quiz asks in the same voice the
  /// level did.
  final String? audioPrompt;

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
      prompt: text == null || text.isEmpty
          ? fallbackPrompt.forAnswer(options, correctIndex, isRtl: isRtl)
          : text,
      promptImage: promptImage,
      promptRepeat: promptRepeat,
      options: options,
      correctIndex: correctIndex,
      isRtl: isRtl,
      audioPrompt: audioPrompt,
    );
  }
}

/// The stock questions a generated quiz asks, in both scripts.
///
/// A quiz that closes the Urdu module used to ask "Tap the right one." in
/// English and then offer ا and ب as the answers — a question a child who
/// cannot read English has to answer in a script the question was not written
/// in. The quiz now asks in the language of the module it closes.
///
/// Only the stock wordings live here. A round that carries its own prompt из
/// the pack keeps it, whatever language that is.
class _Ask {
  const _Ask(this.english, this.urdu, {this.direct = false});

  final String english;
  final String urdu;

  /// Whether this question reads better with the answer named in it.
  ///
  /// "Which one is right?" over a C and a D tells a two-year-old nothing about
  /// what to look for; "Where is C?" is the question the level was already
  /// asking out loud, in `where_is_C.mp3`. The same goes for a row of shapes.
  ///
  /// Off for anything where naming the answer *is* the answer: a counting
  /// slide must never ask "Where is 3?", and "which one does not belong" and
  /// "which shadow matches" are about the relationship, not the name.
  final bool direct;

  String forDirection({required bool isRtl}) => isRtl ? urdu : english;

  /// The question, made specific when it can be and when it should be.
  String forAnswer(
    List<ActivityOption> options,
    int correctIndex, {
    required bool isRtl,
  }) {
    if (!direct) return forDirection(isRtl: isRtl);
    final name = _nameOf(options[correctIndex]);
    if (name == null) return forDirection(isRtl: isRtl);

    // Naming the answer only helps if the name picks one option out. The
    // more-versus-less round draws the same apple on both plates and differs
    // only in how many, so "Where is the apple?" would have two right answers.
    for (var i = 0; i < options.length; i++) {
      if (i != correctIndex && _nameOf(options[i]) == name) {
        return forDirection(isRtl: isRtl);
      }
    }

    return isRtl ? '$name کہاں ہے؟' : 'Where is $name?';
  }

  /// What to call the right answer, or null when it cannot be named.
  ///
  /// A label is used as written, except that an Urdu letter name becomes its
  /// glyph — the packs write "Bay" as an identifier and the child is learning
  /// ب. A picture is named from its own filename, which is how the artwork is
  /// already described: `blue_square.png` is a blue square.
  static String? _nameOf(ActivityOption answer) {
    final label = answer.label?.trim();
    if (label != null && label.isNotEmpty) {
      return UrduLetters.glyphFor(label) ?? label;
    }

    final image = answer.image;
    if (image == null || image.isEmpty) return null;

    var file = image.split('/').last;
    final dot = file.lastIndexOf('.');
    if (dot > 0) file = file.substring(0, dot);

    final words = file
        .split(RegExp(r'[_\-]'))
        .where((word) => word.isNotEmpty)
        .toList();
    if (words.isEmpty) return null;

    // Artwork is named subject-first — ball_red, ball_big — but it is spoken
    // the other way round, so a trailing adjective moves to the front.
    const adjectives = {
      'red', 'blue', 'green', 'yellow', 'orange', 'purple', 'pink',
      'black', 'white', 'brown', 'big', 'small', 'large', 'little',
    };
    if (words.length > 1 && adjectives.contains(words.last.toLowerCase())) {
      words.insert(0, words.removeLast());
    }

    final name = words.join(' ').toLowerCase();
    // "Where is A?", but "Where is the blue square?"
    return name.length <= 2 ? name.toUpperCase() : 'the $name';
  }

  static const whichOne =
      _Ask('Which one is right?', 'درست کون سا ہے؟', direct: true);
  static const tapRight =
      _Ask('Tap the right one.', 'درست پر ٹیپ کریں۔', direct: true);
  static const oddOne =
      _Ask('Which one does not belong?', 'کون سا الگ ہے؟');
  static const whichShadow =
      _Ask('Which shadow matches?', 'کون سا سایہ ملتا ہے؟');
  // Age 2 and 3 reviewers both flagged this as too abstract: a row of
  // shapes and "what comes next?" asks a toddler to infer a rule. Named,
  // it becomes "Where is the blue square?" — the same tap, a question they
  // can act on.
  static const whatNext =
      _Ask('What comes next?', 'آگے کیا آئے گا؟', direct: true);
  static const howMany = _Ask('How many do you see?', 'کتنے ہیں؟');
  static const whichPicture =
      _Ask('Which picture matches?', 'کون سی تصویر ملتی ہے؟');
  static const whereGoes = _Ask('Where does this go?', 'یہ کہاں جائے گا؟');
  static const howManyAltogether =
      _Ask('How many altogether?', 'سب ملا کر کتنے؟');
  static const howManyLeft = _Ask('How many are left?', 'کتنے باقی بچے؟');
  static const whichMore = _Ask('Which one has more?', 'زیادہ کس میں ہیں؟');

  /// The letter is drawn in its own script either way, so only the sentence
  /// around it changes.
  static String goesWith(String letter) {
    final glyph = UrduLetters.glyphFor(letter) ?? letter;
    return UrduLetters.glyphFor(letter) != null
        ? 'کون سی تصویر $glyph کے ساتھ ہے؟'
        : 'Which picture goes with $glyph?';
  }
}
