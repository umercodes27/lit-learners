import 'package:flutter_test/flutter_test.dart';
import 'package:little_learners/repositories/parental_lock_repository.dart';
import 'package:little_learners/viewmodels/parental_lock_viewmodel.dart';

void main() {
  group('ParentalLockViewModel', () {
    test('unlocks when the challenge answer is correct', () async {
      final viewModel = ParentalLockViewModel(InMemoryParentalLockRepository());
      addTearDown(viewModel.dispose);
      await viewModel.loadChallenge();

      final challenge = viewModel.challenge!;
      final passed = await viewModel.verify(challenge.answer.toString());

      expect(passed, isTrue);
      expect(viewModel.errorMessage, isNull);
      expect(viewModel.isLocked, isFalse);
    });

    test('locks after three failed attempts', () async {
      final viewModel = ParentalLockViewModel(InMemoryParentalLockRepository());
      addTearDown(viewModel.dispose);
      await viewModel.loadChallenge();

      await viewModel.verify('999');
      await viewModel.verify('999');
      await viewModel.verify('999');

      expect(viewModel.isLocked, isTrue);
      expect(viewModel.errorMessage, contains('Too many tries'));
    });
  });
}
