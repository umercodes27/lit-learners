import 'package:flutter_test/flutter_test.dart';
import 'package:little_learners/models/learning_level.dart';
import 'package:little_learners/repositories/progress_repository.dart';
import 'package:little_learners/services/local/progress_dao.dart';

void main() {
  group('CachedProgressRepository', () {
    test('completes a level with score, stars, and reward state', () async {
      final repository = CachedProgressRepository(
        progressDao: InMemoryProgressDao(),
      );

      final progress = await repository.completeLevel(
        childId: 'child-1',
        level: _level(),
        score: 92,
      );

      expect(progress.completed, isTrue);
      expect(progress.score, 92);
      expect(progress.starsEarned, 3);
      expect(progress.rewardEarned, isTrue);
      expect(progress.rewardEarnedAt, isNotNull);
      expect(progress.isSynced, isFalse);
    });

    test('records watched video lessons without duplicating lesson ids',
        () async {
      final repository = CachedProgressRepository(
        progressDao: InMemoryProgressDao(),
      );
      final level = _level(type: LevelType.video);

      await repository.recordVideoWatched(
        childId: 'child-1',
        level: level,
        lessonId: 'lesson-1',
      );
      final progress = await repository.recordVideoWatched(
        childId: 'child-1',
        level: level,
        lessonId: 'lesson-1',
      );

      expect(progress.completed, isFalse);
      expect(progress.watchedLessonIds, ['lesson-1']);
      expect(progress.lastWatchedAt, isNotNull);
      expect(progress.isSynced, isFalse);
    });

    test('video watch updates preserve completed progress and reward',
        () async {
      final repository = CachedProgressRepository(
        progressDao: InMemoryProgressDao(),
      );
      final level = _level(type: LevelType.video);

      await repository.completeLevel(
        childId: 'child-1',
        level: level,
        score: 80,
      );
      final progress = await repository.recordVideoWatched(
        childId: 'child-1',
        level: level,
        lessonId: 'lesson-1',
      );

      expect(progress.completed, isTrue);
      expect(progress.score, 80);
      expect(progress.rewardEarned, isTrue);
      expect(progress.watchedLessonIds, ['lesson-1']);
    });
  });
}

LearningLevel _level({LevelType type = LevelType.counting}) {
  return LearningLevel(
    id: 'level-1',
    moduleId: type == LevelType.video ? 'video' : 'math',
    stage: 3,
    levelNumber: 1,
    title: 'Demo',
    subtitle: 'Demo',
    type: type,
    passingScore: 70,
    isBundled: true,
  );
}
