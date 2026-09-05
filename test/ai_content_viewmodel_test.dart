import 'package:flutter_test/flutter_test.dart';
import 'package:little_learners/models/admin_content.dart';
import 'package:little_learners/models/content_item.dart';
import 'package:little_learners/models/learning_level.dart';
import 'package:little_learners/models/learning_module.dart';
import 'package:little_learners/models/quiz_question.dart';
import 'package:little_learners/repositories/admin_content_repository.dart';
import 'package:little_learners/services/ai/ai_content_generator.dart';
import 'package:little_learners/services/ai/fake_llm_client.dart';
import 'package:little_learners/services/ai/llm_client.dart';
import 'package:little_learners/services/ai/llm_credential_store.dart';
import 'package:little_learners/services/ai/llm_provider_profile.dart';
import 'package:little_learners/services/remote/content_remote_data_source.dart';
import 'package:little_learners/viewmodels/admin_content_viewmodel.dart';
import 'package:little_learners/viewmodels/ai_content_viewmodel.dart';

/// Wraps the in-memory repository to record how the levels were written —
/// one batch or several single writes.
class RecordingAdminContentRepository implements AdminContentRepository {
  RecordingAdminContentRepository(this._delegate);

  final AdminContentRepository _delegate;
  final List<List<AdminContentLevel>> batches = [];
  int singleUpsertCount = 0;
  bool failNextWrite = false;

  @override
  Future<List<AdminContentLevel>> upsertLevels(
    List<AdminContentLevel> levels,
  ) async {
    batches.add(List.unmodifiable(levels));
    if (failNextWrite) {
      // A batch that fails writes nothing at all, which is the property under
      // test: the delegate is never touched.
      throw StateError('connection lost');
    }
    return _delegate.upsertLevels(levels);
  }

  @override
  Future<AdminContentLevel> upsertLevel(AdminContentLevel level) {
    singleUpsertCount++;
    return _delegate.upsertLevel(level);
  }

  @override
  Future<AdminContentModule> upsertModule(AdminContentModule module) =>
      _delegate.upsertModule(module);
  @override
  Future<List<AdminContentLevel>> getLevels({String? moduleId}) =>
      _delegate.getLevels(moduleId: moduleId);
  @override
  Future<List<AdminContentModule>> getModules() => _delegate.getModules();
  @override
  Future<void> deleteLevel(String levelId) => _delegate.deleteLevel(levelId);
  @override
  Future<void> deleteModule(String moduleId) =>
      _delegate.deleteModule(moduleId);
}

LearningLevel level({
  required int levelNumber,
  String moduleId = 'english',
  int stage = 2,
  String? id,
  String title = 'Letters',
  LevelType type = LevelType.flashcards,
  List<ContentItem>? contentItems,
  List<QuizQuestion> quizQuestions = const [],
}) =>
    LearningLevel(
      id: id ?? '$moduleId-stage$stage-$levelNumber',
      moduleId: moduleId,
      stage: stage,
      levelNumber: levelNumber,
      title: title,
      subtitle: 'Look and say.',
      type: type,
      passingScore: 60,
      isBundled: false,
      contentItems: contentItems ??
          const [
            ContentItem(
                title: 'A',
                prompt: 'Say A.',
                displayText: 'A',
                visualLabel: 'Letter A'),
          ],
      quizQuestions: quizQuestions,
    );

void main() {
  group('createLevelsFromDrafts writes one batch, or nothing', () {
    late RecordingAdminContentRepository repository;
    late AdminContentViewModel viewModel;

    setUp(() {
      repository = RecordingAdminContentRepository(
        InMemoryAdminContentRepository(
          contentRemoteDataSource: InMemoryContentRemoteDataSource(),
        ),
      );
      viewModel = AdminContentViewModel(repository);
    });

    test('five levels go out as a single batch, not five writes', () async {
      final saved = await viewModel.createLevelsFromDrafts(
        [for (var n = 1; n <= 5; n++) level(levelNumber: n)],
      );

      expect(saved, isTrue);
      expect(repository.batches, hasLength(1));
      expect(repository.batches.single, hasLength(5));
      expect(repository.singleUpsertCount, 0,
          reason: 'a dropped connection between single writes is the bug '
              'this exists to prevent');
    });

    test('a failed batch leaves nothing behind', () async {
      repository.failNextWrite = true;

      final saved = await viewModel.createLevelsFromDrafts(
        [for (var n = 1; n <= 5; n++) level(levelNumber: n)],
      );

      expect(saved, isFalse);
      expect(viewModel.errorMessage, isNotNull);
      expect(await repository.getLevels(), isEmpty,
          reason: 'no partial ladder may survive a failed save');
    });

    test('every level is validated before any is written', () async {
      final saved = await viewModel.createLevelsFromDrafts([
        level(levelNumber: 1),
        level(levelNumber: 2),
        // Only the last one is bad.
        level(levelNumber: 3, title: '   '),
      ]);

      expect(saved, isFalse);
      expect(repository.batches, isEmpty,
          reason: 'a bad third level must not leave two saved ones');
      expect(viewModel.errorMessage, contains('english-stage2-3'));
    });

    test('ids are kept exactly, never slugged', () async {
      // Slugging is ASCII-only, so an Urdu title would slug to nothing and be
      // rejected as a missing id.
      await viewModel.createLevelsFromDrafts([
        level(levelNumber: 1, moduleId: 'urdu', title: 'حرف ا'),
      ]);

      expect(repository.batches.single.single.level.id, 'urdu-stage2-1');
    });

    test('drafts land unpublished and stay out of the child app', () async {
      await viewModel.createLevelsFromDrafts([level(levelNumber: 1)]);

      final written = repository.batches.single.single;
      expect(written.isPublished, isFalse);
      expect(written.publishStatus, AdminPublishStatus.draft);
      expect(written.level.isBundled, isFalse);
    });

    test('several cards and questions survive, which the manual form cannot do',
        () async {
      await viewModel.createLevelsFromDrafts([
        level(
          levelNumber: 1,
          contentItems: const [
            ContentItem(
                title: 'A', prompt: 'Say A.', displayText: 'A', visualLabel: 'A'),
            ContentItem(
                title: 'B', prompt: 'Say B.', displayText: 'B', visualLabel: 'B'),
            ContentItem(
                title: 'C', prompt: 'Say C.', displayText: 'C', visualLabel: 'C'),
          ],
          quizQuestions: const [
            QuizQuestion(
                id: 'q1', prompt: 'Which?', options: ['A', 'B'], correctIndex: 0),
            QuizQuestion(
                id: 'q2', prompt: 'And?', options: ['B', 'C'], correctIndex: 1),
          ],
        ),
      ]);

      final written = repository.batches.single.single.level;
      expect(written.contentItems, hasLength(3));
      expect(written.quizQuestions, hasLength(2));
    });

    test('saving nothing is refused rather than writing an empty batch',
        () async {
      expect(await viewModel.createLevelsFromDrafts([]), isFalse);
      expect(repository.batches, isEmpty);
    });
  });

  group('AiContentViewModel', () {
    const english = LearningModule(
      id: 'english',
      title: 'English',
      description: 'Letters',
      category: ModuleCategory.english,
      minStage: 1,
      maxStage: 4,
      order: 1,
    );
    const tracing = LearningModule(
      id: 'tracing',
      title: 'Tracing',
      description: 'Write',
      category: ModuleCategory.tracing,
      minStage: 2,
      maxStage: 4,
      order: 8,
    );

    const badTracing = '{"levels":[{"title":"Trace","subtitle":"Follow.",'
        '"passingScore":60,"contentItems":[{"title":"AB","prompt":"Trace.",'
        '"displayText":"AB","visualLabel":"Letters"}]}]}';

    String card(String letter) => '{"title":"$letter","prompt":"Say $letter.",'
        '"displayText":"$letter","visualLabel":"Letter $letter"}';

    String reply(int count) => '{"levels":[${[
          for (var i = 0; i < count; i++)
            '{"title":"Level $i","subtitle":"Look and say.","passingScore":60,'
                '"contentItems":[${card(String.fromCharCode(65 + i))}]}',
        ].join(',')}]}';

    AiContentViewModel viewModelWith(
      List<Object> replies, {
      bool withKey = true,
    }) {
      return AiContentViewModel(
        generator: AiContentGenerator(client: FakeLlmClient(replies)),
        credentialStore: InMemoryLlmCredentialStore(
          withKey
              ? const LlmCredentials(
                  apiKey: 'sk-test', profile: LlmProviderProfile.deepseek)
              : const LlmCredentials.unset(),
        ),
      );
    }

    Future<AiContentViewModel> generated(
      int count, {
      List<Object>? replies,
      LearningModule module = english,
      LevelType type = LevelType.flashcards,
      int stage = 1,
      List<LearningLevel> existing = const [],
    }) async {
      final vm = viewModelWith(replies ?? [reply(count)]);
      await vm.loadCredentials();
      vm.selectModule(module.id, modules: [module]);
      // After selectModule, which clamps to the module's own range.
      vm.setStage(stage);
      vm.setType(type);
      vm.setLevelCount(count);
      await vm.generate(modules: [module], existingLevels: existing);
      return vm;
    }

    test('the stage is clamped to what the module actually supports', () {
      final vm = viewModelWith([reply(1)]);
      vm.setStage(1);
      vm.selectModule('tracing', modules: [tracing]);

      expect(vm.stage, 2, reason: 'tracing does not start until stage 2');
      expect(vm.stagesFor([tracing]), [2, 3, 4]);
    });

    test('generating without a key says so instead of calling out', () async {
      final vm = viewModelWith([reply(1)], withKey: false);
      await vm.loadCredentials();
      vm.selectModule('english', modules: [english]);

      await vm.generate(modules: [english], existingLevels: const []);

      expect(vm.errorMessage, contains('API key'));
      expect(vm.drafts, isEmpty);
    });

    test('numbering continues from what the stage already holds', () async {
      final vm = await generated(
        2,
        stage: 2,
        existing: [level(levelNumber: 1), level(levelNumber: 2)],
      );

      expect(vm.firstLevelNumber, 3);
      expect(vm.drafts.map((d) => d.level.levelNumber), [3, 4]);
    });

    test('the level count is capped', () {
      final vm = viewModelWith([reply(1)]);
      vm.setLevelCount(99);
      expect(vm.levelCount, AiContentViewModel.maxLevelCount);
      vm.setLevelCount(0);
      expect(vm.levelCount, 1);
    });

    test('a blocked draft cannot be approved, even by asking directly',
        () async {
      final vm = await generated(
        1,
        replies: [badTracing, badTracing, badTracing],
        module: tracing,
        type: LevelType.tracing,
      );

      expect(vm.drafts.single.isBlocked, isTrue);
      vm.toggleApproved(0, true);
      expect(vm.drafts.single.isApproved, isFalse);
      expect(vm.canSave, isFalse);
    });

    test('fixing a draft by hand unblocks it', () async {
      final vm = await generated(
        1,
        replies: [badTracing, badTracing, badTracing],
        module: tracing,
        type: LevelType.tracing,
      );

      vm.updateDraft(
        0,
        vm.drafts.single.level.copyWith(contentItems: const [
          ContentItem(
              title: 'A', prompt: 'Trace.', displayText: 'A', visualLabel: 'A'),
        ]),
      );

      expect(vm.drafts.single.isBlocked, isFalse);
      vm.toggleApproved(0, true);
      expect(vm.canSave, isTrue);
    });

    test('approving a non-contiguous set is refused, gap and all', () async {
      final vm = await generated(3);

      // Levels 1 and 3, skipping 2. Atomic or not, that ladder has a hole,
      // and the hole locks everything after it.
      vm.toggleApproved(0, true);
      vm.toggleApproved(2, true);

      expect(vm.approvalProblem, contains('unbroken run'));
      expect(vm.canSave, isFalse);

      vm.toggleApproved(1, true);
      expect(vm.approvalProblem, isNull);
      expect(vm.canSave, isTrue);
    });

    test('an unbroken prefix is fine, so a partial batch can still be saved',
        () async {
      final vm = await generated(3);
      vm.toggleApproved(0, true);
      vm.toggleApproved(1, true);

      expect(vm.approvalProblem, isNull);
    });

    test('approving only the tail is refused', () async {
      final vm = await generated(3);
      vm.toggleApproved(1, true);
      vm.toggleApproved(2, true);

      expect(vm.approvalProblem, contains('unbroken run'));
    });

    test('a successful save hands over one ascending list and clears them',
        () async {
      final vm = await generated(3);
      for (var i = 0; i < 3; i++) {
        vm.toggleApproved(i, true);
      }

      List<LearningLevel>? handed;
      final saved = await vm.saveApproved((levels) async {
        handed = levels;
        return true;
      });

      expect(saved, isTrue);
      expect(handed!.map((l) => l.levelNumber), [1, 2, 3]);
      expect(vm.drafts, isEmpty);
      expect(vm.infoMessage, contains('3 levels'));
    });

    test('a failed save keeps every draft, because nothing was written',
        () async {
      final vm = await generated(2);
      vm.toggleApproved(0, true);
      vm.toggleApproved(1, true);

      final saved = await vm.saveApproved((_) async => false);

      expect(saved, isFalse);
      expect(vm.drafts, hasLength(2));
      expect(vm.drafts.every((d) => d.isApproved), isTrue);
      expect(vm.errorMessage, contains('still here'));
    });

    test('the key can be stored and forgotten without leaking it', () async {
      final vm = viewModelWith([reply(1)], withKey: false);
      await vm.loadCredentials();
      expect(vm.hasKey, isFalse);

      await vm.saveKey(
        apiKey: 'sk-abcdefghijklmnop1234',
        profile: LlmProviderProfile.deepseek,
      );
      expect(vm.hasKey, isTrue);
      expect(vm.credentials.maskedKey, isNot(contains('abcdefghijklmnop')));

      await vm.forgetKey();
      expect(vm.hasKey, isFalse);
    });
  });
}
