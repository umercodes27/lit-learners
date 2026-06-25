import 'package:flutter_test/flutter_test.dart';
import 'package:little_learners/models/progress.dart';
import 'package:little_learners/services/local/progress_dao.dart';
import 'package:little_learners/services/remote/progress_remote_data_source.dart';
import 'package:little_learners/services/sync/progress_sync_service.dart';

void main() {
  group('ProgressSyncService', () {
    test('pushes unsynced progress and marks it synced', () async {
      final dao = InMemoryProgressDao();
      final remote = InMemoryProgressRemoteDataSource();
      final service = ProgressSyncService(
        progressDao: dao,
        progressRemoteDataSource: remote,
      );

      await dao.upsert(_progress(isSynced: false));

      final report = await service.syncNow(childId: 'child-1');
      final cachedProgress = await dao.getByLevel(
        childId: 'child-1',
        levelId: 'level-1',
      );

      expect(report.pushedProgress, 1);
      expect(report.failedItems, 0);
      expect(remote.progress, hasLength(1));
      expect(cachedProgress?.isSynced, isTrue);
    });

    test('pulls remote progress into the local cache', () async {
      final dao = InMemoryProgressDao();
      final remote = InMemoryProgressRemoteDataSource();
      final service = ProgressSyncService(
        progressDao: dao,
        progressRemoteDataSource: remote,
      );

      await remote.upsertProgress(_progress(levelId: 'remote-level'));

      final report = await service.syncNow(childId: 'child-1');
      final cachedProgress = await dao.getByLevel(
        childId: 'child-1',
        levelId: 'remote-level',
      );

      expect(report.pulledProgress, 1);
      expect(report.failedItems, 0);
      expect(cachedProgress?.completed, isTrue);
      expect(cachedProgress?.isSynced, isTrue);
    });

    test('skips remote pull when local progress push fails', () async {
      final dao = InMemoryProgressDao();
      final remote = _FailingProgressRemoteDataSource([
        _progress(
          isSynced: true,
          score: 70,
          updatedAt: DateTime.utc(2026, 1, 1),
        ),
      ]);
      final service = ProgressSyncService(
        progressDao: dao,
        progressRemoteDataSource: remote,
      );

      await dao.upsert(
        _progress(
          isSynced: false,
          score: 95,
          updatedAt: DateTime.utc(2026, 1, 2),
        ),
      );

      final report = await service.syncNow(childId: 'child-1');
      final cachedProgress = await dao.getByLevel(
        childId: 'child-1',
        levelId: 'level-1',
      );

      expect(report.failedItems, 1);
      expect(report.pulledProgress, 0);
      expect(cachedProgress?.score, 95);
      expect(cachedProgress?.isSynced, isFalse);
    });
  });
}

LevelProgress _progress({
  String childId = 'child-1',
  String levelId = 'level-1',
  bool isSynced = true,
  int? score = 90,
  DateTime? updatedAt,
}) {
  final now = updatedAt ?? DateTime.utc(2026, 1, 1);
  return LevelProgress(
    childId: childId,
    moduleId: 'math',
    levelId: levelId,
    completed: true,
    score: score,
    starsEarned: 3,
    rewardEarned: true,
    rewardEarnedAt: now,
    watchedLessonIds: const [],
    updatedAt: now,
    isSynced: isSynced,
  );
}

class _FailingProgressRemoteDataSource implements ProgressRemoteDataSource {
  const _FailingProgressRemoteDataSource(this._progress);

  final List<LevelProgress> _progress;

  @override
  Future<List<LevelProgress>> getProgressForChild(String childId) async {
    return _progress.where((progress) => progress.childId == childId).toList();
  }

  @override
  Future<void> upsertProgress(LevelProgress progress) async {
    throw Exception('Push failed');
  }
}
