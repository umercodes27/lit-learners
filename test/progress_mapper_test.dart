import 'package:flutter_test/flutter_test.dart';
import 'package:little_learners/models/progress.dart';
import 'package:little_learners/services/local/progress_mapper.dart';

void main() {
  test('ProgressMapper round-trips local map values', () {
    final now = DateTime.utc(2026, 1, 1, 12);
    final progress = LevelProgress(
      childId: 'child-1',
      moduleId: 'video',
      levelId: 'video-stage3-1',
      completed: true,
      score: 85,
      starsEarned: 2,
      rewardEarned: true,
      rewardEarnedAt: now,
      watchedLessonIds: const ['lesson-1', 'lesson-2'],
      lastWatchedAt: now,
      updatedAt: now,
      isSynced: false,
    );

    final mapped = ProgressMapper.fromLocalMap(
      ProgressMapper.toLocalMap(progress),
    );

    expect(mapped.childId, progress.childId);
    expect(mapped.moduleId, progress.moduleId);
    expect(mapped.levelId, progress.levelId);
    expect(mapped.completed, progress.completed);
    expect(mapped.score, progress.score);
    expect(mapped.starsEarned, progress.starsEarned);
    expect(mapped.rewardEarned, progress.rewardEarned);
    expect(mapped.rewardEarnedAt, progress.rewardEarnedAt);
    expect(mapped.watchedLessonIds, progress.watchedLessonIds);
    expect(mapped.lastWatchedAt, progress.lastWatchedAt);
    expect(mapped.updatedAt, progress.updatedAt);
    expect(mapped.isSynced, progress.isSynced);
  });
}
