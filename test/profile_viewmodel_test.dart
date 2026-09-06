import 'package:flutter_test/flutter_test.dart';
import 'package:little_learners/repositories/child_profile_repository.dart';
import 'package:little_learners/viewmodels/profile_viewmodel.dart';

void main() {
  group('ProfileViewModel', () {
    test('rejects invalid age and empty child name', () async {
      final viewModel = ProfileViewModel(InMemoryChildProfileRepository());

      final missingName = await viewModel.createProfile(
        parentId: 'parent-1',
        name: '',
        age: 3,
        avatarAsset: 'koala-blue',
        leaderboardOptIn: false,
        displayPreference: 'alias',
      );
      final invalidAge = await viewModel.createProfile(
        parentId: 'parent-1',
        name: 'Aya',
        age: 9,
        avatarAsset: 'koala-blue',
        leaderboardOptIn: false,
        displayPreference: 'alias',
      );

      expect(missingName, isFalse);
      expect(invalidAge, isFalse);
      expect(viewModel.profiles, isEmpty);
    });

    test('accepts only the ages the content is authored for', () async {
      final viewModel = ProfileViewModel(InMemoryChildProfileRepository());

      for (final age in [0, 1, 5, 8]) {
        expect(
          await viewModel.createProfile(
            parentId: 'parent-1',
            name: 'Aya',
            age: age,
            avatarAsset: 'koala-blue',
            leaderboardOptIn: false,
            displayPreference: 'alias',
          ),
          isFalse,
          reason: 'age $age is outside 2-4',
        );
      }
      expect(viewModel.errorMessage, 'Age must be between 2 and 4.');

      for (final age in [2, 3, 4]) {
        expect(
          await viewModel.createProfile(
            parentId: 'parent-$age',
            name: 'Aya',
            age: age,
            avatarAsset: 'koala-blue',
            leaderboardOptIn: false,
            displayPreference: 'alias',
          ),
          isTrue,
          reason: 'age $age is inside 2-4',
        );
      }
    });

    test('loads created profiles and exposes max-profile state', () async {
      final viewModel = ProfileViewModel(InMemoryChildProfileRepository());

      for (var index = 0; index < 3; index++) {
        final created = await viewModel.createProfile(
          parentId: 'parent-1',
          name: 'Child $index',
          age: 4,
          avatarAsset: 'koala-blue',
          leaderboardOptIn: false,
          displayPreference: 'alias',
        );
        expect(created, isTrue);
      }

      expect(viewModel.profiles.length, 3);
      expect(viewModel.canCreateProfile, isFalse);
    });
  });
}
