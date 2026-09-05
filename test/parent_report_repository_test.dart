import 'package:flutter_test/flutter_test.dart';
import 'package:little_learners/data/seed_content.dart';
import 'package:little_learners/repositories/child_profile_repository.dart';
import 'package:little_learners/repositories/content_repository.dart';
import 'package:little_learners/models/learning_level.dart';
import 'package:little_learners/repositories/parent_report_repository.dart';
import 'package:little_learners/repositories/progress_repository.dart';
import 'package:little_learners/services/local/child_profile_dao.dart';
import 'package:little_learners/services/local/content_dao.dart';
import 'package:little_learners/services/local/sync_outbox_dao.dart';

void main() {
  group('CachedParentReportRepository', () {
    test('aggregates profile, progress, quiz, reward, and video data',
        () async {
      final profileDao = InMemoryChildProfileDao();
      final childProfileRepository = CachedChildProfileRepository(
        profileDao: profileDao,
        syncOutboxDao: InMemorySyncOutboxDao(),
      );
      final contentRepository = CachedContentRepository(
        contentDao: InMemoryContentDao(),
      );
      final progressRepository = InMemoryProgressRepository();
      final reportRepository = CachedParentReportRepository(
        childProfileRepository: childProfileRepository,
        progressRepository: progressRepository,
        contentRepository: contentRepository,
      );

      final child = await childProfileRepository.createProfile(
        parentId: 'parent-1',
        name: 'Aya',
        age: 3,
        avatarAsset: 'koala-blue',
        leaderboardOptIn: true,
        displayPreference: 'firstName',
      );
      await profileDao.markSynced(child.id);

      final mathLevel = seedLevels.firstWhere((level) {
        return level.id == 'math-stage3-1';
      });
      final videoLevel = seedLevels.firstWhere((level) {
        return level.id == 'video-stage3-1';
      });

      await progressRepository.completeLevel(
        childId: child.id,
        level: mathLevel,
        score: 92,
      );
      await progressRepository.recordVideoWatched(
        childId: child.id,
        level: videoLevel,
        lessonId: videoLevel.videoLessons.first.id,
      );

      final report = await reportRepository.getReport('parent-1');
      final childReport = report.childReports.single;
      final videoReport = childReport.progressReports.firstWhere(
        (report) => report.progress.levelId == videoLevel.id,
      );

      expect(report.childCount, 1);
      expect(report.completedLevels, 1);
      expect(report.totalStars, 3);
      expect(report.averageQuizScore, 92);
      expect(report.watchedVideoLessons, 1);
      expect(report.rewardsEarned, 1);
      expect(childReport.profile.isSynced, isTrue);
      expect(childReport.averageQuizScore, 92);
      expect(videoReport.levelTitle, 'Watch and Count');
      expect(videoReport.moduleTitle, 'Video Learning');
      expect(videoReport.watchedLessonTitles, ['Counting Bees']);
    });

    test('names an age-pack activity rather than printing its id', () async {
      final profileDao = InMemoryChildProfileDao();
      final childProfileRepository = CachedChildProfileRepository(
        profileDao: profileDao,
        syncOutboxDao: InMemorySyncOutboxDao(),
      );
      final progressRepository = InMemoryProgressRepository();
      final reportRepository = CachedParentReportRepository(
        childProfileRepository: childProfileRepository,
        progressRepository: progressRepository,
        contentRepository: CachedContentRepository(
          contentDao: InMemoryContentDao(),
        ),
      );

      final child = await childProfileRepository.createProfile(
        parentId: 'parent-1',
        name: 'Aya',
        age: 3,
        avatarAsset: 'koala-blue',
        leaderboardOptIn: true,
        displayPreference: 'firstName',
      );

      // A pack activity is played from JSON, so there is no level row for the
      // report to look up - only the id progress was recorded against.
      await progressRepository.completeLevel(
        childId: child.id,
        level: const LearningLevel(
          id: 'pack:urdu:level_2',
          moduleId: 'urdu',
          stage: 2,
          levelNumber: 2,
          title: 'Drawn only',
          subtitle: '',
          type: LevelType.flashcards,
          passingScore: 0,
          isBundled: true,
        ),
      );

      final report = await reportRepository.getReport('parent-1');
      final entry = report.childReports.single.progressReports.single;

      expect(entry.levelTitle, 'Level 2');
      // The module id is real, so the module still resolves by the usual path
      // - under its own name, which for Urdu is written in Urdu.
      expect(entry.moduleTitle, 'اردو');
    });
  });
}
