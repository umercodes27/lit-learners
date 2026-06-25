import 'package:flutter_test/flutter_test.dart';
import 'package:little_learners/models/learning_level.dart';
import 'package:little_learners/models/quiz_question.dart';
import 'package:little_learners/viewmodels/quiz_viewmodel.dart';

void main() {
  test('QuizViewModel scores correct answers and marks passing result', () {
    const level = LearningLevel(
      id: 'level-1',
      moduleId: 'math',
      stage: 3,
      levelNumber: 1,
      title: 'Demo',
      subtitle: 'Demo',
      type: LevelType.counting,
      passingScore: 70,
      isBundled: true,
      quizQuestions: [
        QuizQuestion(
          id: 'q1',
          prompt: 'First?',
          options: ['No', 'Yes'],
          correctIndex: 1,
        ),
        QuizQuestion(
          id: 'q2',
          prompt: 'Second?',
          options: ['Yes', 'No'],
          correctIndex: 0,
        ),
      ],
    );

    final quiz = QuizViewModel(level);

    quiz.selectAnswer(1);
    quiz.nextQuestion();
    quiz.selectAnswer(0);

    expect(quiz.scorePercent, 100);
    expect(quiz.passed, isTrue);
  });
}
