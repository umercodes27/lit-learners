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
        age: 5,
        avatarAsset: 'koala-blue',
        leaderboardOptIn: false,
        displayPreference: 'alias',
      );

      expect(missingName, isFalse);
      expect(invalidAge, isFalse);
      expect(viewModel.profiles, isEmpty);
    });

    test('loads created profiles and exposes max-profile state', () async {
      final viewModel = ProfileViewModel(InMemoryChildProfileRepository());

      for (var index = 0; index < 3; index++) {
        final created = await viewModel.createProfile(
          parentId: 'parent-1',
          name: 'Child $index',
          age: 2,
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
