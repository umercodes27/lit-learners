import 'package:flutter_test/flutter_test.dart';
import 'package:little_learners/models/content_item.dart';
import 'package:little_learners/models/learning_level.dart';
import 'package:little_learners/models/parent_mark.dart';
import 'package:little_learners/models/quiz_question.dart';
import 'package:little_learners/models/video_lesson.dart';
import 'package:little_learners/services/ai/content_draft_repairer.dart';
import 'package:little_learners/services/ai/content_draft_validator.dart';

const repairer = ContentDraftRepairer();

LearningLevel level({
  LevelType type = LevelType.flashcards,
  int passingScore = 70,
  List<ContentItem>? contentItems,
  List<QuizQuestion> quizQuestions = const [],
  List<VideoLesson> videoLessons = const [],
}) =>
    LearningLevel(
      id: 'math-stage2-1',
      moduleId: 'math',
      stage: 2,
      levelNumber: 1,
      title: 'Count to 5',
      subtitle: 'Practice counting.',
      type: type,
      passingScore: passingScore,
      isBundled: false,
      contentItems: contentItems ??
          const [
            ContentItem(
              title: 'Three',
              prompt: 'Count three apples.',
              displayText: '3',
              visualLabel: 'Three apples',
            ),
          ],
      quizQuestions: quizQuestions,
      videoLessons: videoLessons,
    );

void main() {
  group('passing score', () {
    test('a canvas score above the band lands back inside it', () {
      for (final type in [LevelType.drawing, LevelType.tracing]) {
        final result = repairer.repair(level(type: type, passingScore: 85));
        final score = result.level.passingScore;

        expect(score,
            lessThanOrEqualTo(ContentDraftValidator.canvasMaxPassingScore));
        expect(score,
            greaterThanOrEqualTo(ContentDraftValidator.canvasMinPassingScore));

        // The rule the band exists to preserve, asserted directly rather than
        // trusted: exactly one grade may fail.
        expect(
          ParentMark.values.where((m) => !m.passes(score)).toList(),
          equals([ParentMark.needsPractice]),
          reason: '${type.name} repaired to $score',
        );
        expect(result.notes, isNotEmpty);
      }
    });

    test('a canvas score below the band lands back inside it', () {
      final result =
          repairer.repair(level(type: LevelType.drawing, passingScore: 10));
      expect(
        ParentMark.values.where((m) => !m.passes(result.level.passingScore)),
        equals([ParentMark.needsPractice]),
      );
    });

    test('a canvas score already in the band is left alone', () {
      final result =
          repairer.repair(level(type: LevelType.tracing, passingScore: 60));
      expect(result.level.passingScore, 60);
      expect(result.changed, isFalse);
    });

    test('a non-canvas score is only clamped to 0-100', () {
      expect(repairer.repair(level(passingScore: 140)).level.passingScore, 100);
      expect(repairer.repair(level(passingScore: -5)).level.passingScore, 0);
      // 85 is illegal on a canvas level but perfectly normal elsewhere.
      expect(repairer.repair(level(passingScore: 85)).level.passingScore, 85);
    });
  });

  group('quiz questions', () {
    test('a question with one option is dropped, not padded', () {
      final result = repairer.repair(level(quizQuestions: const [
        QuizQuestion(
            id: 'q1', prompt: 'Which?', options: ['3'], correctIndex: 0),
        QuizQuestion(
            id: 'q2',
            prompt: 'And which?',
            options: ['3', '4'],
            correctIndex: 1),
      ]));

      expect(result.level.quizQuestions.map((q) => q.id), ['q2']);
      expect(result.notes.single, contains('Dropped 1'));
    });

    test('a good question is untouched', () {
      final result = repairer.repair(level(quizQuestions: const [
        QuizQuestion(
            id: 'q1', prompt: 'Which?', options: ['3', '4'], correctIndex: 0),
      ]));
      expect(result.changed, isFalse);
    });
  });

  group('small fills', () {
    test('a missing picture description falls back to the card title', () {
      final result = repairer.repair(level(contentItems: const [
        ContentItem(
            title: 'Apple',
            prompt: 'Find the apple.',
            displayText: 'A',
            visualLabel: '   '),
      ]));

      expect(result.level.contentItems.single.visualLabel, 'Apple');
      expect(result.notes.single, contains('picture description'));
    });

    test('a malformed video duration falls back to a label', () {
      final result = repairer.repair(level(
        type: LevelType.video,
        videoLessons: const [
          VideoLesson(
            id: 'v1',
            title: 'Bees',
            description: 'A clip.',
            durationLabel: 'about ten seconds',
            videoUrl: 'https://example.com/bee.mp4',
            thumbnailLabel: 'Bees',
          ),
        ],
      ));

      expect(result.level.videoLessons.single.durationLabel, '0:30');
      // The URL is the load-bearing part and must survive untouched.
      expect(result.level.videoLessons.single.videoUrl,
          'https://example.com/bee.mp4');
    });
  });

  group('what the repairer refuses to do', () {
    test('it never invents a tracing glyph', () {
      final result = repairer.repair(level(
        type: LevelType.tracing,
        passingScore: 60,
        contentItems: const [
          ContentItem(
              title: 'AB',
              prompt: 'Trace.',
              displayText: 'AB',
              visualLabel: 'Letters'),
        ],
      ));

      expect(result.level.contentItems.single.displayText, 'AB');
      expect(
        const ContentDraftValidator()
            .validateLevel(result.level, path: 'x')
            .isBlocked,
        isTrue,
        reason: 'it must still block afterwards, not be quietly made legal',
      );
    });

    test('it never repoints a wrong correctIndex', () {
      final result = repairer.repair(level(quizQuestions: const [
        QuizQuestion(
            id: 'q1',
            prompt: 'Which?',
            options: ['2', '3', '4'],
            correctIndex: 7),
      ]));

      expect(result.level.quizQuestions.single.correctIndex, 7);
      expect(
        const ContentDraftValidator()
            .validateLevel(result.level, path: 'x')
            .blocking
            .map((i) => i.rule),
        contains(DraftRule.quizCorrectIndexOutOfRange),
      );
    });

    test('it never invents a title, prompt or glyph for a blank card', () {
      final result = repairer.repair(level(contentItems: const [
        ContentItem(
            title: '', prompt: '', displayText: '', visualLabel: 'A picture'),
      ]));

      final item = result.level.contentItems.single;
      expect(item.title, isEmpty);
      expect(item.prompt, isEmpty);
      expect(item.displayText, isEmpty);
    });

    test('it never conjures cards for an empty level', () {
      final result = repairer.repair(level(contentItems: const []));
      expect(result.level.contentItems, isEmpty);
      expect(result.changed, isFalse);
    });
  });

  test('any change is always explained', () {
    final result = repairer.repair(level(
      type: LevelType.drawing,
      passingScore: 99,
      quizQuestions: const [
        QuizQuestion(
            id: 'q1', prompt: 'Which?', options: ['a'], correctIndex: 0),
      ],
    ));

    expect(result.changed, isTrue);
    expect(result.notes.length, 2);
    for (final note in result.notes) {
      expect(note.trim(), isNotEmpty);
    }
  });
}
