import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_learners/core/utils/learning_text_direction.dart';
import 'package:little_learners/data/seed_content.dart';
import 'package:little_learners/models/content_item.dart';
import 'package:little_learners/models/learning_level.dart';
import 'package:little_learners/models/learning_module.dart';
import 'package:little_learners/repositories/content_repository.dart';
import 'package:little_learners/services/local/content_dao.dart';
import 'package:little_learners/services/remote/content_remote_data_source.dart';
import 'package:little_learners/services/sync/content_sync_service.dart';

void main() {
  group('CachedContentRepository', () {
    test('seeds bundled content on first read', () async {
      final dao = InMemoryContentDao();
      final repository = CachedContentRepository(contentDao: dao);

      final modules = await repository.getModulesForStage(3);

      expect(modules.map((module) => module.id), contains('math'));
      expect(await dao.hasModules(), isTrue);
    });

    test('returns exact stage levels before fallback levels', () async {
      final repository = CachedContentRepository(
        contentDao: InMemoryContentDao(),
        bundledModules: seedModules,
        bundledLevels: seedLevels,
      );

      final stageThree = await repository.getLevelsForModule(
        moduleId: 'math',
        stage: 3,
      );
      final stageFour = await repository.getLevelsForModule(
        moduleId: 'math',
        stage: 4,
      );

      expect(stageThree.map((level) => level.id), contains('math-stage3-1'));
      expect(stageFour.map((level) => level.stage).toSet(), {3});
    });

    test('returns full cached level by id with quiz questions', () async {
      final repository = CachedContentRepository(
        contentDao: InMemoryContentDao(),
      );

      final level = await repository.getLevelById('math-stage3-1');

      expect(level?.title, 'Count to 5');
      expect(level?.quizQuestions, hasLength(2));
    });

    test('loads Urdu stage content with RTL text and audio cue keys', () async {
      final repository = CachedContentRepository(
        contentDao: InMemoryContentDao(),
        bundledModules: seedModules,
        bundledLevels: seedLevels,
      );

      final modules = await repository.getModulesForStage(3);
      final urduModule = modules.singleWhere((module) => module.id == 'urdu');
      final stageOneLevels = await repository.getLevelsForModule(
        moduleId: 'urdu',
        stage: 1,
      );
      final stageThreeLevels = await repository.getLevelsForModule(
        moduleId: 'urdu',
        stage: 3,
      );

      expect(urduModule.title, 'اردو');
      expect(LearningTextDirection.forModule(urduModule), TextDirection.rtl);
      expect(
        LearningTextDirection.fontFamilyFor(TextDirection.rtl),
        LearningTextDirection.urduFontFamily,
      );
      expect(
        LearningTextDirection.fontFamilyForText('انار'),
        LearningTextDirection.urduFontFamily,
      );
      expect(
        LearningTextDirection.styleFor(
          const TextStyle(fontSize: 16),
          TextDirection.rtl,
        )?.fontFamily,
        LearningTextDirection.urduFontFamily,
      );
      expect(stageOneLevels.map((level) => level.id), ['urdu-stage1-1']);
      expect(
        stageThreeLevels.map((level) => level.id),
        ['urdu-stage3-1', 'urdu-stage3-2'],
      );
      expect(stageThreeLevels.first.contentItems.first.displayText, 'ا');
      expect(
          stageThreeLevels.first.contentItems.first.audioCueKey, 'urdu_alif');
      expect(
        LearningTextDirection.forLevel(stageThreeLevels.first),
        TextDirection.rtl,
      );
    });

    test('loads staged Logic thinking skills with downloadable practice',
        () async {
      final repository = CachedContentRepository(
        contentDao: InMemoryContentDao(),
        bundledModules: seedModules,
        bundledLevels: seedLevels,
      );

      final modules = await repository.getModulesForStage(4);
      final logicModule = modules.singleWhere(
        (module) => module.id == 'logic',
      );
      final stageOneLevels = await repository.getLevelsForModule(
        moduleId: 'logic',
        stage: 1,
      );
      final stageThreeLevels = await repository.getLevelsForModule(
        moduleId: 'logic',
        stage: 3,
      );
      final stageFourLevels = await repository.getLevelsForModule(
        moduleId: 'logic',
        stage: 4,
      );

      expect(logicModule.category, ModuleCategory.logic);
      expect(logicModule.title, 'Logic');
      expect(stageOneLevels.map((level) => level.id), ['logic-stage1-1']);
      expect(
        stageThreeLevels.map((level) => level.id),
        ['logic-stage3-1', 'logic-stage3-2'],
      );
      expect(stageThreeLevels.first.type, LevelType.matching);
      expect(stageThreeLevels.first.contentItems.first.title, 'Blue');
      expect(
        stageThreeLevels.first.contentItems.first.audioCueKey,
        'logic_blue',
      );
      expect(stageThreeLevels.first.quizQuestions, hasLength(2));
      expect(stageThreeLevels.last.isBundled, isFalse);
      expect(stageFourLevels.map((level) => level.id), [
        'logic-stage4-1',
        'logic-stage4-2',
      ]);
      expect(stageFourLevels.last.isAvailableOffline, isFalse);
    });

    test('loads staged Storytelling content with downloadable sequencing',
        () async {
      final repository = CachedContentRepository(
        contentDao: InMemoryContentDao(),
        bundledModules: seedModules,
        bundledLevels: seedLevels,
      );

      final modules = await repository.getModulesForStage(4);
      final storyModule = modules.singleWhere(
        (module) => module.id == 'story',
      );
      final stageOneLevels = await repository.getLevelsForModule(
        moduleId: 'story',
        stage: 1,
      );
      final stageThreeLevels = await repository.getLevelsForModule(
        moduleId: 'story',
        stage: 3,
      );
      final stageFourLevels = await repository.getLevelsForModule(
        moduleId: 'story',
        stage: 4,
      );

      expect(storyModule.category, ModuleCategory.story);
      expect(storyModule.title, 'Stories');
      expect(stageOneLevels.map((level) => level.id), ['story-stage1-1']);
      expect(
        stageThreeLevels.map((level) => level.id),
        ['story-stage3-1', 'story-stage3-2'],
      );
      expect(stageThreeLevels.first.type, LevelType.story);
      expect(stageThreeLevels.first.contentItems.first.title, 'Beginning');
      expect(
        stageThreeLevels.first.contentItems.first.audioCueKey,
        'story_kite_start',
      );
      expect(stageThreeLevels.first.quizQuestions, hasLength(2));
      expect(stageThreeLevels.last.isBundled, isFalse);
      expect(stageFourLevels.map((level) => level.id), [
        'story-stage4-1',
        'story-stage4-2',
      ]);
      expect(stageFourLevels.last.isAvailableOffline, isFalse);
    });

    test('loads staged Drawing content with downloadable coloring practice',
        () async {
      final repository = CachedContentRepository(
        contentDao: InMemoryContentDao(),
        bundledModules: seedModules,
        bundledLevels: seedLevels,
      );

      final modules = await repository.getModulesForStage(4);
      final drawingModule = modules.singleWhere(
        (module) => module.id == 'drawing',
      );
      final stageOneLevels = await repository.getLevelsForModule(
        moduleId: 'drawing',
        stage: 1,
      );
      final stageThreeLevels = await repository.getLevelsForModule(
        moduleId: 'drawing',
        stage: 3,
      );
      final stageFourLevels = await repository.getLevelsForModule(
        moduleId: 'drawing',
        stage: 4,
      );

      expect(drawingModule.category, ModuleCategory.drawing);
      expect(drawingModule.title, 'Drawing');
      expect(stageOneLevels.map((level) => level.id), ['drawing-stage1-1']);
      expect(
        stageThreeLevels.map((level) => level.id),
        ['drawing-stage3-1', 'drawing-stage3-2'],
      );
      expect(stageThreeLevels.first.type, LevelType.drawing);
      expect(stageThreeLevels.first.contentItems.first.title, 'Triangle');
      expect(
        stageThreeLevels.first.contentItems.first.audioCueKey,
        'drawing_triangle',
      );
      expect(stageThreeLevels.first.quizQuestions, hasLength(2));
      expect(stageThreeLevels.last.isBundled, isFalse);
      expect(stageFourLevels.map((level) => level.id), [
        'drawing-stage4-1',
        'drawing-stage4-2',
      ]);
      expect(stageFourLevels.last.isAvailableOffline, isFalse);
    });

    test('loads staged English phonics content with downloadable practice',
        () async {
      final repository = CachedContentRepository(
        contentDao: InMemoryContentDao(),
        bundledModules: seedModules,
        bundledLevels: seedLevels,
      );

      final modules = await repository.getModulesForStage(4);
      final englishModule = modules.singleWhere(
        (module) => module.id == 'english',
      );
      final stageOneLevels = await repository.getLevelsForModule(
        moduleId: 'english',
        stage: 1,
      );
      final stageThreeLevels = await repository.getLevelsForModule(
        moduleId: 'english',
        stage: 3,
      );
      final stageFourLevels = await repository.getLevelsForModule(
        moduleId: 'english',
        stage: 4,
      );

      expect(englishModule.title, 'English');
      expect(
        LearningTextDirection.forModule(englishModule),
        TextDirection.ltr,
      );
      expect(stageOneLevels.map((level) => level.id), ['english-stage1-1']);
      expect(
        stageThreeLevels.map((level) => level.id),
        ['english-stage3-1', 'english-stage3-2'],
      );
      expect(stageThreeLevels.first.quizQuestions, hasLength(2));
      expect(stageThreeLevels.last.isBundled, isFalse);
      expect(stageThreeLevels.last.isAvailableOffline, isFalse);
      expect(stageFourLevels.map((level) => level.id), [
        'english-stage4-1',
        'english-stage4-2',
      ]);
      expect(stageFourLevels.first.contentItems.first.displayText, 'Cat');
      expect(
        stageFourLevels.first.contentItems.first.audioCueKey,
        'english_cat',
      );
    });

    test('marks a cached level downloaded', () async {
      final repository = CachedContentRepository(
        contentDao: InMemoryContentDao(),
      );

      final before = await repository.getLevelById('math-stage3-2');

      expect(before?.isAvailableOffline, isFalse);

      await repository.markLevelDownloaded('math-stage3-2');

      final after = await repository.getLevelById('math-stage3-2');

      expect(after?.isDownloaded, isTrue);
      expect(after?.isAvailableOffline, isTrue);
    });

    test('syncs remote admin content on first read when service is provided',
        () async {
      final dao = InMemoryContentDao();
      final syncService = ContentSyncService(
        contentDao: dao,
        contentRemoteDataSource: InMemoryContentRemoteDataSource(
          modules: [_remoteModule()],
          levels: [_remoteLevel()],
        ),
      );
      final repository = CachedContentRepository(
        contentDao: dao,
        contentSyncService: syncService,
      );

      final modules = await repository.getModulesForStage(3);
      final level = await repository.getLevelById('remote-level-1');

      expect(modules.map((module) => module.id), ['remote-module']);
      expect(level?.title, 'Remote Level');
      expect(level?.contentItems.single.displayText, '8');
    });
  });
}

LearningModule _remoteModule() {
  return const LearningModule(
    id: 'remote-module',
    title: 'Remote Module',
    description: 'Admin synced content.',
    category: ModuleCategory.math,
    minStage: 1,
    maxStage: 4,
    order: 1,
  );
}

LearningLevel _remoteLevel() {
  return const LearningLevel(
    id: 'remote-level-1',
    moduleId: 'remote-module',
    stage: 3,
    levelNumber: 1,
    title: 'Remote Level',
    subtitle: 'Loaded from admin backend.',
    type: LevelType.counting,
    passingScore: 70,
    isBundled: false,
    contentItems: [
      ContentItem(
        title: 'Eight',
        prompt: 'Count eight stars.',
        displayText: '8',
        visualLabel: 'Eight stars',
      ),
    ],
  );
}
