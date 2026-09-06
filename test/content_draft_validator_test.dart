import 'package:flutter_test/flutter_test.dart';
import 'package:little_learners/data/seed_content.dart';
import 'package:little_learners/models/content_item.dart';
import 'package:little_learners/models/learning_level.dart';
import 'package:little_learners/models/parent_mark.dart';
import 'package:little_learners/models/quiz_question.dart';
import 'package:little_learners/models/video_lesson.dart';
import 'package:little_learners/services/ai/content_draft_validator.dart';
import 'package:little_learners/services/content/asset_availability.dart';

const validator = ContentDraftValidator();

ContentItem card({
  String title = 'Three',
  String prompt = 'Count three apples.',
  String displayText = '3',
  String visualLabel = 'Three apples',
}) =>
    ContentItem(
      title: title,
      prompt: prompt,
      displayText: displayText,
      visualLabel: visualLabel,
    );

LearningLevel level({
  String id = 'math-stage2-1',
  String moduleId = 'math',
  int stage = 2,
  int levelNumber = 1,
  String title = 'Count to 5',
  String subtitle = 'Practice counting small groups.',
  LevelType type = LevelType.flashcards,
  int passingScore = 70,
  String? portionLabel,
  List<ContentItem>? contentItems,
  List<QuizQuestion> quizQuestions = const [],
  List<VideoLesson> videoLessons = const [],
}) {
  return LearningLevel(
    id: id,
    moduleId: moduleId,
    stage: stage,
    levelNumber: levelNumber,
    title: title,
    subtitle: subtitle,
    type: type,
    passingScore: passingScore,
    isBundled: false,
    portionLabel: portionLabel,
    contentItems: contentItems ?? [card()],
    quizQuestions: quizQuestions,
    videoLessons: videoLessons,
  );
}

Set<DraftRule> blockingRulesOf(LearningLevel candidate) => validator
    .validateLevel(candidate, path: 'levels[0]')
    .blocking
    .map((issue) => issue.rule)
    .toSet();

LearningLevel videoLevel(String url) => level(
      type: LevelType.video,
      videoLessons: [
        VideoLesson(
          id: 'v1',
          title: 'Clip',
          description: 'A clip.',
          durationLabel: '0:10',
          videoUrl: url,
          thumbnailLabel: 'Clip',
        ),
      ],
    );

void main() {
  group('golden: the validator agrees with content the app already ships', () {
    test('no shipped level has a blocking issue', () {
      final offenders = <String>[];

      for (final shipped in seedLevels) {
        final result = validator.validateLevel(shipped, path: shipped.id);
        if (result.isBlocked) {
          offenders.add(
            '${shipped.id} (${shipped.type.name}): '
            '${result.blocking.map((i) => "${i.rule.name} at ${i.path}").join("; ")}',
          );
        }
      }

      expect(
        offenders,
        isEmpty,
        reason: 'These levels ship in the app today, so if the validator '
            'rejects one then the validator is what is wrong:\n'
            '${offenders.join("\n")}',
      );
    });

    test('the golden set actually covers every level type', () {
      expect(
        seedLevels.map((l) => l.type).toSet(),
        containsAll(LevelType.values.toSet()),
      );
    });
  });

  group('rules that apply to every level type', () {
    test('an empty title and subtitle both block', () {
      expect(
        blockingRulesOf(level(title: '  ', subtitle: '')),
        containsAll({DraftRule.levelTitleEmpty, DraftRule.levelSubtitleEmpty}),
      );
    });

    test('a passing score outside 0-100 blocks', () {
      expect(blockingRulesOf(level(passingScore: 140)),
          contains(DraftRule.passingScoreOutOfRange));
    });

    test('a blank field on any card blocks', () {
      expect(
        blockingRulesOf(level(contentItems: [card(visualLabel: '   ')])),
        contains(DraftRule.contentFieldEmpty),
      );
    });

    test('a question with one option is not a choice', () {
      expect(
        blockingRulesOf(level(quizQuestions: const [
          QuizQuestion(
              id: 'q1', prompt: 'Which?', options: ['3'], correctIndex: 0),
        ])),
        contains(DraftRule.quizTooFewOptions),
      );
    });

    test('correctIndex past the end of options blocks, and is never clamped',
        () {
      expect(
        blockingRulesOf(level(quizQuestions: const [
          QuizQuestion(
              id: 'q1',
              prompt: 'Which?',
              options: ['2', '3', '4'],
              correctIndex: 3),
        ])),
        contains(DraftRule.quizCorrectIndexOutOfRange),
      );
    });
  });

  group('per level type', () {
    test('every type is covered by a case in this suite', () {
      // Forces this file to grow when an eighth LevelType is added.
      const covered = {
        LevelType.flashcards,
        LevelType.counting,
        LevelType.matching,
        LevelType.story,
        LevelType.drawing,
        LevelType.tracing,
        LevelType.video,
      };
      expect(covered, equals(LevelType.values.toSet()));
    });

    test('flashcards and story need at least one card', () {
      for (final type in [LevelType.flashcards, LevelType.story]) {
        expect(
          blockingRulesOf(level(type: type, contentItems: const [])),
          contains(DraftRule.contentItemsEmpty),
          reason: '${type.name} with no cards must block',
        );
      }
    });

    test('counting displayText that is not a number blocks', () {
      expect(
        blockingRulesOf(level(
          type: LevelType.counting,
          contentItems: [card(displayText: 'three')],
        )),
        contains(DraftRule.countingDisplayTextNotInteger),
      );
    });

    test('counting past 12 warns but does not block', () {
      final result = validator.validateLevel(
        level(
          type: LevelType.counting,
          contentItems: [card(displayText: '20')],
        ),
        path: 'levels[0]',
      );
      expect(result.isBlocked, isFalse);
      expect(result.warnings.map((i) => i.rule),
          contains(DraftRule.countingTargetTooHigh));
    });

    test('matching with one distinct title blocks', () {
      expect(
        blockingRulesOf(level(
          type: LevelType.matching,
          contentItems: [card(title: 'Apple'), card(title: 'Apple')],
        )),
        contains(DraftRule.matchingNeedsTwoDistinctTitles),
      );
    });

    test('matching with two distinct titles passes', () {
      expect(
        blockingRulesOf(level(
          type: LevelType.matching,
          contentItems: [card(title: 'Apple'), card(title: 'Pear')],
        )),
        isEmpty,
      );
    });

    test('a tracing glyph of two characters blocks', () {
      expect(
        blockingRulesOf(level(
          type: LevelType.tracing,
          passingScore: 60,
          contentItems: [card(displayText: 'AB')],
        )),
        contains(DraftRule.tracingGlyphNotSingleRune),
      );
    });

    test('a tracing glyph in a script no bundled font covers blocks', () {
      for (final glyph in ['x2713', 'x6F22', 'x0021']) {
        final actual = String.fromCharCode(int.parse(glyph.substring(1), radix: 16));
        expect(
          blockingRulesOf(level(
            type: LevelType.tracing,
            passingScore: 60,
            contentItems: [card(displayText: actual)],
          )),
          contains(DraftRule.tracingGlyphUnsupportedScript),
          reason: '"$actual" has no font to draw a guide from',
        );
      }
    });

    test('Latin and Urdu tracing glyphs are both accepted', () {
      for (final glyph in ['A', 'z', '7', 'ا', 'ب']) {
        expect(
          blockingRulesOf(level(
            type: LevelType.tracing,
            passingScore: 60,
            contentItems: [card(displayText: glyph)],
          )),
          isEmpty,
          reason: '"$glyph" should be traceable',
        );
      }
    });

    test('a video level with no lessons blocks', () {
      expect(
        blockingRulesOf(level(type: LevelType.video, videoLessons: const [])),
        contains(DraftRule.videoLessonsMissing),
      );
    });

    test('a video url that is neither an asset nor http(s) blocks', () {
      for (final url in ['example.com/a.mp4', 'file:///tmp/a.mp4', '']) {
        expect(
          blockingRulesOf(videoLevel(url)),
          contains(DraftRule.videoUrlNotPlayable),
          reason: '"$url" is not playable',
        );
      }
    });

    // The player opens a bundled file as readily as a URL, and the lessons
    // that ship today are all bundled. A validator that only knew about
    // http(s) called all nine of them broken.
    test('a bundled asset path is accepted', () {
      AssetAvailability.instance.debugSeed({'assets/videos/age2/duck.mp4'});
      addTearDown(AssetAvailability.instance.debugReset);

      expect(
        blockingRulesOf(videoLevel('assets/videos/age2/duck.mp4')),
        isEmpty,
      );
    });

    test('an asset path the app does not ship blocks', () {
      AssetAvailability.instance.debugSeed({'assets/videos/age2/duck.mp4'});
      addTearDown(AssetAvailability.instance.debugReset);

      expect(
        blockingRulesOf(videoLevel('assets/videos/age2/rabbit.mp4')),
        contains(DraftRule.videoAssetMissing),
        reason: 'nothing would play, and no admin could fix it without a '
            'new release',
      );
    });

    test('an unread manifest accuses nothing', () {
      // `debugSeed` marks the registry populated, so this has to be the
      // untouched singleton to prove the optimistic path.
      expect(
        blockingRulesOf(videoLevel('assets/videos/age2/rabbit.mp4')),
        isEmpty,
        reason: 'a headless test has no manifest, and guessing "missing" '
            'would fail every video level in this suite',
      );
    });
  });

  group('canvas levels are graded by a person', () {
    test('the band is derived so that exactly one grade fails', () {
      for (final score in [
        ContentDraftValidator.canvasMinPassingScore,
        ContentDraftValidator.canvasMaxPassingScore,
      ]) {
        final failing =
            ParentMark.values.where((m) => !m.passes(score)).toList();
        expect(failing, equals([ParentMark.needsPractice]),
            reason: 'at passingScore $score');
      }
    });

    test('a score above the band blocks for drawing and tracing', () {
      for (final type in [LevelType.drawing, LevelType.tracing]) {
        expect(
          blockingRulesOf(level(
            type: type,
            passingScore: 85,
            contentItems: [card(displayText: 'A')],
          )),
          contains(DraftRule.canvasPassingScoreOutOfBand),
          reason: '${type.name} at 85 fails more than one grade',
        );
      }
    });

    test('a score below the band blocks', () {
      expect(
        blockingRulesOf(level(type: LevelType.drawing, passingScore: 40)),
        contains(DraftRule.canvasPassingScoreOutOfBand),
      );
    });
  });

  group('rules that only exist between levels', () {
    List<LearningLevel> stage(int count, {int from = 1}) => [
          for (var i = 0; i < count; i++)
            level(
              id: 'math-stage2-${from + i}',
              levelNumber: from + i,
              title: 'Level ${from + i}',
            ),
        ];

    test('a clean stage produces nothing', () {
      final result = validator.validateStage(
        stage(3),
        expectedLevelCount: 3,
        expectedFirstLevelNumber: 1,
      );
      expect(result.issues, isEmpty);
    });

    test('the wrong number of levels blocks', () {
      final result = validator.validateStage(
        stage(2),
        expectedLevelCount: 5,
        expectedFirstLevelNumber: 1,
      );
      expect(result.blocking.map((i) => i.rule),
          contains(DraftRule.wrongLevelCount));
    });

    test('a gap in level numbers blocks, because it locks the tail', () {
      final result = validator.validateStage(
        [
          level(id: 'math-stage2-1', levelNumber: 1, title: 'One'),
          level(id: 'math-stage2-3', levelNumber: 3, title: 'Three'),
        ],
        expectedLevelCount: 2,
        expectedFirstLevelNumber: 1,
      );
      expect(result.blocking.map((i) => i.rule),
          contains(DraftRule.levelNumberNotConsecutive));
    });

    test('numbering is checked from where the stage actually continues', () {
      final result = validator.validateStage(
        stage(2, from: 4),
        expectedLevelCount: 2,
        expectedFirstLevelNumber: 4,
      );
      expect(result.issues, isEmpty);
    });

    test('an id that already exists blocks rather than silently overwriting',
        () {
      final result = validator.validateStage(
        stage(1),
        expectedLevelCount: 1,
        expectedFirstLevelNumber: 1,
        existingLevelIds: {'math-stage2-1'},
      );
      expect(result.blocking.map((i) => i.rule),
          contains(DraftRule.levelIdCollision));
    });

    test('a repeated quiz id blocks, because it is the database key', () {
      const question = QuizQuestion(
          id: 'dup', prompt: 'Which?', options: ['a', 'b'], correctIndex: 0);
      final result = validator.validateStage(
        [
          level(id: 'math-stage2-1', levelNumber: 1, quizQuestions: [question]),
          level(id: 'math-stage2-2', levelNumber: 2, quizQuestions: [question]),
        ],
        expectedLevelCount: 2,
        expectedFirstLevelNumber: 1,
      );
      expect(result.blocking.map((i) => i.rule),
          contains(DraftRule.quizIdDuplicated));
    });

    test('an unknown module id blocks', () {
      final result = validator.validateStage(
        [level(moduleId: 'maths')],
        expectedLevelCount: 1,
        expectedFirstLevelNumber: 1,
      );
      expect(result.blocking.map((i) => i.rule),
          contains(DraftRule.moduleIdNotACategory));
    });

    test('an Urdu level written in English only warns', () {
      final result = validator.validateStage(
        [level(moduleId: 'urdu', title: 'Letter Alif')],
        expectedLevelCount: 1,
        expectedFirstLevelNumber: 1,
      );
      expect(result.isBlocked, isFalse);
      expect(result.warnings.map((i) => i.rule),
          contains(DraftRule.scriptMismatch));
    });

    test('Urdu script in a non-Urdu module warns about the flip', () {
      final result = validator.validateStage(
        [level(moduleId: 'math', title: 'حرف ا')],
        expectedLevelCount: 1,
        expectedFirstLevelNumber: 1,
      );
      expect(result.warnings.map((i) => i.rule),
          contains(DraftRule.scriptMismatch));
    });

    test('a repeated title warns', () {
      final result = validator.validateStage(
        [
          level(id: 'math-stage2-1', levelNumber: 1, title: 'Same'),
          level(id: 'math-stage2-2', levelNumber: 2, title: 'Same'),
        ],
        expectedLevelCount: 2,
        expectedFirstLevelNumber: 1,
      );
      expect(result.warnings.map((i) => i.rule),
          contains(DraftRule.duplicateLevelTitle));
    });
  });
}
