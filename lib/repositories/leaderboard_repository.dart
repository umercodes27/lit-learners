import '../core/utils/age_stage_helper.dart';
import '../models/child_profile.dart';
import '../models/leaderboard_entry.dart';
import '../models/progress.dart';
import '../services/remote/leaderboard_remote_data_source.dart';

abstract class LeaderboardRepository {
  Future<LeaderboardEntry?> refreshEntry({
    required ChildProfile profile,
    required List<LevelProgress> progress,
  });

  Future<List<LeaderboardEntry>> getTopEntries({
    required int age,
    int limit = 20,
  });

  Future<void> deleteEntryForChild(String childId);
}

class RemoteLeaderboardRepository implements LeaderboardRepository {
  const RemoteLeaderboardRepository({
    required LeaderboardRemoteDataSource remoteDataSource,
  }) : _remoteDataSource = remoteDataSource;

  final LeaderboardRemoteDataSource _remoteDataSource;

  @override
  Future<void> deleteEntryForChild(String childId) {
    return _remoteDataSource.deleteEntryForChild(childId);
  }

  @override
  Future<List<LeaderboardEntry>> getTopEntries({
    required int age,
    int limit = 20,
  }) {
    return _remoteDataSource.getTopEntries(
      ageStage: AgeStageHelper.stageForAge(age),
      limit: limit,
    );
  }

  @override
  Future<LeaderboardEntry?> refreshEntry({
    required ChildProfile profile,
    required List<LevelProgress> progress,
  }) async {
    if (!profile.leaderboardOptIn) {
      await _remoteDataSource.deleteEntryForChild(profile.id);
      return null;
    }

    final now = DateTime.now();
    final entry = LeaderboardEntry(
      childId: profile.id,
      parentId: profile.parentId,
      displayName: _displayNameFor(profile),
      ageStage: AgeStageHelper.stageForAge(profile.age),
      totalScore: _totalScore(progress),
      completedLevels: progress.where((item) => item.completed).length,
      totalStars: progress.fold<int>(
        0,
        (total, item) => total + item.starsEarned,
      ),
      rewardCount: progress.where((item) => item.rewardEarned).length,
      lastActivityAt: _lastActivityAt(progress),
      updatedAt: now,
    );
    await _remoteDataSource.upsertEntry(entry);
    return entry;
  }

  String _displayNameFor(ChildProfile profile) {
    if (profile.displayPreference == 'firstName') {
      return profile.name.trim().split(RegExp(r'\s+')).first;
    }

    final suffix = profile.id.length <= 4
        ? profile.id
        : profile.id.substring(profile.id.length - 4);
    return 'Learner $suffix';
  }

  int _totalScore(List<LevelProgress> progress) {
    return progress.fold<int>(0, (total, item) {
      final completionPoints = item.completed ? 100 : 0;
      final quizPoints = item.score ?? 0;
      final starPoints = item.starsEarned * 10;
      final rewardPoints = item.rewardEarned ? 25 : 0;
      return total + completionPoints + quizPoints + starPoints + rewardPoints;
    });
  }

  DateTime? _lastActivityAt(List<LevelProgress> progress) {
    DateTime? latest;
    for (final item in progress) {
      if (latest == null || item.updatedAt.isAfter(latest)) {
        latest = item.updatedAt;
      }
    }
    return latest;
  }
}
