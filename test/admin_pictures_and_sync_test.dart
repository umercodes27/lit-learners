import 'package:flutter_test/flutter_test.dart';
import 'package:little_learners/models/content_item.dart';
import 'package:little_learners/models/learning_level.dart';
import 'package:little_learners/models/learning_module.dart';
import 'package:little_learners/models/quiz_question.dart';
import 'package:little_learners/services/ai/content_draft_validator.dart';
import 'package:little_learners/services/local/content_dao.dart';
import 'package:little_learners/services/local/content_mapper.dart';
import 'package:little_learners/services/local/db_schema.dart';
import 'package:little_learners/services/remote/content_remote_data_source.dart';
import 'package:little_learners/services/sync/content_sync_service.dart';

const picture = 'https://res.cloudinary.com/demo/image/upload/cat.png';

LearningLevel level({
  String id = 'phonics-stage2-1',
  String moduleId = 'phonics',
  String? cardImage,
  String? questionImage,
}) =>
    LearningLevel(
      id: id,
      moduleId: moduleId,
      stage: 2,
      levelNumber: 1,
      title: 'Cat',
      subtitle: 'Say cat.',
      type: LevelType.flashcards,
      passingScore: 60,
      isBundled: false,
      contentItems: [
        ContentItem(
          title: 'Cat',
          prompt: 'This is a cat.',
          displayText: 'C',
          visualLabel: 'A cat',
          imageUrl: cardImage,
        ),
      ],
      quizQuestions: [
        QuizQuestion(
          id: '$id-q1',
          prompt: 'Which is the cat?',
          options: const ['Cat', 'Dog'],
          correctIndex: 0,
          imageUrl: questionImage,
        ),
      ],
    );

void main() {
  group('pictures are kept on the device', () {
    test('a card keeps its picture through the local database', () {
      const item = ContentItem(
        title: 'Cat',
        prompt: 'A cat.',
        displayText: 'C',
        visualLabel: 'A cat',
        imageUrl: picture,
      );
      final map = ContentMapper.contentItemToLocalMap(
        item: item,
        id: 'x',
        levelId: 'l',
        sortOrder: 0,
      );
      expect(ContentMapper.contentItemFromLocalMap(map).imageUrl, picture);
    });

    test('a quiz question keeps its picture too', () {
      const question = QuizQuestion(
        id: 'q',
        prompt: 'Which?',
        options: ['a', 'b'],
        correctIndex: 0,
        imageUrl: picture,
      );
      final map = ContentMapper.quizQuestionToLocalMap(
        question: question,
        levelId: 'l',
        sortOrder: 0,
      );
      expect(ContentMapper.quizQuestionFromLocalMap(map).imageUrl, picture);
    });

    test('installed apps gain the column, new installs start with it', () {
      expect(LocalDbSchema.version, 8);
      expect(LocalDbSchema.version8Statements.join(' '),
          allOf(contains(LocalDbSchema.contentItems),
              contains(LocalDbSchema.quizQuestions)));
      expect(LocalDbSchema.createContentItemsTable, contains('imageUrl'));
      expect(LocalDbSchema.createQuizQuestionsTable, contains('imageUrl'));
    });
  });

  group('the validator and pictures', () {
    const validator = ContentDraftValidator();

    List<DraftRule> blockingRules(LearningLevel level) => [
          for (final issue in validator.validateLevel(level, path: 'l').blocking)
            issue.rule,
        ];

    test('a web address is fine, and so is no picture', () {
      expect(blockingRules(level(cardImage: picture, questionImage: picture)),
          isNot(contains(DraftRule.imageUrlNotHttp)));
      expect(blockingRules(level()), isNot(contains(DraftRule.imageUrlNotHttp)));
    });

    test('an address a phone cannot fetch is blocked', () {
      expect(blockingRules(level(cardImage: 'memory://media/cat.png')),
          contains(DraftRule.imageUrlNotHttp));
      expect(blockingRules(level(questionImage: 'C:/pictures/cat.png')),
          contains(DraftRule.imageUrlNotHttp));
    });

    test('a module an admin created is not an unknown module', () {
      DraftValidationResult check(Set<String> known) => validator.validateStage(
            [level()],
            expectedLevelCount: 1,
            expectedFirstLevelNumber: 1,
            knownModuleIds: known,
          );

      expect(check({'phonics'}).blocking.map((i) => i.rule),
          isNot(contains(DraftRule.moduleIdNotACategory)));
      expect(check(const {}).blocking.map((i) => i.rule),
          contains(DraftRule.moduleIdNotACategory),
          reason: 'an id that matches nothing at all is still invented');
    });
  });

  group('which published levels reach a child', () {
    const math = LearningModule(
      id: 'math',
      title: 'Math',
      description: '',
      category: ModuleCategory.math,
      minStage: 2,
      maxStage: 4,
      order: 1,
    );

    test('an edited built-in level arrives without a module document',
        () async {
      final remote = InMemoryContentRemoteDataSource()
        ..upsertLevel(
          level: level(id: 'math-stage2-1', moduleId: 'math'),
          isPublished: true,
        );
      final dao = InMemoryContentDao();

      await ContentSyncService(
        contentDao: dao,
        contentRemoteDataSource: remote,
        bundledModules: const [math],
        bundledLevels: const [],
      ).syncNow();

      expect(await dao.getLevelById('math-stage2-1'), isNotNull);
    });

    test('a level whose module exists nowhere is still dropped', () async {
      final remote = InMemoryContentRemoteDataSource()
        ..upsertLevel(level: level(moduleId: 'ghost'), isPublished: true);
      final dao = InMemoryContentDao();

      await ContentSyncService(
        contentDao: dao,
        contentRemoteDataSource: remote,
        bundledModules: const [math],
        bundledLevels: const [],
      ).syncNow();

      expect(await dao.getLevelById('phonics-stage2-1'), isNull);
    });
  });
}
