import 'package:flutter/foundation.dart';

import '../models/learning_level.dart';
import '../models/quiz_question.dart';

class QuizViewModel extends ChangeNotifier {
  QuizViewModel(this.level);

  final LearningLevel level;
  int _questionIndex = 0;
  int _correctCount = 0;
  int? _selectedIndex;
  bool _answered = false;

  QuizQuestion get currentQuestion => level.quizQuestions[_questionIndex];
  int get questionIndex => _questionIndex;
  int get totalQuestions => level.quizQuestions.length;
  int? get selectedIndex => _selectedIndex;
  bool get answered => _answered;
  bool get isLastQuestion => _questionIndex == totalQuestions - 1;
  int get scorePercent => ((_correctCount / totalQuestions) * 100).round();
  bool get passed => scorePercent >= level.passingScore;

  void selectAnswer(int index) {
    if (_answered) return;

    _selectedIndex = index;
    _answered = true;
    if (currentQuestion.isCorrect(index)) {
      _correctCount += 1;
    }
    notifyListeners();
  }

  void nextQuestion() {
    if (!_answered || isLastQuestion) return;

    _questionIndex += 1;
    _selectedIndex = null;
    _answered = false;
    notifyListeners();
  }

  void restart() {
    _questionIndex = 0;
    _correctCount = 0;
    _selectedIndex = null;
    _answered = false;
    notifyListeners();
  }
}
