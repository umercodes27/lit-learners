import 'content_sync_service.dart';
import 'leaderboard_sync_service.dart';
import 'progress_sync_service.dart';
import 'sync_orchestrator.dart';
import 'sync_service.dart';

class BackendSyncCoordinator {
  const BackendSyncCoordinator({
    required SyncOrchestrator orchestrator,
    required SyncService profileSyncService,
    required ProgressSyncService progressSyncService,
    required ContentSyncService contentSyncService,
    LeaderboardSyncService? leaderboardSyncService,
  })  : _orchestrator = orchestrator,
        _profileSyncService = profileSyncService,
        _progressSyncService = progressSyncService,
        _contentSyncService = contentSyncService,
        _leaderboardSyncService = leaderboardSyncService;

  final SyncOrchestrator _orchestrator;
  final SyncService _profileSyncService;
  final ProgressSyncService _progressSyncService;
  final ContentSyncService _contentSyncService;
  final LeaderboardSyncService? _leaderboardSyncService;

  Future<SyncOrchestrationReport> syncNow({
    String? parentId,
    String? childId,
    bool includeContent = true,
  }) {
    final tasks = <SyncTask>[
      if (parentId != null)
        SyncTask(
          name: 'child-profile-sync',
          run: () async {
            final report = await _profileSyncService.syncNow(
              parentId: parentId,
            );
            return !report.hasFailures;
          },
        ),
      if (childId != null)
        SyncTask(
          name: 'progress-sync',
          run: () async {
            final report = await _progressSyncService.syncNow(
              childId: childId,
            );
            return !report.hasFailures;
          },
        ),
      if (includeContent)
        SyncTask(
          name: 'content-sync',
          run: () async {
            final report = await _contentSyncService.syncNow();
            return !report.hasFailures;
          },
        ),
      if (parentId != null && _leaderboardSyncService != null)
        SyncTask(
          name: 'leaderboard-sync',
          run: () async {
            await _leaderboardSyncService.refreshParent(parentId);
            return true;
          },
        ),
    ];

    return _orchestrator.run(tasks);
  }
}
