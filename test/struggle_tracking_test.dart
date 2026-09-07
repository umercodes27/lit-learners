import 'package:flutter_test/flutter_test.dart';
import 'package:little_learners/models/content_item.dart';
import 'package:little_learners/models/learning_level.dart';
import 'package:little_learners/models/progress.dart';
import 'package:little_learners/models/quiz_question.dart';
import 'package:little_learners/repositories/progress_repository.dart';
import 'package:little_learners/services/local/progress_dao.dart';
import 'package:little_learners/viewmodels/quiz_viewmodel.dart';

LearningLevel level({int passingScore = 60}) => const LearningLevel(
      id: 'math-stage3-1',
      moduleId: 'math',
      stage: 3,
      levelNumber: 1,
      title: 'Count to 3',
      subtitle: 'Together',
      type: LevelType.counting,
      passingScore: 60,
      isBundled: true,
      contentItems: [
        ContentItem(
          title: 'Three',
          prompt: 'Count three.',
          displayText: '3',
          visualLabel: 'Three apples',
        ),
      ],
      quizQuestions: [
        QuizQuestion(
          id: 'q1',
          prompt: 'How many?',
          options: ['2', '3'],
          correctIndex: 1,
        ),
        QuizQuestion(
          id: 'q2',
          prompt: 'And now?',
          options: ['1', '4'],
          correctIndex: 0,
        ),
      ],
    );

void main() {
  group('the quiz counts what went wrong', () {
    test('a wrong answer is counted, a right one is not', () {
      final quiz = QuizViewModel(level());

      quiz.selectAnswer(0); // wrong
      expect(quiz.wrongAnswers, 1);

      quiz.nextQuestion();
      quiz.selectAnswer(0); // right
      expect(quiz.wrongAnswers, 1);
    });

    test('restarting after a failed round does not wipe the record', () {
      final quiz = QuizViewModel(level());

      quiz.selectAnswer(0); // wrong
      quiz.nextQuestion();
      quiz.selectAnswer(1); // wrong
      expect(quiz.wrongAnswers, 2);
      expect(quiz.scorePercent, 0);

      quiz.restart();

      // The score starts again because the child does. The record of how much
      // this level has cost them does not.
      expect(quiz.scorePercent, 0);
      expect(quiz.wrongAnswers, 2);

      quiz.selectAnswer(1); // right
      quiz.nextQuestion();
      quiz.selectAnswer(0); // right

      expect(quiz.scorePercent, 100);
      expect(quiz.wrongAnswers, 2,
          reason: 'passing on the third go must not look like passing first '
              'time, which is exactly what a score alone would say');
    });

    test('a clean run records nothing wrong', () {
      final quiz = QuizViewModel(level());
      quiz.selectAnswer(1);
      quiz.nextQuestion();
      quiz.selectAnswer(0);

      expect(quiz.scorePercent, 100);
      expect(quiz.wrongAnswers, 0);
    });
  });

  group('progress accumulates rather than being replaced', () {
    test('attempts and wrong answers add up across plays', () async {
      final repository =
          CachedProgressRepository(progressDao: InMemoryProgressDao());

      await repository.completeLevel(
        childId: 'c1',
        level: level(),
        score: 50,
        wrongAnswers: 3,
      );
      final second = await repository.completeLevel(
        childId: 'c1',
        level: level(),
        score: 100,
        wrongAnswers: 2,
      );

      expect(second.attempts, 2);
      expect(second.wrongAnswers, 5);
      // The score is the latest run, which is right for "how is it going now"
      // and useless for "how hard was this".
      expect(second.score, 100);
      expect(second.wrongPerAttempt, 2.5);
    });

    test('a first play starts the count at one', () async {
      final repository =
          CachedProgressRepository(progressDao: InMemoryProgressDao());

      final first = await repository.completeLevel(
        childId: 'c1',
        level: level(),
        score: 80,
      );

      expect(first.attempts, 1);
      expect(first.wrongAnswers, 0);
      expect(first.wrongPerAttempt, 0);
    });

    test('a row with no attempts does not divide by zero', () {
      final untouched = LevelProgress(
        childId: 'c1',
        moduleId: 'math',
        levelId: 'math-stage3-1',
        completed: false,
        starsEarned: 0,
        rewardEarned: false,
        updatedAt: DateTime(2026),
        isSynced: false,
      );

      expect(untouched.attempts, 0);
      expect(untouched.wrongPerAttempt, 0);
    });
  });
}
