import 'package:flutter/foundation.dart';

import '../models/learning_level.dart';
import '../models/quiz_question.dart';

class QuizViewModel extends ChangeNotifier {
  QuizViewModel(this.level);

  /// Canvas levels are graded twice: once by the grown-up who marked the
  /// drawing or tracing, once by the quiz that follows. The level mark is the
  /// average, so neither half can be skipped and the parent's mark is not
  /// thrown away by a good round of questions.
  ///
  /// Levels with no canvas stage keep their quiz percentage unchanged.
  static int combineWithParentMark({
    required int quizPercent,
    int? parentMark,
  }) {
    if (parentMark == null) return quizPercent;
    return ((parentMark + quizPercent) / 2).round();
  }

  final LearningLevel level;
  int _questionIndex = 0;
  int _correctCount = 0;
  int? _selectedIndex;
  bool _answered = false;

  /// Every wrong answer this child has given on this level, across retries.
  ///
  /// Deliberately not reset by [restart]. A child who failed the quiz twice
  /// and passed on the third go scores the same as one who passed first time,
  /// and the difference between them is the whole point of asking.
  int _wrongTotal = 0;

  QuizQuestion get currentQuestion => level.quizQuestions[_questionIndex];
  int get questionIndex => _questionIndex;
  int get totalQuestions => level.quizQuestions.length;
  int? get selectedIndex => _selectedIndex;
  bool get answered => _answered;
  bool get isLastQuestion => _questionIndex == totalQuestions - 1;
  int get scorePercent => ((_correctCount / totalQuestions) * 100).round();
  bool get passed => scorePercent >= level.passingScore;

  /// Wrong answers so far, counting every attempt at this level.
  int get wrongAnswers => _wrongTotal;

  void selectAnswer(int index) {
    if (_answered) return;

    _selectedIndex = index;
    _answered = true;
    if (currentQuestion.isCorrect(index)) {
      _correctCount += 1;
    } else {
      _wrongTotal += 1;
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

  /// Starts the questions again after a failed round.
  ///
  /// [_wrongTotal] survives on purpose: it is a record of how much this level
  /// has cost the child, and starting over does not undo that.
  void restart() {
    _questionIndex = 0;
    _correctCount = 0;
    _selectedIndex = null;
    _answered = false;
    notifyListeners();
  }
}
