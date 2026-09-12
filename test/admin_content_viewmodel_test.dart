import 'package:flutter_test/flutter_test.dart';
import 'package:little_learners/models/admin_content.dart';
import 'package:little_learners/models/content_item.dart';
import 'package:little_learners/models/learning_level.dart';
import 'package:little_learners/models/learning_module.dart';
import 'package:little_learners/models/quiz_question.dart';
import 'package:little_learners/repositories/admin_content_repository.dart';
import 'package:little_learners/services/local/content_dao.dart';
import 'package:little_learners/services/remote/content_remote_data_source.dart';
import 'package:little_learners/services/sync/content_sync_service.dart';
import 'package:little_learners/viewmodels/admin_content_viewmodel.dart';

/// Without the built-in curriculum, so the counts below are only what these
/// tests create. The built-in side has its own tests.
AdminContentViewModel adminOnly(
  AdminContentRepository repository, {
  ContentSyncService? contentSyncService,
}) =>
    AdminContentViewModel(
      repository,
      contentSyncService: contentSyncService,
      bundledModules: const [],
      bundledLevels: const [],
    );

const threeCard = ContentItem(
  title: 'Three',
  prompt: 'Count three.',
  displayText: '3',
  visualLabel: 'Three dots',
);

void main() {
  group('AdminContentViewModel', () {
    test('creates published module and level and syncs them locally', () async {
      final remote = InMemoryContentRemoteDataSource();
      final contentDao = InMemoryContentDao();
      final viewModel = adminOnly(
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
        minStage: 2,
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
        contentItems: const [threeCard],
        quizQuestions: const [
          QuizQuestion(
            id: '',
            prompt: 'How many?',
            options: ['2', '3', '4'],
            correctIndex: 1,
          ),
        ],
      );

      final syncedLevel = await contentDao.getLevelById('math-stage3-1');

      expect(moduleCreated, isTrue);
      expect(levelCreated, isTrue, reason: viewModel.errorMessage);
      expect(viewModel.modules.single.module.id, 'math');
      expect(viewModel.levels.single.level.id, 'math-stage3-1');
      expect(syncedLevel?.title, 'Count to 3');
      expect(syncedLevel?.contentItems, hasLength(1));
      expect(syncedLevel?.quizQuestions, hasLength(1));
      expect(syncedLevel?.quizQuestions.single.id, 'math-stage3-1-q1');
    });

    test('rejects invalid module and level input', () async {
      final viewModel = adminOnly(
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
        maxStage: 2,
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

    test('keeps the right answer on the same words when blanks are dropped',
        () async {
      final viewModel = adminOnly(
        InMemoryAdminContentRepository(
          contentRemoteDataSource: InMemoryContentRemoteDataSource(),
        ),
      );
      await viewModel.createModule(
        id: 'math',
        title: 'Math',
        description: '',
        category: ModuleCategory.math,
        minStage: 2,
        maxStage: 4,
        order: 1,
        isPublished: false,
      );

      final saved = await viewModel.createLevel(
        id: '',
        moduleId: 'math',
        stage: 2,
        levelNumber: 1,
        title: 'Count',
        subtitle: '',
        type: LevelType.counting,
        passingScore: 70,
        isPublished: false,
        contentItems: const [threeCard],
        quizQuestions: const [
          QuizQuestion(
            id: '',
            prompt: 'How many?',
            options: ['', '2', '3'],
            correctIndex: 2,
          ),
        ],
      );

      expect(saved, isTrue, reason: viewModel.errorMessage);
      final question = viewModel.levels.single.level.quizQuestions.single;
      expect(question.options, ['2', '3']);
      expect(question.options[question.correctIndex], '3');
    });

    test('a right answer left blank is reported, not guessed', () async {
      final viewModel = adminOnly(
        InMemoryAdminContentRepository(
          contentRemoteDataSource: InMemoryContentRemoteDataSource(),
        ),
      );
      await viewModel.createModule(
        id: 'math',
        title: 'Math',
        description: '',
        category: ModuleCategory.math,
        minStage: 2,
        maxStage: 4,
        order: 1,
        isPublished: false,
      );

      final saved = await viewModel.createLevel(
        id: '',
        moduleId: 'math',
        stage: 2,
        levelNumber: 1,
        title: 'Count',
        subtitle: '',
        type: LevelType.counting,
        passingScore: 70,
        isPublished: false,
        contentItems: const [threeCard],
        quizQuestions: const [
          QuizQuestion(
            id: '',
            prompt: 'How many?',
            options: ['2', '3', ''],
            correctIndex: 2,
          ),
        ],
      );

      expect(saved, isFalse);
      expect(viewModel.errorMessage, contains('pick which answer is right'));
    });

    test('refuses to publish a module that has no levels', () async {
      final viewModel = adminOnly(
        InMemoryAdminContentRepository(
          contentRemoteDataSource: InMemoryContentRemoteDataSource(),
        ),
      );
      await viewModel.createModule(
        id: 'Math',
        title: 'Math',
        description: 'Numbers',
        category: ModuleCategory.math,
        minStage: 2,
        maxStage: 4,
        order: 1,
        isPublished: false,
      );

      final published = await viewModel.publishModule(viewModel.modules.single);

      expect(published, isFalse);
      expect(viewModel.modules.single.isPublished, isFalse);
      expect(viewModel.errorMessage, contains('at least one level'));
    });

    test('moves admin content through review and published versions', () async {
      final viewModel = adminOnly(
        InMemoryAdminContentRepository(
          contentRemoteDataSource: InMemoryContentRemoteDataSource(),
        ),
      );

      await viewModel.createModule(
        id: 'Math',
        title: 'Math',
        description: 'Numbers',
        category: ModuleCategory.math,
        minStage: 2,
        maxStage: 4,
        order: 1,
        isPublished: false,
      );

      // UC-19 business rule: a module needs at least one level before it can
      // be published, so the workflow test supplies one.
      await viewModel.createLevel(
        id: '',
        moduleId: 'math',
        stage: 2,
        levelNumber: 1,
        title: 'Count to 3',
        subtitle: 'Count together',
        type: LevelType.counting,
        passingScore: 70,
        isPublished: false,
        contentItems: const [threeCard],
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
