import 'package:flutter_test/flutter_test.dart';
import 'package:little_learners/models/child_profile.dart';
import 'package:little_learners/models/progress.dart';
import 'package:little_learners/repositories/leaderboard_repository.dart';
import 'package:little_learners/services/remote/leaderboard_remote_data_source.dart';

void main() {
  group('RemoteLeaderboardRepository', () {
    test('creates anonymized opt-in leaderboard entries from progress',
        () async {
      final remote = InMemoryLeaderboardRemoteDataSource();
      final repository = RemoteLeaderboardRepository(remoteDataSource: remote);
      final profile = _profile(
        id: 'child-123456',
        age: 3,
        leaderboardOptIn: true,
        displayPreference: 'alias',
      );

      final entry = await repository.refreshEntry(
        profile: profile,
        progress: [
          _progress(
            childId: profile.id,
            completed: true,
            score: 80,
            starsEarned: 2,
            rewardEarned: true,
          ),
        ],
      );

      expect(entry?.displayName, 'Learner 3456');
      expect(entry?.ageStage, 3);
      expect(entry?.totalScore, 225);
      expect(await repository.getTopEntries(age: 3), hasLength(1));
    });

    test('removes leaderboard entries when profile opts out', () async {
      final remote = InMemoryLeaderboardRemoteDataSource();
      final repository = RemoteLeaderboardRepository(remoteDataSource: remote);
      final optedIn = _profile(
        id: 'child-1',
        leaderboardOptIn: true,
      );

      await repository.refreshEntry(
        profile: optedIn,
        progress: [_progress(childId: optedIn.id, completed: true)],
      );
      await repository.refreshEntry(
        profile: optedIn.copyWith(
          leaderboardOptIn: false,
          updatedAt: DateTime.utc(2026, 1, 2),
        ),
        progress: [_progress(childId: optedIn.id, completed: true)],
      );

      expect(await repository.getTopEntries(age: optedIn.age), isEmpty);
    });

    test('sorts top entries by score within an age group', () async {
      final remote = InMemoryLeaderboardRemoteDataSource();
      final repository = RemoteLeaderboardRepository(remoteDataSource: remote);

      await repository.refreshEntry(
        profile: _profile(id: 'child-low', leaderboardOptIn: true),
        progress: [_progress(childId: 'child-low', completed: true, score: 40)],
      );
      await repository.refreshEntry(
        profile: _profile(id: 'child-high', leaderboardOptIn: true),
        progress: [
          _progress(childId: 'child-high', completed: true, score: 90)
        ],
      );

      final entries = await repository.getTopEntries(age: 3);

      expect(
          entries.map((entry) => entry.childId), ['child-high', 'child-low']);
    });
  });
}

ChildProfile _profile({
  required String id,
  int age = 3,
  bool leaderboardOptIn = false,
  String displayPreference = 'alias',
}) {
  final now = DateTime.utc(2026);
  return ChildProfile(
    id: id,
    parentId: 'parent-1',
    name: 'Ayesha Learner',
    age: age,
    avatarAsset: 'koala-blue',
    leaderboardOptIn: leaderboardOptIn,
    displayPreference: displayPreference,
    createdAt: now,
    updatedAt: now,
    isSynced: true,
  );
}

LevelProgress _progress({
  required String childId,
  bool completed = false,
  int? score,
  int starsEarned = 0,
  bool rewardEarned = false,
}) {
  return LevelProgress(
    childId: childId,
    moduleId: 'math',
    levelId: 'math-1',
    completed: completed,
    score: score,
    starsEarned: starsEarned,
    rewardEarned: rewardEarned,
    updatedAt: DateTime.utc(2026),
    isSynced: true,
  );
}
