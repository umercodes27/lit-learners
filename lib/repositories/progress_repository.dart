import '../models/learning_level.dart';
import '../models/progress.dart';
import '../services/local/progress_dao.dart';

abstract class ProgressRepository {
  Future<List<LevelProgress>> getProgressForChild(String childId);
  Future<LevelProgress?> getProgressForLevel({
    required String childId,
    required String levelId,
  });
  Future<LevelProgress> completeLevel({
    required String childId,
    required LearningLevel level,
    int? score,
  });
  Future<LevelProgress> recordVideoWatched({
    required String childId,
    required LearningLevel level,
    required String lessonId,
  });
}

class CachedProgressRepository implements ProgressRepository {
  CachedProgressRepository({required ProgressDao progressDao})
      : _progressDao = progressDao;

  final ProgressDao _progressDao;

  @override
  Future<LevelProgress> completeLevel({
    required String childId,
    required LearningLevel level,
    int? score,
  }) async {
    final existing = await getProgressForLevel(
      childId: childId,
      levelId: level.id,
    );
    final now = DateTime.now();
    final progress = LevelProgress(
      childId: childId,
      moduleId: level.moduleId,
      levelId: level.id,
      completed: true,
      score: score ?? existing?.score,
      starsEarned: _starsFor(score, level.passingScore),
      rewardEarned: true,
      rewardEarnedAt: existing?.rewardEarnedAt ?? now,
      watchedLessonIds: existing?.watchedLessonIds ?? const [],
      lastWatchedAt: existing?.lastWatchedAt,
      updatedAt: now,
      isSynced: false,
    );
    await _progressDao.upsert(progress);
    return progress;
  }

  @override
  Future<List<LevelProgress>> getProgressForChild(String childId) async {
    return _progressDao.getByChild(childId);
  }

  @override
  Future<LevelProgress?> getProgressForLevel({
    required String childId,
    required String levelId,
  }) async {
    return _progressDao.getByLevel(childId: childId, levelId: levelId);
  }

  @override
  Future<LevelProgress> recordVideoWatched({
    required String childId,
    required LearningLevel level,
    required String lessonId,
  }) async {
    final existing = await getProgressForLevel(
      childId: childId,
      levelId: level.id,
    );
    final now = DateTime.now();
    final watchedLessonIds = {
      ...?existing?.watchedLessonIds,
      lessonId,
    }.toList();
    final progress = LevelProgress(
      childId: childId,
      moduleId: level.moduleId,
      levelId: level.id,
      completed: existing?.completed ?? false,
      score: existing?.score,
      starsEarned: existing?.starsEarned ?? 0,
      rewardEarned: existing?.rewardEarned ?? false,
      rewardEarnedAt: existing?.rewardEarnedAt,
      watchedLessonIds: watchedLessonIds,
      lastWatchedAt: now,
      updatedAt: now,
      isSynced: false,
    );
    await _progressDao.upsert(progress);
    return progress;
  }

  int _starsFor(int? score, int passingScore) {
    if (score == null) return 3;
    if (score < passingScore) return 0;
    if (score >= 90) return 3;
    if (score >= 75) return 2;
    return 1;
  }
}

class InMemoryProgressRepository extends CachedProgressRepository {
  InMemoryProgressRepository() : super(progressDao: InMemoryProgressDao());
}
