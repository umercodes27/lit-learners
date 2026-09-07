import '../../models/content_item.dart';
import '../../models/learning_level.dart';
import '../../models/learning_module.dart';
import '../../models/parent_mark.dart';
import '../../models/quiz_question.dart';
import '../content/asset_availability.dart';

/// Whether an issue stops a draft being saved, or merely warns about it.
enum DraftSeverity {
  /// The level would be broken in the app. It cannot be approved.
  blocking,

  /// The level works, but is probably not what the admin meant.
  warning,
}

/// Every way a generated level can be wrong.
///
/// One value per rule so tests can assert on the rule rather than on prose,
/// and so the review screen can group issues without parsing messages.
enum DraftRule {
  /// Not a content problem: the model's reply could not be parsed at all.
  unreadableReply,
  wrongLevelCount,
  levelTitleEmpty,
  levelSubtitleEmpty,
  passingScoreOutOfRange,
  canvasPassingScoreOutOfBand,
  contentItemsEmpty,
  contentFieldEmpty,
  tracingGlyphNotSingleRune,
  tracingGlyphUnsupportedScript,
  countingDisplayTextNotInteger,
  countingTargetTooHigh,
  matchingNeedsTwoDistinctTitles,
  videoLessonsMissing,
  videoUrlNotPlayable,
  videoAssetMissing,
  videoDurationLabelMalformed,
  quizTooFewOptions,
  quizCorrectIndexOutOfRange,
  quizIdDuplicated,
  levelNumberNotConsecutive,
  levelIdCollision,
  moduleIdNotACategory,
  portionLabelMalformed,
  scriptMismatch,
  duplicateLevelTitle,
}

/// One problem with one field of one draft.
class DraftIssue {
  const DraftIssue({
    required this.rule,
    required this.severity,
    required this.path,
    required this.message,
    required this.modelHint,
  });

  final DraftRule rule;
  final DraftSeverity severity;

  /// Where the problem is, e.g. `levels[2].contentItems[1].displayText`.
  /// Shown to the admin and fed back to the model on a repair round.
  final String path;

  /// One sentence, written for the admin reading the review screen.
  final String message;

  /// The same problem stated as an imperative, written for the model. Fed
  /// back verbatim, so it says what to do rather than what went wrong.
  final String modelHint;

  bool get isBlocking => severity == DraftSeverity.blocking;

  @override
  String toString() => '$path: $message';
}

class DraftValidationResult {
  const DraftValidationResult(this.issues);

  const DraftValidationResult.clean() : issues = const [];

  final List<DraftIssue> issues;

  bool get isBlocked => issues.any((issue) => issue.isBlocking);

  List<DraftIssue> get blocking =>
      issues.where((issue) => issue.isBlocking).toList();

  List<DraftIssue> get warnings =>
      issues.where((issue) => !issue.isBlocking).toList();
}

/// Checks a generated level against every rule the app relies on but the
/// admin form never enforced.
///
/// These are not style preferences. Each one corresponds to something that
/// breaks in front of a child: a glyph that will not rasterise, a counting
/// target that silently becomes one, a quiz that teaches the wrong answer, a
/// numbering gap that locks the rest of the module forever.
///
/// Every rule here is already asserted somewhere in `test/` against the
/// content that ships in `seed_content.dart`. The golden test in
/// `content_draft_validator_test.dart` runs this validator over all of that
/// content and requires zero blocking issues: if the validator ever disagrees
/// with a level the app already ships, the validator is what is wrong.
class ContentDraftValidator {
  const ContentDraftValidator();

  /// Drawing and tracing are graded by a grown-up, not by the app, and the
  /// four [ParentMark] grades are chosen so exactly one of them fails. That
  /// only holds if the passing score sits above the failing grade and at or
  /// below the next one, so the band is derived from the grades rather than
  /// typed as a number that could drift away from them.
  static final int canvasMinPassingScore = ParentMark.needsPractice.score + 1;
  static final int canvasMaxPassingScore = ParentMark.goodTry.score;

  static final RegExp _durationLabel = RegExp(r'^\d{1,2}:\d{2}$');

  /// What the video player treats as a bundled file rather than an
  /// address. Kept in step with the check in [VideoPlayerPage].
  static const _assetPrefix = 'assets/';
  static final RegExp _arabicScript = RegExp(r'[؀-ۿ]');

  /// The scripts the app can actually draw a tracing guide for: Fredoka
  /// covers Latin letters and digits, NotoNastaliqUrdu covers Arabic script.
  /// A rune outside both renders as tofu and the guide comes out empty.
  static final RegExp _traceableGlyph = RegExp(r'^[A-Za-z0-9؀-ۿ]$');

  DraftValidationResult validateLevel(
    LearningLevel level, {
    required String path,
  }) {
    final issues = <DraftIssue>[
      ..._common(level, path),
      // A switch expression, not a statement: adding an eighth LevelType then
      // fails to compile here instead of silently skipping validation.
      ...switch (level.type) {
        LevelType.flashcards => _requireCards(level, path),
        LevelType.story => _requireCards(level, path),
        LevelType.counting => _counting(level, path),
        LevelType.matching => _matching(level, path),
        LevelType.drawing => _canvas(level, path),
        LevelType.tracing => _tracing(level, path),
        LevelType.video => _video(level, path),
      },
    ];
    return DraftValidationResult(issues);
  }

  List<DraftIssue> _common(LearningLevel level, String path) {
    final issues = <DraftIssue>[];

    if (level.title.trim().isEmpty) {
      issues.add(DraftIssue(
        rule: DraftRule.levelTitleEmpty,
        severity: DraftSeverity.blocking,
        path: '$path.title',
        message: 'This level has no title.',
        modelHint: 'Give every level a short title a parent would recognise.',
      ));
    }
    if (level.subtitle.trim().isEmpty) {
      issues.add(DraftIssue(
        rule: DraftRule.levelSubtitleEmpty,
        severity: DraftSeverity.blocking,
        path: '$path.subtitle',
        message: 'This level has no subtitle.',
        modelHint: 'Give every level a one-line subtitle saying what the '
            'child will do.',
      ));
    }
    if (level.passingScore < 0 || level.passingScore > 100) {
      issues.add(DraftIssue(
        rule: DraftRule.passingScoreOutOfRange,
        severity: DraftSeverity.blocking,
        path: '$path.passingScore',
        message: 'Passing score ${level.passingScore} is outside 0-100.',
        modelHint: 'passingScore must be a whole number between 0 and 100.',
      ));
    }

    for (var i = 0; i < level.contentItems.length; i++) {
      issues.addAll(_contentFields(level.contentItems[i], '$path.contentItems[$i]'));
    }
    for (var i = 0; i < level.quizQuestions.length; i++) {
      issues.addAll(_quiz(level.quizQuestions[i], '$path.quizQuestions[$i]'));
    }
    return issues;
  }

  List<DraftIssue> _contentFields(ContentItem item, String path) {
    final issues = <DraftIssue>[];
    final fields = <String, String>{
      'title': item.title,
      'prompt': item.prompt,
      'displayText': item.displayText,
      'visualLabel': item.visualLabel,
    };
    fields.forEach((name, value) {
      if (value.trim().isEmpty) {
        issues.add(DraftIssue(
          rule: DraftRule.contentFieldEmpty,
          severity: DraftSeverity.blocking,
          path: '$path.$name',
          message: 'Card $name is empty.',
          modelHint: 'Every card needs a non-empty title, prompt, displayText '
              'and visualLabel.',
        ));
      }
    });
    return issues;
  }

  List<DraftIssue> _quiz(QuizQuestion question, String path) {
    final issues = <DraftIssue>[];
    if (question.options.length < 2) {
      issues.add(DraftIssue(
        rule: DraftRule.quizTooFewOptions,
        severity: DraftSeverity.blocking,
        path: '$path.options',
        message: 'A question with ${question.options.length} option(s) is not '
            'a choice.',
        modelHint: 'Every quiz question needs at least 2 options.',
      ));
    }
    if (question.correctIndex < 0 ||
        question.correctIndex >= question.options.length) {
      issues.add(DraftIssue(
        rule: DraftRule.quizCorrectIndexOutOfRange,
        severity: DraftSeverity.blocking,
        path: '$path.correctIndex',
        message: 'correctIndex ${question.correctIndex} does not point at one '
            'of the ${question.options.length} options.',
        modelHint: 'correctIndex must be between 0 and options.length - 1, and '
            'must point at the option that actually answers the prompt.',
      ));
    }
    return issues;
  }

  /// Any level the player walks card by card needs at least one card:
  /// `LevelActivityViewModel.currentItem` indexes the list directly, so an
  /// empty level is a RangeError the moment a child opens it.
  List<DraftIssue> _requireCards(LearningLevel level, String path) {
    if (level.contentItems.isNotEmpty) return const [];
    return [
      DraftIssue(
        rule: DraftRule.contentItemsEmpty,
        severity: DraftSeverity.blocking,
        path: '$path.contentItems',
        message: 'This level has no cards, so it would crash when opened.',
        modelHint: 'Every level except a video level needs at least one entry '
            'in contentItems.',
      ),
    ];
  }

  List<DraftIssue> _counting(LearningLevel level, String path) {
    final issues = <DraftIssue>[..._requireCards(level, path)];
    for (var i = 0; i < level.contentItems.length; i++) {
      final text = level.contentItems[i].displayText.trim();
      final target = int.tryParse(text);
      final at = '$path.contentItems[$i].displayText';

      if (target == null || target < 1) {
        // The player does `int.tryParse(displayText) ?? 1`, so a word here
        // does not fail loudly — it quietly asks the child to count to one.
        issues.add(DraftIssue(
          rule: DraftRule.countingDisplayTextNotInteger,
          severity: DraftSeverity.blocking,
          path: at,
          message: '"$text" is not a counting target, so the level would '
              'silently ask for 1.',
          modelHint: 'On a counting level, displayText must be the digits of '
              'the number to count, like "3". Not "three". Not "3 apples".',
        ));
      } else if (target > 12) {
        issues.add(DraftIssue(
          rule: DraftRule.countingTargetTooHigh,
          severity: DraftSeverity.warning,
          path: at,
          message: 'Counting to $target is a lot of taps for this age.',
          modelHint: 'Keep counting targets at 12 or below.',
        ));
      }
    }
    return issues;
  }

  /// On a matching level the choices a child picks from are the card *titles*
  /// themselves. One distinct title means one option, which is not a choice.
  List<DraftIssue> _matching(LearningLevel level, String path) {
    final issues = <DraftIssue>[..._requireCards(level, path)];
    final distinct =
        level.contentItems.map((item) => item.title.trim()).toSet();
    if (level.contentItems.isNotEmpty && distinct.length < 2) {
      issues.add(DraftIssue(
        rule: DraftRule.matchingNeedsTwoDistinctTitles,
        severity: DraftSeverity.blocking,
        path: '$path.contentItems',
        message: 'A matching level needs at least two different card titles — '
            'the titles are the options the child chooses between.',
        modelHint: 'On a matching level the card titles become the answer '
            'choices, so give the level at least 2 cards with different '
            'titles.',
      ));
    }
    return issues;
  }

  List<DraftIssue> _canvas(LearningLevel level, String path) => [
        ..._requireCards(level, path),
        ..._canvasScore(level, path),
      ];

  List<DraftIssue> _canvasScore(LearningLevel level, String path) {
    if (level.passingScore >= canvasMinPassingScore &&
        level.passingScore <= canvasMaxPassingScore) {
      return const [];
    }
    return [
      DraftIssue(
        rule: DraftRule.canvasPassingScoreOutOfBand,
        severity: DraftSeverity.blocking,
        path: '$path.passingScore',
        message: 'A grown-up grades this level, and the four grades are worth '
            '45, 70, 85 and 100. At ${level.passingScore} '
            '${level.passingScore < canvasMinPassingScore ? "every grade passes" : "more than one grade fails"}.',
        modelHint: 'Drawing and tracing levels must have a passingScore '
            'between $canvasMinPassingScore and $canvasMaxPassingScore.',
      ),
    ];
  }

  List<DraftIssue> _tracing(LearningLevel level, String path) {
    final issues = <DraftIssue>[
      ..._requireCards(level, path),
      ..._canvasScore(level, path),
    ];

    for (var i = 0; i < level.contentItems.length; i++) {
      final glyph = level.contentItems[i].displayText.trim();
      final at = '$path.contentItems[$i].displayText';

      if (glyph.runes.length != 1) {
        issues.add(DraftIssue(
          rule: DraftRule.tracingGlyphNotSingleRune,
          severity: DraftSeverity.blocking,
          path: at,
          message: '"$glyph" is ${glyph.runes.length} characters. A tracing '
              'guide is drawn from exactly one.',
          modelHint: 'On a tracing level, displayText must be exactly one '
              'character. Not "AB". Not "A B". One character.',
        ));
      } else if (!_traceableGlyph.hasMatch(glyph)) {
        issues.add(DraftIssue(
          rule: DraftRule.tracingGlyphUnsupportedScript,
          severity: DraftSeverity.blocking,
          path: at,
          message: 'The app has no font that can draw a "$glyph" guide, so the '
              'child would get an empty page.',
          modelHint: 'A tracing character must be a Latin letter, a digit, or '
              'an Urdu letter. No emoji, no punctuation, no other scripts.',
        ));
      }
    }
    return issues;
  }

  List<DraftIssue> _video(LearningLevel level, String path) {
    if (level.videoLessons.isEmpty) {
      return [
        DraftIssue(
          rule: DraftRule.videoLessonsMissing,
          severity: DraftSeverity.blocking,
          path: '$path.videoLessons',
          message: 'A video level with no video cannot be opened.',
          modelHint: 'A video level needs at least one entry in videoLessons.',
        ),
      ];
    }

    final issues = <DraftIssue>[];
    for (var i = 0; i < level.videoLessons.length; i++) {
      final lesson = level.videoLessons[i];
      final source = lesson.videoUrl.trim();

      // Two shapes are legal because [VideoPlayerPage] opens two: a file
      // bundled with the app, and a remote address for lessons an admin
      // publishes through Firestore. Anything else reaches
      // `VideoPlayerController.networkUrl` and fails there.
      if (source.startsWith(_assetPrefix)) {
        // A bundled path that is not in the bundle is the worse failure of
        // the two: there is no network to blame, it breaks identically on
        // every device, and no admin can fix it without a new release. The
        // registry stays optimistic until something populates it, so an
        // unpopulated manifest reports nothing rather than condemning every
        // path — the same bargain [AssetAvailability] makes everywhere else.
        if (AssetAvailability.instance.isKnown &&
            !AssetAvailability.instance.has(source)) {
          issues.add(DraftIssue(
            rule: DraftRule.videoAssetMissing,
            severity: DraftSeverity.blocking,
            path: '$path.videoLessons[$i].videoUrl',
            message: '"$source" is not a file this app ships.',
            modelHint: 'Only name a bundled video that already exists. You '
                'cannot add files to the app, so a path you invented will '
                'never play.',
          ));
        }
      } else {
        final uri = Uri.tryParse(source);
        final playable = uri != null &&
            uri.hasAuthority &&
            (uri.scheme == 'http' || uri.scheme == 'https');
        if (!playable) {
          issues.add(DraftIssue(
            rule: DraftRule.videoUrlNotPlayable,
            severity: DraftSeverity.blocking,
            path: '$path.videoLessons[$i].videoUrl',
            message: '"$source" is neither a bundled asset nor a URL the '
                'player can open.',
            modelHint: 'videoUrl must be a full http:// or https:// address '
                'to a video file. Never invent one — leave videoLessons '
                'empty and choose a different level type if you have no real '
                'URL.',
          ));
        }
      }
      if (!_durationLabel.hasMatch(lesson.durationLabel.trim())) {
        issues.add(DraftIssue(
          rule: DraftRule.videoDurationLabelMalformed,
          severity: DraftSeverity.warning,
          path: '$path.videoLessons[$i].durationLabel',
          message: 'Duration "${lesson.durationLabel}" is not in m:ss form.',
          modelHint: 'durationLabel looks like "0:30".',
        ));
      }
    }
    return issues;
  }

  /// Checks the whole batch together.
  ///
  /// Some rules only exist between levels — a numbering gap, a clashing id, a
  /// repeated title — and those are exactly the ones that a level-at-a-time
  /// workflow lets through and a child hits weeks later.
  DraftValidationResult validateStage(
    List<LearningLevel> levels, {
    required int expectedLevelCount,
    required int expectedFirstLevelNumber,
    Set<String> existingLevelIds = const {},
    Set<String> existingQuizIds = const {},
    Set<String> existingTitles = const {},
  }) {
    final issues = <DraftIssue>[];

    if (levels.length != expectedLevelCount) {
      issues.add(DraftIssue(
        rule: DraftRule.wrongLevelCount,
        severity: DraftSeverity.blocking,
        path: 'levels',
        message: 'Got ${levels.length} levels, expected $expectedLevelCount.',
        modelHint: 'Return exactly $expectedLevelCount levels — no more, no '
            'fewer.',
      ));
    }

    final seenQuizIds = <String>{...existingQuizIds};
    final seenTitles = <String>{...existingTitles};

    for (var i = 0; i < levels.length; i++) {
      final level = levels[i];
      final path = 'levels[$i]';

      issues.addAll(validateLevel(level, path: path).issues);

      // A gap here does not degrade anything, it permanently locks every
      // level after it: unlocking walks the levelNumber chain and level N
      // needs N-1 completed. The app assigns these by index, so this is an
      // assertion on our own assembly rather than on the model.
      final expected = expectedFirstLevelNumber + i;
      if (level.levelNumber != expected) {
        issues.add(DraftIssue(
          rule: DraftRule.levelNumberNotConsecutive,
          severity: DraftSeverity.blocking,
          path: '$path.levelNumber',
          message: 'Level number ${level.levelNumber} breaks the chain; '
              'everything after it would stay locked. Expected $expected.',
          modelHint: 'Levels must be numbered consecutively from '
              '$expectedFirstLevelNumber with no gaps.',
        ));
      }

      if (existingLevelIds.contains(level.id)) {
        issues.add(DraftIssue(
          rule: DraftRule.levelIdCollision,
          severity: DraftSeverity.blocking,
          path: '$path.id',
          message: 'A level called "${level.id}" already exists. Saving this '
              'would overwrite it.',
          modelHint: 'Do not reuse an existing level id.',
        ));
      }

      if (!ModuleCategory.values.any((c) => c.name == level.moduleId)) {
        // Module ids double as the key for a module's colour and icon, so an
        // unknown one does not fail — it silently falls back to English.
        issues.add(DraftIssue(
          rule: DraftRule.moduleIdNotACategory,
          severity: DraftSeverity.blocking,
          path: '$path.moduleId',
          message: '"${level.moduleId}" is not a known module, so this level '
              'would take English\'s colour and icon.',
          modelHint: 'moduleId must be one of: '
              '${ModuleCategory.values.map((c) => c.name).join(', ')}.',
        ));
      }

      for (final question in level.quizQuestions) {
        if (!seenQuizIds.add(question.id)) {
          issues.add(DraftIssue(
            rule: DraftRule.quizIdDuplicated,
            severity: DraftSeverity.blocking,
            path: '$path.quizQuestions',
            message: 'Question id "${question.id}" is already used. Ids are '
                'the database key, so one would overwrite the other.',
            modelHint: 'Every quiz question needs its own id.',
          ));
        }
      }

      final label = level.portionLabel;
      if (label != null && level.contentItems.isNotEmpty) {
        final expectedLabel = '${level.contentItems.first.title.trim()}'
            ' – ${level.contentItems.last.title.trim()}';
        if (label.trim() != expectedLabel && label.trim().isNotEmpty) {
          issues.add(DraftIssue(
            rule: DraftRule.portionLabelMalformed,
            severity: DraftSeverity.warning,
            path: '$path.portionLabel',
            message: 'Portion "$label" does not match the cards in this level '
                '($expectedLabel).',
            modelHint: 'Do not send portionLabel at all — it is worked out '
                'from the cards.',
          ));
        }
      }

      final title = level.title.trim();
      if (title.isNotEmpty && !seenTitles.add(title)) {
        issues.add(DraftIssue(
          rule: DraftRule.duplicateLevelTitle,
          severity: DraftSeverity.warning,
          path: '$path.title',
          message: '"$title" is used by another level.',
          modelHint: 'Give each level a distinct title.',
        ));
      }

      issues.addAll(_script(level, path));
    }

    return DraftValidationResult(issues);
  }

  /// Text direction is inferred from the module id and the script actually
  /// used, never declared. So an Urdu level written in English quietly lays
  /// out left-to-right, and an English level with Urdu in its title quietly
  /// flips. Both are worth saying out loud before a child sees them.
  List<DraftIssue> _script(LearningLevel level, String path) {
    final written = '${level.title} ${level.subtitle} '
        '${level.contentItems.map((i) => i.displayText).join(' ')}';
    final hasArabic = _arabicScript.hasMatch(written);

    if (level.moduleId == 'urdu' && !hasArabic) {
      return [
        DraftIssue(
          rule: DraftRule.scriptMismatch,
          severity: DraftSeverity.warning,
          path: '$path.title',
          message: 'This is an Urdu level with no Urdu script, so it will lay '
              'out left-to-right.',
          modelHint: 'Write Urdu levels in Urdu script.',
        ),
      ];
    }
    if (level.moduleId != 'urdu' && hasArabic) {
      return [
        DraftIssue(
          rule: DraftRule.scriptMismatch,
          severity: DraftSeverity.warning,
          path: '$path.title',
          message: 'Urdu script in a ${level.moduleId} level will flip it to '
              'right-to-left.',
          modelHint: 'Write ${level.moduleId} levels in their own script.',
        ),
      ];
    }
    return const [];
  }
}
