import '../local/progress_dao.dart';
import '../remote/progress_remote_data_source.dart';

class ProgressSyncReport {
  const ProgressSyncReport({
    required this.pushedProgress,
    required this.pulledProgress,
    required this.failedItems,
  });

  final int pushedProgress;
  final int pulledProgress;
  final int failedItems;

  bool get hasFailures => failedItems > 0;
}

class ProgressSyncService {
  ProgressSyncService({
    required ProgressDao progressDao,
    required ProgressRemoteDataSource progressRemoteDataSource,
  })  : _progressDao = progressDao,
        _progressRemoteDataSource = progressRemoteDataSource;

  final ProgressDao _progressDao;
  final ProgressRemoteDataSource _progressRemoteDataSource;

  Future<ProgressSyncReport> syncNow({required String childId}) async {
    var pushedProgress = 0;
    var pulledProgress = 0;
    var failedItems = 0;

    final unsyncedProgress = await _progressDao.getUnsynced();
    for (final progress in unsyncedProgress) {
      try {
        await _progressRemoteDataSource.upsertProgress(progress);
        await _progressDao.markSynced(
          childId: progress.childId,
          levelId: progress.levelId,
        );
        pushedProgress += 1;
      } catch (error) {
        failedItems += 1;
      }
    }

    if (failedItems == 0) {
      try {
        final remoteProgress =
            await _progressRemoteDataSource.getProgressForChild(childId);
        for (final progress in remoteProgress) {
          final existing = await _progressDao.getByLevel(
            childId: progress.childId,
            levelId: progress.levelId,
          );
          if (existing != null &&
              !existing.isSynced &&
              existing.updatedAt.isAfter(progress.updatedAt)) {
            continue;
          }

          await _progressDao.upsert(progress.copyWith(isSynced: true));
          pulledProgress += 1;
        }
      } catch (error) {
        failedItems += 1;
      }
    }

    return ProgressSyncReport(
      pushedProgress: pushedProgress,
      pulledProgress: pulledProgress,
      failedItems: failedItems,
    );
  }
}
