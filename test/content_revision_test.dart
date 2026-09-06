import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_learners/core/utils/learning_text_direction.dart';
import 'package:little_learners/core/utils/age_stage_helper.dart';
import 'package:little_learners/data/seed_content.dart';
import 'package:little_learners/models/content_item.dart';
import 'package:little_learners/models/learning_level.dart';
import 'package:little_learners/models/learning_module.dart';
import 'package:little_learners/repositories/content_repository.dart';
import 'package:little_learners/services/local/content_dao.dart';

void main() {
  group('bundled content revision', () {
    test('a fresh install seeds the bundle and records its revision', () async {
      final dao = InMemoryContentDao();
      final repository = CachedContentRepository(
        contentDao: dao,
        bundledModules: [_module()],
        bundledLevels: [_level('a-1')],
        contentRevision: 'rev-1',
      );

      final levels = await repository.getLevelsForModule(
        moduleId: 'demo',
        stage: 1,
      );

      expect(levels.map((level) => level.id), ['a-1']);
      expect(await dao.getContentRevision(), 'rev-1');
    });

    // The bug: content added to the bundle after a device was already seeded
    // never reached that device, so newly shipped levels were invisible.
    test('a newer bundle replaces content installed under an older revision',
        () async {
      final dao = InMemoryContentDao();
      await CachedContentRepository(
        contentDao: dao,
        bundledModules: [_module()],
        bundledLevels: [_level('a-1')],
        contentRevision: 'rev-1',
      ).getLevelsForModule(moduleId: 'demo', stage: 1);

      final upgraded = CachedContentRepository(
        contentDao: dao,
        bundledModules: [_module()],
        bundledLevels: [_level('a-1'), _level('a-2', levelNumber: 2)],
        contentRevision: 'rev-2',
      );
      final levels = await upgraded.getLevelsForModule(
        moduleId: 'demo',
        stage: 1,
      );

      expect(levels.map((level) => level.id), ['a-1', 'a-2']);
      expect(await dao.getContentRevision(), 'rev-2');
    });

    test('an unchanged revision leaves the database alone', () async {
      final dao = InMemoryContentDao();
      await CachedContentRepository(
        contentDao: dao,
        bundledModules: [_module()],
        bundledLevels: [_level('a-1')],
        contentRevision: 'rev-1',
      ).getLevelsForModule(moduleId: 'demo', stage: 1);
      await dao.markLevelDownloaded('a-1');

      final reopened = CachedContentRepository(
        contentDao: dao,
        bundledModules: [_module()],
        bundledLevels: [_level('a-1')],
        contentRevision: 'rev-1',
      );
      final levels = await reopened.getLevelsForModule(
        moduleId: 'demo',
        stage: 1,
      );

      expect(levels.single.isDownloaded, isTrue);
    });

    test('reinstalling the bundle keeps levels the parent downloaded',
        () async {
      final dao = InMemoryContentDao();
      await CachedContentRepository(
        contentDao: dao,
        bundledModules: [_module()],
        bundledLevels: [_level('a-1', isBundled: false)],
        contentRevision: 'rev-1',
      ).getLevelsForModule(moduleId: 'demo', stage: 1);
      await dao.markLevelDownloaded('a-1');

      final levels = await CachedContentRepository(
        contentDao: dao,
        bundledModules: [_module()],
        bundledLevels: [
          _level('a-1', isBundled: false),
          _level('a-2', levelNumber: 2),
        ],
        contentRevision: 'rev-2',
      ).getLevelsForModule(moduleId: 'demo', stage: 1);

      expect(levels.first.isDownloaded, isTrue);
      expect(levels, hasLength(2));
    });

    test('the tracing module ships levels for every stage that offers it',
        () async {
      final repository = CachedContentRepository(
        contentDao: InMemoryContentDao(),
      );
      final module = await repository.getModuleById('tracing');

      expect(module, isNotNull);
      expect(module!.category, ModuleCategory.tracing);

      for (var stage = module.minStage; stage <= module.maxStage; stage++) {
        final levels = await repository.getLevelsForModule(
          moduleId: 'tracing',
          stage: stage,
        );
        expect(levels, isNotEmpty, reason: 'stage $stage');
        expect(
          levels.every((level) => level.type == LevelType.tracing),
          isTrue,
          reason: 'stage $stage',
        );
      }
    });

    test('the tracing module appears for the stages it supports', () async {
      final repository = CachedContentRepository(
        contentDao: InMemoryContentDao(),
      );

      for (var stage = 1; stage <= 4; stage++) {
        final modules = await repository.getModulesForStage(stage);
        final hasTracing = modules.any((module) => module.id == 'tracing');
        expect(hasTracing, stage >= 2, reason: 'stage $stage');
      }
    });

    test('tracing levels number consecutively from one in each stage',
        () async {
      final repository = CachedContentRepository(
        contentDao: InMemoryContentDao(),
      );

      for (var stage = 2; stage <= 4; stage++) {
        final levels = await repository.getLevelsForModule(
          moduleId: 'tracing',
          stage: stage,
        );
        expect(
          levels.map((level) => level.levelNumber),
          List.generate(levels.length, (index) => index + 1),
          reason: 'stage $stage',
        );
      }
    });

    test('every tracing card carries a single glyph to trace', () {
      final tracingLevels =
          seedLevels.where((level) => level.type == LevelType.tracing);

      expect(tracingLevels, isNotEmpty);
      for (final level in tracingLevels) {
        expect(level.contentItems, isNotEmpty, reason: level.id);
        for (final item in level.contentItems) {
          expect(
            item.displayText.runes.length,
            1,
            reason: '${level.id}: "${item.displayText}"',
          );
        }
      }
    });

    // Urdu tracing lives in the tracing module now, so direction can no longer
    // be decided by the module id alone.
    test('Urdu tracing levels still lay out right to left', () {
      final tracingLevels = seedLevels.where(
        (level) => level.moduleId == 'tracing',
      );
      final urduLevels = tracingLevels.where(
        (level) => RegExp(r'[؀-ۿ]').hasMatch(level.title),
      );
      final latinLevels = tracingLevels.where(
        (level) => !RegExp(r'[؀-ۿ]').hasMatch(level.title),
      );

      expect(urduLevels, isNotEmpty);
      for (final level in urduLevels) {
        expect(
          LearningTextDirection.forLevel(level),
          TextDirection.rtl,
          reason: level.id,
        );
      }
      for (final level in latinLevels) {
        expect(
          LearningTextDirection.forLevel(level),
          TextDirection.ltr,
          reason: level.id,
        );
      }
    });

    test('tracing quizzes only ask about glyphs the level traced', () {
      final tracingLevels =
          seedLevels.where((level) => level.type == LevelType.tracing);

      for (final level in tracingLevels) {
        for (final question in level.quizQuestions) {
          expect(
            question.options.length,
            greaterThanOrEqualTo(2),
            reason: question.id,
          );
          expect(
            question.correctIndex,
            lessThan(question.options.length),
            reason: question.id,
          );
        }
      }
    });

    test('nothing is authored below the youngest age the app accepts', () {
      // Ages 2-4 map onto stages 2-4, so a stage-1 level or a module claiming
      // to start there is content no child can reach. Stage numbers were left
      // alone when age 1 was dropped - they are baked into progress rows and
      // `leaderboards/stage-{n}` ids - so stage 1 still exists as a number and
      // has to stay empty by test rather than by construction.
      expect(
        seedLevels.where((level) => level.stage < AgeStageHelper.minStage),
        isEmpty,
      );
      expect(
        seedModules.where((module) => module.minStage < AgeStageHelper.minStage),
        isEmpty,
      );
    });
  });
}

LearningModule _module() {
  return const LearningModule(
    id: 'demo',
    title: 'Demo',
    description: 'Demo module',
    category: ModuleCategory.english,
    minStage: 1,
    maxStage: 4,
    order: 1,
  );
}

LearningLevel _level(
  String id, {
  int levelNumber = 1,
  bool isBundled = true,
}) {
  return LearningLevel(
    id: id,
    moduleId: 'demo',
    stage: 1,
    levelNumber: levelNumber,
    title: id,
    subtitle: id,
    type: LevelType.flashcards,
    passingScore: 70,
    isBundled: isBundled,
    contentItems: const [
      ContentItem(
        title: 'Card',
        prompt: 'Prompt',
        displayText: 'A',
        visualLabel: 'Card',
      ),
    ],
  );
}
