import 'package:flutter_test/flutter_test.dart';
import 'package:little_learners/repositories/onboarding_repository.dart';
import 'package:little_learners/viewmodels/onboarding_viewmodel.dart';

void main() {
  group('OnboardingViewModel', () {
    test('passes readiness test at or above threshold', () async {
      final viewModel = OnboardingViewModel(InMemoryOnboardingRepository());
      await viewModel.loadForParent('parent-1');

      for (final question in viewModel.questions) {
        viewModel.selectAnswer(question.id, question.correctIndex);
      }

      final passed = await viewModel.submitReadinessTest('parent-1');

      expect(passed, isTrue);
      expect(viewModel.testPassed, isTrue);
      expect(viewModel.latestScore, 100);
    });

    test('fails readiness test below threshold', () async {
      final viewModel = OnboardingViewModel(InMemoryOnboardingRepository());
      await viewModel.loadForParent('parent-1');

      for (final question in viewModel.questions) {
        viewModel.selectAnswer(question.id, 1);
      }

      final passed = await viewModel.submitReadinessTest('parent-1');

      expect(passed, isFalse);
      expect(viewModel.testPassed, isFalse);
      expect(viewModel.latestScore, lessThan(OnboardingViewModel.passingScore));
    });
  });
}
