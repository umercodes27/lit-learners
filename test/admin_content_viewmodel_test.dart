import 'package:flutter_test/flutter_test.dart';
import 'package:little_learners/models/admin_content.dart';
import 'package:little_learners/models/learning_level.dart';
import 'package:little_learners/models/learning_module.dart';
import 'package:little_learners/repositories/admin_content_repository.dart';
import 'package:little_learners/services/local/content_dao.dart';
import 'package:little_learners/services/remote/content_remote_data_source.dart';
import 'package:little_learners/services/sync/content_sync_service.dart';
import 'package:little_learners/viewmodels/admin_content_viewmodel.dart';

void main() {
  group('AdminContentViewModel', () {
    test('creates published module and level and syncs them locally', () async {
      final remote = InMemoryContentRemoteDataSource();
      final contentDao = InMemoryContentDao();
      final viewModel = AdminContentViewModel(
        InMemoryAdminContentRepository(contentRemoteDataSource: remote),
        contentSyncService: ContentSyncService(
          contentDao: contentDao,
          contentRemoteDataSource: remote,
        ),
      );

      final moduleCreated = await viewModel.createModule(
        id: 'Math',
        title: 'Math',
        description: 'Numbers',
        category: ModuleCategory.math,
        minStage: 1,
        maxStage: 4,
        order: 1,
        isPublished: true,
      );
      final levelCreated = await viewModel.createLevel(
        id: '',
        moduleId: 'math',
        stage: 3,
        levelNumber: 1,
        title: 'Count to 3',
        subtitle: 'Count together',
        type: LevelType.counting,
        passingScore: 70,
        isPublished: true,
        contentTitle: 'Three',
        contentPrompt: 'Count three.',
        contentDisplayText: '3',
        contentVisualLabel: 'Three dots',
        quizPrompt: 'How many?',
        quizOptions: const ['2', '3', '4'],
        quizCorrectIndex: 1,
      );

      final syncedLevel = await contentDao.getLevelById('math-stage3-1');

      expect(moduleCreated, isTrue);
      expect(levelCreated, isTrue);
      expect(viewModel.modules.single.module.id, 'math');
      expect(viewModel.levels.single.level.id, 'math-stage3-1');
      expect(syncedLevel?.title, 'Count to 3');
      expect(syncedLevel?.contentItems, hasLength(1));
      expect(syncedLevel?.quizQuestions, hasLength(1));
    });

    test('rejects invalid module and level input', () async {
      final viewModel = AdminContentViewModel(
        InMemoryAdminContentRepository(
          contentRemoteDataSource: InMemoryContentRemoteDataSource(),
        ),
      );

      final invalidModule = await viewModel.createModule(
        id: '',
        title: '',
        description: '',
        category: ModuleCategory.math,
        minStage: 4,
        maxStage: 1,
        order: 1,
        isPublished: false,
      );
      final invalidLevel = await viewModel.createLevel(
        id: '',
        moduleId: '',
        stage: 5,
        levelNumber: 0,
        title: '',
        subtitle: '',
        type: LevelType.counting,
        passingScore: 101,
        isPublished: false,
      );

      expect(invalidModule, isFalse);
      expect(invalidLevel, isFalse);
      expect(viewModel.modules, isEmpty);
      expect(viewModel.levels, isEmpty);
    });

    test('moves admin content through review and published versions', () async {
      final viewModel = AdminContentViewModel(
        InMemoryAdminContentRepository(
          contentRemoteDataSource: InMemoryContentRemoteDataSource(),
        ),
      );

      await viewModel.createModule(
        id: 'Math',
        title: 'Math',
        description: 'Numbers',
        category: ModuleCategory.math,
        minStage: 1,
        maxStage: 4,
        order: 1,
        isPublished: false,
      );

      final draft = viewModel.modules.single;
      final reviewed = await viewModel.submitModuleForReview(draft);
      final published = await viewModel.publishModule(viewModel.modules.single);

      expect(reviewed, isTrue);
      expect(published, isTrue);
      expect(
          viewModel.modules.single.publishStatus, AdminPublishStatus.published);
      expect(viewModel.modules.single.isPublished, isTrue);
      expect(viewModel.modules.single.version, 2);
      expect(viewModel.modules.single.submittedAt, isNotNull);
      expect(viewModel.modules.single.publishedAt, isNotNull);
    });
  });
}
