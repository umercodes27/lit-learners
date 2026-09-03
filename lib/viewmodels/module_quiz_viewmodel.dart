import 'package:flutter/foundation.dart';

import '../models/module_quiz.dart';

/// Drives one run through a module's closing quiz.
///
/// Deliberately separate from [QuizViewModel], which grades a seeded
/// [LearningLevel] against its own `passingScore` and averages the result with
/// a parent's mark. A module quiz has neither: it is built from pack content,
/// carries no canvas stage, and passes at [ModuleQuiz.passingPercent].
class ModuleQuizViewModel extends ChangeNotifier {
  ModuleQuizViewModel(this.quiz);

  final ModuleQuiz quiz;

  int _index = 0;
  int _correctCount = 0;
  int? _selectedIndex;
  bool _answered = false;

  ModuleQuizQuestion get currentQuestion => quiz.questions[_index];
  int get questionNumber => _index + 1;
  int get totalQuestions => quiz.length;
  int? get selectedIndex => _selectedIndex;
  bool get answered => _answered;
  bool get isLastQuestion => _index == quiz.length - 1;

  /// True once the last question has been answered and the child has moved on
  /// from it, at which point the result replaces the slides.
  bool get isFinished => _finished;
  bool _finished = false;

  int get correctCount => _correctCount;
  int get scorePercent => quiz.percentFor(_correctCount);
  bool get passed => quiz.passes(_correctCount);

  /// How far along the slides the child is, for the progress bar.
  double get progress => quiz.isEmpty ? 0 : questionNumber / totalQuestions;

  void selectAnswer(int index) {
    if (_answered) return;

    _selectedIndex = index;
    _answered = true;
    if (currentQuestion.isCorrect(index)) _correctCount += 1;
    notifyListeners();
  }

  /// Moves to the next slide, or to the result after the last one.
  void next() {
    if (!_answered) return;

    if (isLastQuestion) {
      _finished = true;
    } else {
      _index += 1;
      _selectedIndex = null;
      _answered = false;
    }
    notifyListeners();
  }

  void restart() {
    _index = 0;
    _correctCount = 0;
    _selectedIndex = null;
    _answered = false;
    _finished = false;
    notifyListeners();
  }
}
