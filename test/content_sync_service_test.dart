import 'package:flutter_test/flutter_test.dart';
import 'package:little_learners/data/seed_content.dart';
import 'package:little_learners/models/content_item.dart';
import 'package:little_learners/models/learning_level.dart';
import 'package:little_learners/models/learning_module.dart';
import 'package:little_learners/models/quiz_question.dart';
import 'package:little_learners/models/video_lesson.dart';
import 'package:little_learners/services/local/content_dao.dart';
import 'package:little_learners/services/remote/content_remote_data_source.dart';
import 'package:little_learners/services/sync/content_sync_service.dart';

void main() {
  group('ContentSyncService', () {
    test('adds a remote published bundle on top of the bundled curriculum',
        () async {
      final dao = InMemoryContentDao();
      final remote = InMemoryContentRemoteDataSource(
        modules: [_adminModule()],
        levels: [_adminLevel()],
      );
      final service = ContentSyncService(
        contentDao: dao,
        contentRemoteDataSource: remote,
      );

      await dao.seedContent(modules: seedModules, levels: seedLevels);

      final report = await service.syncNow();
      final modules = await dao.getModules();
      final level = await dao.getLevelById('admin-math-stage3-1');

      expect(report.didApplyRemoteContent, isTrue);
      expect(report.modulesPulled, 1);
      expect(report.levelsPulled, 1);

      expect(modules.map((module) => module.id), contains('admin-math'));
      expect(level?.contentItems, hasLength(1));
      expect(level?.quizQuestions, hasLength(1));
      expect(level?.videoLessons, hasLength(1));

      // The regression this guards. Publishing a single module from the admin
      // panel used to empty the content tables and write only that module, so
      // a parent going back to the dashboard found the entire shipped
      // curriculum gone and one lonely new module in its place.
      expect(
        modules.map((module) => module.id),
        containsAll(seedModules.map((module) => module.id)),
      );
      expect(modules, hasLength(seedModules.length + 1));
      expect(await dao.getLevelById('math-stage3-1'), isNotNull);
    });

    test('a remote module reusing a bundled id overrides it, not duplicates it',
        () async {
      final dao = InMemoryContentDao();
      const override = LearningModule(
        id: 'math',
        title: 'Maths, rewritten by an admin',
        description: 'Edited remotely.',
        category: ModuleCategory.math,
        minStage: 1,
        maxStage: 4,
        order: 1,
      );
      final service = ContentSyncService(
        contentDao: dao,
        contentRemoteDataSource:
            InMemoryContentRemoteDataSource(modules: [override], levels: []),
      );

      await dao.seedContent(modules: seedModules, levels: seedLevels);
      await service.syncNow();

      final modules = await dao.getModules();
      expect(modules, hasLength(seedModules.length));
      expect(
        modules.firstWhere((module) => module.id == 'math').title,
        'Maths, rewritten by an admin',
      );
    });

    test('keeps local content when remote bundle is empty', () async {
      final dao = InMemoryContentDao();
      final service = ContentSyncService(
        contentDao: dao,
        contentRemoteDataSource: InMemoryContentRemoteDataSource(),
      );

      await dao.seedContent(modules: seedModules, levels: seedLevels);

      final report = await service.syncNow();

      expect(report.didApplyRemoteContent, isFalse);
      expect(await dao.getModules(), hasLength(seedModules.length));
    });

    test('preserves downloaded state for matching remote levels', () async {
      final dao = InMemoryContentDao();
      final remoteLevel = _adminLevel().copyWith(isDownloaded: false);
      final service = ContentSyncService(
        contentDao: dao,
        contentRemoteDataSource: InMemoryContentRemoteDataSource(
          modules: [_adminModule()],
          levels: [remoteLevel],
        ),
      );

      await dao.seedContent(
        modules: [_adminModule()],
        levels: [remoteLevel],
      );
      await dao.markLevelDownloaded(remoteLevel.id);

      await service.syncNow();
      final syncedLevel = await dao.getLevelById(remoteLevel.id);

      expect(syncedLevel?.isDownloaded, isTrue);
      expect(syncedLevel?.isAvailableOffline, isTrue);
    });
  });
}

LearningModule _adminModule() {
  return const LearningModule(
    id: 'admin-math',
    title: 'Admin Math',
    description: 'Remote math lessons.',
    category: ModuleCategory.math,
    minStage: 1,
    maxStage: 4,
    order: 1,
  );
}

LearningLevel _adminLevel() {
  return const LearningLevel(
    id: 'admin-math-stage3-1',
    moduleId: 'admin-math',
    stage: 3,
    levelNumber: 1,
    title: 'Remote Counting',
    subtitle: 'Synced from admin content.',
    type: LevelType.counting,
    passingScore: 70,
    isBundled: false,
    contentItems: [
      ContentItem(
        title: 'Six',
        prompt: 'Count six dots.',
        displayText: '6',
        visualLabel: 'Six dots',
      ),
    ],
    quizQuestions: [
      QuizQuestion(
        id: 'admin-q1',
        prompt: 'How many dots?',
        options: ['5', '6', '7'],
        correctIndex: 1,
      ),
    ],
    videoLessons: [
      VideoLesson(
        id: 'admin-video-1',
        title: 'Six Dots',
        description: 'Count six dots together.',
        durationLabel: '0:15',
        videoUrl: 'https://example.com/six-dots.mp4',
        thumbnailLabel: 'Six dots video',
      ),
    ],
  );
}
