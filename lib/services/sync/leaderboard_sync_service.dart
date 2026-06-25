import '../../models/child_profile.dart';
import '../../repositories/child_profile_repository.dart';
import '../../repositories/leaderboard_repository.dart';
import '../../repositories/progress_repository.dart';
import 'progress_sync_service.dart';
import 'sync_service.dart';

class LeaderboardSyncService {
  const LeaderboardSyncService({
    required ChildProfileRepository childProfileRepository,
    required ProgressRepository progressRepository,
    required LeaderboardRepository leaderboardRepository,
    SyncService? profileSyncService,
    ProgressSyncService? progressSyncService,
  })  : _childProfileRepository = childProfileRepository,
        _progressRepository = progressRepository,
        _leaderboardRepository = leaderboardRepository,
        _profileSyncService = profileSyncService,
        _progressSyncService = progressSyncService;

  final ChildProfileRepository _childProfileRepository;
  final ProgressRepository _progressRepository;
  final LeaderboardRepository _leaderboardRepository;
  final SyncService? _profileSyncService;
  final ProgressSyncService? _progressSyncService;

  Future<void> refreshParent(String parentId) async {
    await _profileSyncService?.syncNow(parentId: parentId);
    final profiles = await _childProfileRepository.getProfiles(parentId);
    for (final profile in profiles) {
      await refreshProfile(profile);
    }
  }

  Future<void> refreshProfile(ChildProfile profile) async {
    await _progressSyncService?.syncNow(childId: profile.id);
    final progress = await _progressRepository.getProgressForChild(profile.id);
    await _leaderboardRepository.refreshEntry(
      profile: profile,
      progress: progress,
    );
  }

  Future<void> removeChild(String childId) {
    return _leaderboardRepository.deleteEntryForChild(childId);
  }
}
