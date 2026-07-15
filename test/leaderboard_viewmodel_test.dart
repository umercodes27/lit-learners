import 'package:flutter_test/flutter_test.dart';
import 'package:little_learners/models/child_profile.dart';
import 'package:little_learners/models/leaderboard_entry.dart';
import 'package:little_learners/models/progress.dart';
import 'package:little_learners/repositories/leaderboard_repository.dart';
import 'package:little_learners/viewmodels/leaderboard_viewmodel.dart';

void main() {
  test('LeaderboardViewModel loads and sorts all stage entries', () async {
    final repository = _FakeLeaderboardRepository({
      3: [
        _entry(childId: 'low', stage: 3, totalScore: 100),
        _entry(childId: 'high', stage: 3, totalScore: 300),
      ],
      4: [
        _entry(childId: 'middle', stage: 4, totalScore: 200),
      ],
    });
    final viewModel = LeaderboardViewModel(
      leaderboardRepository: repository,
    );

    await viewModel.loadLeaderboard(stage: 0);

    expect(
      viewModel.entries.map((entry) => entry.childId),
      ['high', 'middle', 'low'],
    );
    expect(viewModel.selectedStage, 0);
  });

  test('LeaderboardViewModel loads a selected stage only', () async {
    final repository = _FakeLeaderboardRepository({
      2: [_entry(childId: 'stage-two', stage: 2, totalScore: 200)],
      4: [_entry(childId: 'stage-four', stage: 4, totalScore: 400)],
    });
    final viewModel = LeaderboardViewModel(
      leaderboardRepository: repository,
    );

    await viewModel.loadLeaderboard(stage: 2);

    expect(viewModel.entries.single.childId, 'stage-two');
    expect(viewModel.selectedStage, 2);
  });
}

class _FakeLeaderboardRepository implements LeaderboardRepository {
  const _FakeLeaderboardRepository(this.entriesByAge);

  final Map<int, List<LeaderboardEntry>> entriesByAge;

  @override
  Future<void> deleteEntryForChild(String childId) async {}

  @override
  Future<List<LeaderboardEntry>> getTopEntries({
    required int age,
    int limit = 20,
  }) async {
    return (entriesByAge[age] ?? const []).take(limit).toList();
  }

  @override
  Future<LeaderboardEntry?> refreshEntry({
    required ChildProfile profile,
    required List<LevelProgress> progress,
  }) async {
    return null;
  }
}

LeaderboardEntry _entry({
  required String childId,
  required int stage,
  required int totalScore,
}) {
  return LeaderboardEntry(
    childId: childId,
    parentId: 'parent',
    displayName: 'Learner $childId',
    ageStage: stage,
    totalScore: totalScore,
    completedLevels: totalScore ~/ 100,
    totalStars: totalScore ~/ 10,
    rewardCount: 1,
    updatedAt: DateTime.utc(2026),
  );
}
