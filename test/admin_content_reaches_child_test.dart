import 'package:flutter_test/flutter_test.dart';
import 'package:little_learners/core/utils/age_stage_helper.dart';
import 'package:little_learners/models/learning_level.dart';
import 'package:little_learners/models/learning_module.dart';
import 'package:little_learners/repositories/admin_content_repository.dart';
import 'package:little_learners/repositories/content_repository.dart';
import 'package:little_learners/services/local/content_dao.dart';
import 'package:little_learners/services/remote/content_remote_data_source.dart';
import 'package:little_learners/services/sync/content_sync_service.dart';
import 'package:little_learners/viewmodels/admin_content_viewmodel.dart';

/// Wires the admin side and the child side to the same remote source, the way
/// `app.dart` does, so a module created in the portal can be followed all the
/// way to the screen a parent reads.
({AdminContentViewModel admin, ContentRepository content}) world() {
  final remote = InMemoryContentRemoteDataSource();
  final dao = InMemoryContentDao();
  final sync = ContentSyncService(
    contentDao: dao,
    contentRemoteDataSource: remote,
  );

  return (
    admin: AdminContentViewModel(
      InMemoryAdminContentRepository(contentRemoteDataSource: remote),
      contentSyncService: sync,
    ),
    content: CachedContentRepository(contentDao: dao, contentSyncService: sync),
  );
}

Future<void> createModule(
  AdminContentViewModel admin, {
  String id = 'shapes',
  int minStage = AgeStageHelper.minStage,
  int maxStage = 4,
  bool isPublished = true,
}) async {
  await admin.createModule(
    id: id,
    title: 'Shapes',
    description: 'Circles and squares',
    category: ModuleCategory.logic,
    minStage: minStage,
    maxStage: maxStage,
    order: 9,
    isPublished: isPublished,
  );
}

Future<void> createLevel(
  AdminContentViewModel admin, {
  String moduleId = 'shapes',
  int stage = 3,
  bool isPublished = true,
}) async {
  await admin.createLevel(
    id: '',
    moduleId: moduleId,
    stage: stage,
    levelNumber: 1,
    title: 'Find the circle',
    subtitle: 'Point at the round one',
    type: LevelType.flashcards,
    passingScore: 60,
    isPublished: isPublished,
    contentTitle: 'Circle',
    contentPrompt: 'Find the circle.',
    contentDisplayText: 'Circle',
    contentVisualLabel: 'A circle',
  );
}

void main() {
  test('a published module and level reach the child side', () async {
    final w = world();
    await createModule(w.admin);
    await createLevel(w.admin);

    final modules = await w.content.getModulesForStage(3);
    final levels =
        await w.content.getLevelsForModule(moduleId: 'shapes', stage: 3);

    expect(modules.map((m) => m.id), contains('shapes'));
    expect(levels, hasLength(1));
    expect(levels.single.title, 'Find the circle');
  });

  test('the bundled curriculum is still there alongside it', () async {
    final w = world();
    await createModule(w.admin);
    await createLevel(w.admin);

    final modules = await w.content.getModulesForStage(3);
    expect(modules.map((m) => m.id), contains('math'));
    expect(modules.length, greaterThan(1));
  });

  group('when it does not show up, these are the reasons', () {
    test('an unpublished module never leaves the admin portal', () async {
      final w = world();
      await createModule(w.admin, isPublished: false);
      await createLevel(w.admin);

      final modules = await w.content.getModulesForStage(3);
      expect(modules.map((m) => m.id), isNot(contains('shapes')),
          reason: 'drafts are for the admin only, which is the point of them');
    });

    test('a published module whose levels are unpublished arrives empty',
        () async {
      final w = world();
      await createModule(w.admin);
      await createLevel(w.admin, isPublished: false);

      final levels =
          await w.content.getLevelsForModule(moduleId: 'shapes', stage: 3);
      expect(levels, isEmpty,
          reason: 'the module is publishable on its own, so publishing it '
              'does not publish what is inside it');
    });

    test('a level built for a lower stage still reaches an older child',
        () async {
      final w = world();
      await createModule(w.admin);
      await createLevel(w.admin, stage: AgeStageHelper.minStage);

      // Not a failure mode after all. Rather than show a three-year-old an
      // empty subject, the repository falls back to the nearest lower stage
      // that has anything in it — which is why the report must not filter on
      // an exact stage match a second time.
      expect(
        await w.content.getLevelsForModule(moduleId: 'shapes', stage: 3),
        hasLength(1),
      );
    });

    test('a module whose stage range excludes the child is filtered out',
        () async {
      final w = world();
      await createModule(
        w.admin,
        minStage: AgeStageHelper.minStage,
        maxStage: AgeStageHelper.minStage,
      );
      await createLevel(w.admin, stage: AgeStageHelper.minStage);

      final modules = await w.content.getModulesForStage(3);
      expect(modules.map((m) => m.id), isNot(contains('shapes')));
    });
  });
}
