import 'package:flutter/foundation.dart';

import '../models/leaderboard_entry.dart';
import '../repositories/leaderboard_repository.dart';
import '../services/sync/leaderboard_sync_service.dart';

class LeaderboardViewModel extends ChangeNotifier {
  LeaderboardViewModel({
    required LeaderboardRepository leaderboardRepository,
    LeaderboardSyncService? leaderboardSyncService,
  })  : _leaderboardRepository = leaderboardRepository,
        _leaderboardSyncService = leaderboardSyncService;

  final LeaderboardRepository _leaderboardRepository;
  final LeaderboardSyncService? _leaderboardSyncService;

  int _selectedStage = 0;
  List<LeaderboardEntry> _entries = [];
  bool _isLoading = false;
  String? _errorMessage;

  int get selectedStage => _selectedStage;
  List<LeaderboardEntry> get entries => List.unmodifiable(_entries);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> loadLeaderboard({
    String? parentId,
    int? stage,
  }) async {
    _selectedStage = stage ?? _selectedStage;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (parentId != null) {
        await _leaderboardSyncService?.refreshParent(parentId);
      }

      final entries = <LeaderboardEntry>[];
      if (_selectedStage == 0) {
        for (var age = 1; age <= 4; age++) {
          entries.addAll(
            await _leaderboardRepository.getTopEntries(age: age, limit: 10),
          );
        }
      } else {
        entries.addAll(
          await _leaderboardRepository.getTopEntries(
            age: _selectedStage,
            limit: 20,
          ),
        );
      }

      entries.sort(_sortEntries);
      _entries = entries.take(20).toList();
    } catch (_) {
      _errorMessage = 'Leaderboard could not load.';
    }

    _isLoading = false;
    notifyListeners();
  }

  int rankFor(LeaderboardEntry entry) {
    final index = _entries.indexOf(entry);
    return index < 0 ? 0 : index + 1;
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
}
