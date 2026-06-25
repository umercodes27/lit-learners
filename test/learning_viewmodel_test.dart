import 'package:flutter_test/flutter_test.dart';
import 'package:little_learners/data/seed_content.dart';
import 'package:little_learners/models/child_profile.dart';
import 'package:little_learners/repositories/content_repository.dart';
import 'package:little_learners/repositories/progress_repository.dart';
import 'package:little_learners/services/local/content_dao.dart';
import 'package:little_learners/viewmodels/learning_viewmodel.dart';

void main() {
  test('LearningViewModel downloads an unlocked cached level', () async {
    final contentRepository = CachedContentRepository(
      contentDao: InMemoryContentDao(),
    );
    final progressRepository = InMemoryProgressRepository();
    final viewModel = LearningViewModel(
      contentRepository: contentRepository,
      progressRepository: progressRepository,
    );
    final child = ChildProfile(
      id: 'child-1',
      parentId: 'parent-1',
      name: 'Aya',
      age: 3,
      avatarAsset: 'koala-blue',
      leaderboardOptIn: false,
      displayPreference: 'alias',
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
      isSynced: true,
    );

    await viewModel.loadForProfile(child);
    await viewModel.loadLevelsForModule('math');

    final firstLevel = seedLevels.firstWhere((level) {
      return level.id == 'math-stage3-1';
    });
    await viewModel.completeLevel(child.id, firstLevel, score: 90);
    await viewModel.loadLevelsForModule('math');

    var nextLevel = viewModel.levelsFor('math').firstWhere((level) {
      return level.id == 'math-stage3-2';
    });

    expect(viewModel.canDownloadLevel(nextLevel), isTrue);
    expect(viewModel.canOpenLevel(nextLevel), isFalse);

    await viewModel.downloadLevel(nextLevel);

    nextLevel = viewModel.levelsFor('math').firstWhere((level) {
      return level.id == 'math-stage3-2';
    });

    expect(viewModel.canDownloadLevel(nextLevel), isFalse);
    expect(viewModel.canOpenLevel(nextLevel), isTrue);
  });

  test('LearningViewModel records watched video lesson progress', () async {
    final contentRepository = CachedContentRepository(
      contentDao: InMemoryContentDao(),
    );
    final progressRepository = InMemoryProgressRepository();
    final viewModel = LearningViewModel(
      contentRepository: contentRepository,
      progressRepository: progressRepository,
    );
    final child = ChildProfile(
      id: 'child-1',
      parentId: 'parent-1',
      name: 'Aya',
      age: 3,
      avatarAsset: 'koala-blue',
      leaderboardOptIn: false,
      displayPreference: 'alias',
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
      isSynced: true,
    );
    final videoLevel = seedLevels.firstWhere((level) {
      return level.id == 'video-stage3-1';
    });

    await viewModel.loadForProfile(child);
    final progress = await viewModel.recordVideoWatched(
      childId: child.id,
      level: videoLevel,
      lessonId: videoLevel.videoLessons.first.id,
    );

    expect(progress.completed, isFalse);
    expect(progress.watchedLessonIds, [videoLevel.videoLessons.first.id]);
    expect(progress.lastWatchedAt, isNotNull);
  });
}
