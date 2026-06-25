import 'package:flutter/foundation.dart';

import '../models/onboarding.dart';
import '../repositories/onboarding_repository.dart';

class OnboardingViewModel extends ChangeNotifier {
  OnboardingViewModel(this._onboardingRepository);

  static const passingScore = 70;

  final OnboardingRepository _onboardingRepository;

  ParentOnboardingState? _state;
  List<ManualPageContent> _manualPages = const [];
  List<ReadinessQuestion> _questions = const [];
  final Map<String, int> _selectedAnswers = {};
  bool _isLoading = false;
  int? _latestScore;
  bool? _latestPassed;

  ParentOnboardingState? get state => _state;
  List<ManualPageContent> get manualPages => List.unmodifiable(_manualPages);
  List<ReadinessQuestion> get questions => List.unmodifiable(_questions);
  bool get isLoading => _isLoading;
  int get currentManualPage => _state?.lastManualPageIndex ?? 0;
  int? get latestScore => _latestScore;
  bool? get latestPassed => _latestPassed;
  bool get manualCompleted => _state?.manualCompleted ?? false;
  bool get testPassed => _state?.testPassed ?? false;
  bool get allQuestionsAnswered => _selectedAnswers.length == _questions.length;

  int? selectedAnswerFor(String questionId) => _selectedAnswers[questionId];

  Future<void> loadForParent(String parentId) async {
    _isLoading = true;
    notifyListeners();

    _manualPages = await _onboardingRepository.getManualPages();
    _questions = await _onboardingRepository.getReadinessQuestions();
    _state = await _onboardingRepository.getState(parentId);

    _isLoading = false;
    notifyListeners();
  }

  Future<void> saveManualPage(String parentId, int pageIndex) async {
    _state = await _onboardingRepository.saveManualPage(
      parentId: parentId,
      pageIndex: pageIndex,
    );
    notifyListeners();
  }

  Future<void> completeManual(String parentId) async {
    _state = await _onboardingRepository.completeManual(parentId);
    notifyListeners();
  }

  void selectAnswer(String questionId, int answerIndex) {
    _selectedAnswers[questionId] = answerIndex;
    notifyListeners();
  }

  Future<bool> submitReadinessTest(String parentId) async {
    if (!allQuestionsAnswered) return false;

    var correct = 0;
    for (final question in _questions) {
      final selectedIndex = _selectedAnswers[question.id];
      if (selectedIndex != null && question.isCorrect(selectedIndex)) {
        correct += 1;
      }
    }

    final score = ((correct / _questions.length) * 100).round();
    final passed = score >= passingScore;
    _latestScore = score;
    _latestPassed = passed;
    _state = await _onboardingRepository.saveReadinessResult(
      parentId: parentId,
      score: score,
      passed: passed,
    );
    notifyListeners();
    return passed;
  }

  void resetReadinessAttempt() {
    _selectedAnswers.clear();
    _latestScore = null;
    _latestPassed = null;
    notifyListeners();
  }
}
