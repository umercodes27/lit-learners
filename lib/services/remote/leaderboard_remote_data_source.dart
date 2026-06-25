import '../../models/leaderboard_entry.dart';

abstract class LeaderboardRemoteDataSource {
  Future<List<LeaderboardEntry>> getTopEntries({
    required int ageStage,
    int limit = 20,
  });

  Future<void> upsertEntry(LeaderboardEntry entry);

  Future<void> deleteEntry({
    required int ageStage,
    required String childId,
  });

  Future<void> deleteEntryForChild(String childId);
}

class InMemoryLeaderboardRemoteDataSource
    implements LeaderboardRemoteDataSource {
  final Map<String, LeaderboardEntry> _entriesByChildId = {};

  List<LeaderboardEntry> get entries =>
      List.unmodifiable(_entriesByChildId.values);

  @override
  Future<void> deleteEntry({
    required int ageStage,
    required String childId,
  }) async {
    final entry = _entriesByChildId[childId];
    if (entry?.ageStage == ageStage) {
      _entriesByChildId.remove(childId);
    }
  }

  @override
  Future<void> deleteEntryForChild(String childId) async {
    _entriesByChildId.remove(childId);
  }

  @override
  Future<List<LeaderboardEntry>> getTopEntries({
    required int ageStage,
    int limit = 20,
  }) async {
    final sortedEntries = _entriesByChildId.values
        .where((entry) => entry.ageStage == ageStage)
        .toList()
      ..sort(_sortEntries);
    return sortedEntries.take(limit).toList();
  }

  @override
  Future<void> upsertEntry(LeaderboardEntry entry) async {
    _entriesByChildId[entry.childId] = entry;
  }
}

int _sortEntries(LeaderboardEntry a, LeaderboardEntry b) {
  final scoreCompare = b.totalScore.compareTo(a.totalScore);
  if (scoreCompare != 0) return scoreCompare;

  final starsCompare = b.totalStars.compareTo(a.totalStars);
  if (starsCompare != 0) return starsCompare;

  final aActivity = a.lastActivityAt ?? a.updatedAt;
  final bActivity = b.lastActivityAt ?? b.updatedAt;
  return bActivity.compareTo(aActivity);
}
