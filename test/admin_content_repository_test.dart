import 'package:flutter_test/flutter_test.dart';
import 'package:little_learners/models/admin_content.dart';
import 'package:little_learners/models/content_item.dart';
import 'package:little_learners/models/learning_level.dart';
import 'package:little_learners/models/learning_module.dart';
import 'package:little_learners/repositories/admin_content_repository.dart';
import 'package:little_learners/services/remote/content_remote_data_source.dart';

void main() {
  group('InMemoryAdminContentRepository', () {
    test('creates draft and published modules for content sync', () async {
      final remote = InMemoryContentRemoteDataSource();
      final repository = InMemoryAdminContentRepository(
        contentRemoteDataSource: remote,
      );
      final module = _adminModule(isPublished: false);

      await repository.upsertModule(module);

      expect(await repository.getModules(), hasLength(1));
      expect((await remote.getPublishedContent()).modules, isEmpty);

      await repository.upsertModule(module.copyWith(isPublished: true));

      expect((await remote.getPublishedContent()).modules.single.id, 'math');
    });

    test('creates levels and deletes a module with its child levels', () async {
      final remote = InMemoryContentRemoteDataSource();
      final repository = InMemoryAdminContentRepository(
        contentRemoteDataSource: remote,
      );

      await repository.upsertModule(_adminModule(isPublished: true));
      await repository.upsertLevel(_adminLevel(isPublished: true));

      var bundle = await remote.getPublishedContent();
      expect(bundle.levels.single.id, 'math-stage3-1');

      await repository.deleteModule('math');

      expect(await repository.getModules(), isEmpty);
      expect(await repository.getLevels(), isEmpty);
      bundle = await remote.getPublishedContent();
      expect(bundle.modules, isEmpty);
      expect(bundle.levels, isEmpty);
    });

    test('persists publishing workflow metadata', () async {
      final remote = InMemoryContentRemoteDataSource();
      final repository = InMemoryAdminContentRepository(
        contentRemoteDataSource: remote,
      );
      final submittedAt = DateTime.utc(2026, 1, 2);
      final publishedAt = DateTime.utc(2026, 1, 3);

      await repository.upsertModule(
        _adminModule(isPublished: true).copyWith(
          publishStatus: AdminPublishStatus.published,
          version: 3,
          submittedAt: submittedAt,
          publishedAt: publishedAt,
        ),
      );

      final module = (await repository.getModules()).single;

      expect(module.publishStatus, AdminPublishStatus.published);
      expect(module.version, 3);
      expect(module.submittedAt, submittedAt);
      expect(module.publishedAt, publishedAt);
    });
  });
}

AdminContentModule _adminModule({required bool isPublished}) {
  final now = DateTime.utc(2026);
  return AdminContentModule(
    module: const LearningModule(
      id: 'math',
      title: 'Math',
      description: 'Numbers',
      category: ModuleCategory.math,
      minStage: 1,
      maxStage: 4,
      order: 1,
    ),
    isPublished: isPublished,
    createdAt: now,
    updatedAt: now,
  );
}

AdminContentLevel _adminLevel({required bool isPublished}) {
  final now = DateTime.utc(2026);
  return AdminContentLevel(
    level: const LearningLevel(
      id: 'math-stage3-1',
      moduleId: 'math',
      stage: 3,
      levelNumber: 1,
      title: 'Count',
      subtitle: 'Count together',
      type: LevelType.counting,
      passingScore: 70,
      isBundled: false,
      contentItems: [
        ContentItem(
          title: 'Three',
          prompt: 'Count three.',
          displayText: '3',
          visualLabel: 'Three dots',
        ),
      ],
    ),
    isPublished: isPublished,
    createdAt: now,
    updatedAt: now,
  );
}
