import 'package:flutter_test/flutter_test.dart';
import 'package:little_learners/models/ai_level_draft.dart';
import 'package:little_learners/models/learning_level.dart';
import 'package:little_learners/models/learning_module.dart';
import 'package:little_learners/services/ai/ai_content_generator.dart';
import 'package:little_learners/services/ai/content_draft_validator.dart';
import 'package:little_learners/services/ai/fake_llm_client.dart';
import 'package:little_learners/services/ai/llm_client.dart';

AiGenerationRequest request({
  String moduleId = 'english',
  ModuleCategory category = ModuleCategory.english,
  int stage = 2,
  int levelCount = 2,
  LevelType type = LevelType.flashcards,
  int firstLevelNumber = 3,
}) =>
    AiGenerationRequest(
      moduleId: moduleId,
      moduleTitle: 'English',
      category: category,
      stage: stage,
      levelCount: levelCount,
      type: type,
      firstLevelNumber: firstLevelNumber,
    );

String card(String letter) => '{"title":"$letter","prompt":"Say $letter.",'
    '"displayText":"$letter","visualLabel":"Letter $letter"}';

String levelJson(String title, List<String> letters, {int passingScore = 60}) =>
    '{"title":"$title","subtitle":"Look and say.",'
    '"passingScore":$passingScore,'
    '"contentItems":[${letters.map(card).join(',')}]}';

String reply(List<String> levels) => '{"levels":[${levels.join(',')}]}';

final goodReply = reply([
  levelJson('Letters A B', ['A', 'B']),
  levelJson('Letters C D', ['C', 'D']),
]);

void main() {
  group('the happy path', () {
    test('one call, clean drafts', () async {
      final client = FakeLlmClient([goodReply]);
      final generator = AiContentGenerator(client: client);

      final result = await generator.generateStage(request());

      expect(client.callCount, 1);
      expect(result.attempts, 1);
      expect(result.isClean, isTrue);
      expect(result.drafts, hasLength(2));
      expect(result.drafts.every((d) => d.canApprove), isTrue);
    });

    test('the app fills in everything it never asked the model for', () async {
      final generator =
          AiContentGenerator(client: FakeLlmClient([goodReply]));

      final drafts = (await generator.generateStage(request())).drafts;
      final first = drafts.first.level;
      final second = drafts.last.level;

      // Numbering continues from where the stage left off, unbroken.
      expect(first.levelNumber, 3);
      expect(second.levelNumber, 4);
      expect(first.id, 'english-stage2-3');
      expect(second.id, 'english-stage2-4');

      expect(first.moduleId, 'english');
      expect(first.stage, 2);
      expect(first.type, LevelType.flashcards);
      expect(first.isBundled, isFalse);

      // A spaced en-dash, not a hyphen.
      expect(first.portionLabel, 'A – B');
      expect(second.portionLabel, 'C – D');

      // Never taken from the model: an invented cue points at a missing file.
      for (final item in first.contentItems) {
        expect(item.audioCueKey, isNull);
      }
    });

    test('quiz ids are derived from the level, never trusted', () async {
      const quiz = '"quizQuestions":[{"prompt":"Which?",'
          '"options":["A","B"],"correctIndex":0},'
          '{"prompt":"And which?","options":["C","D"],"correctIndex":1}]';
      final withQuiz = reply([
        '{"title":"Letters","subtitle":"Look.","passingScore":60,'
            '"contentItems":[${card('A')}],$quiz}',
      ]);

      final generator = AiContentGenerator(client: FakeLlmClient([withQuiz]));
      final result =
          await generator.generateStage(request(levelCount: 1));

      expect(
        result.drafts.single.level.quizQuestions.map((q) => q.id),
        ['english-stage2-3-q1', 'english-stage2-3-q2'],
      );
    });

    test('a single-card level gets a one-sided portion label', () async {
      final generator = AiContentGenerator(
        client: FakeLlmClient([
          reply([levelJson('Letter A', ['A'])]),
        ]),
      );
      final result = await generator.generateStage(request(levelCount: 1));
      expect(result.drafts.single.level.portionLabel, 'A');
    });

    test('story levels get no portion label, because they are not a slice',
        () async {
      final generator = AiContentGenerator(
        client: FakeLlmClient([
          reply([levelJson('A day out', ['A'])]),
        ]),
      );
      final result = await generator.generateStage(
        request(levelCount: 1, type: LevelType.story),
      );
      expect(result.drafts.single.level.portionLabel, isNull);
    });
  });

  group('when the reply cannot be read', () {
    test('it says so, then succeeds on the retry', () async {
      final client = FakeLlmClient(['I cannot help with that.', goodReply]);
      final generator = AiContentGenerator(client: client);

      final result = await generator.generateStage(request());

      expect(client.callCount, 2);
      expect(result.attempts, 2);
      expect(result.isClean, isTrue);
      expect(client.lastUserMessage, contains('no JSON object'));
      expect(client.lastUserMessage, contains('No markdown fences'));
    });

    test('markdown fences and chatter are simply parsed through', () async {
      final client = FakeLlmClient(['Sure!\n```json\n$goodReply\n```\nEnjoy.']);
      final result =
          await AiContentGenerator(client: client).generateStage(request());

      expect(client.callCount, 1, reason: 'no repair round should be needed');
      expect(result.isClean, isTrue);
    });

    test('after the last attempt the failure is reported, not thrown',
        () async {
      final client = FakeLlmClient(['nonsense']);
      final result =
          await AiContentGenerator(client: client).generateStage(request());

      expect(result.attempts, 3);
      expect(result.batchIssues.map((i) => i.rule),
          contains(DraftRule.unreadableReply));
      expect(result.isClean, isFalse);
    });
  });

  group('when the content breaks a rule', () {
    // Two runes where a tracing guide needs one.
    final badGlyph = reply([
      '{"title":"Trace A","subtitle":"Follow the dots.","passingScore":60,'
          '"contentItems":[{"title":"AB","prompt":"Trace.",'
          '"displayText":"AB","visualLabel":"Letters"}]}',
    ]);

    test('the repair message names the field and says what to do', () async {
      final client = FakeLlmClient([badGlyph, badGlyph, badGlyph]);
      final generator = AiContentGenerator(client: client);

      await generator.generateStage(
        request(levelCount: 1, type: LevelType.tracing),
      );

      expect(client.lastUserMessage,
          contains('levels[0].contentItems[0].displayText'));
      expect(client.lastUserMessage, contains('exactly one character'));
    });

    test('a level the model could not fix comes back with its problems, '
        'not thrown away', () async {
      final client = FakeLlmClient([badGlyph]);
      final result = await AiContentGenerator(client: client).generateStage(
        request(levelCount: 1, type: LevelType.tracing),
      );

      expect(result.attempts, 3);
      expect(result.drafts, hasLength(1),
          reason: 'the draft must survive so a human can fix one character');
      expect(result.drafts.single.isBlocked, isTrue);
      expect(result.drafts.single.canApprove, isFalse);
      expect(result.drafts.single.blocking.map((i) => i.rule),
          contains(DraftRule.tracingGlyphNotSingleRune));
    });

    test('a fixed reply on the second round is accepted', () async {
      final fixed = reply([
        '{"title":"Trace A","subtitle":"Follow the dots.","passingScore":60,'
            '"contentItems":[{"title":"A","prompt":"Trace.",'
            '"displayText":"A","visualLabel":"Letter A"}]}',
      ]);
      final client = FakeLlmClient([badGlyph, fixed]);

      final result = await AiContentGenerator(client: client).generateStage(
        request(levelCount: 1, type: LevelType.tracing),
      );

      expect(result.attempts, 2);
      expect(result.isClean, isTrue);
    });

    test('levels that were already right are named so they survive the retry',
        () async {
      final mixed = reply([
        levelJson('Letters A B', ['A', 'B']),
        '{"title":"","subtitle":"","passingScore":60,"contentItems":[]}',
      ]);
      final client = FakeLlmClient([mixed, mixed, mixed]);

      await AiContentGenerator(client: client).generateStage(request());

      expect(client.lastUserMessage, contains('Level 3'));
      expect(client.lastUserMessage, contains('unchanged'));
    });

    test('the wrong number of levels is a batch problem, not a level one',
        () async {
      final client = FakeLlmClient([
        reply([levelJson('Letters A B', ['A', 'B'])]),
      ]);
      final result = await AiContentGenerator(client: client)
          .generateStage(request(levelCount: 5));

      expect(result.batchIssues.map((i) => i.rule),
          contains(DraftRule.wrongLevelCount));
    });
  });

  group('when the service itself fails', () {
    test('a bad key is reported at once and never retried', () async {
      final client = FakeLlmClient.alwaysFails(const LlmException(
        LlmFailure.unauthorized,
        'DeepSeek rejected the API key.',
      ));

      final result =
          await AiContentGenerator(client: client).generateStage(request());

      expect(client.callCount, 1, reason: 'a bad key stays bad');
      expect(result.failure?.kind, LlmFailure.unauthorized);
      expect(result.drafts, isEmpty);
      expect(result.isClean, isFalse);
    });

    test('a dropped connection is retried without spending a repair round',
        () async {
      final client = FakeLlmClient([
        const LlmException(LlmFailure.network, 'Connection reset.'),
        goodReply,
      ]);

      final result =
          await AiContentGenerator(client: client).generateStage(request());

      expect(client.callCount, 2);
      expect(result.attempts, 1, reason: 'the model only ever saw one attempt');
      expect(result.isClean, isTrue);
    });

    test('a connection that keeps dropping gives up rather than looping',
        () async {
      final client = FakeLlmClient.alwaysFails(
        const LlmException(LlmFailure.network, 'Connection reset.'),
      );

      final result =
          await AiContentGenerator(client: client).generateStage(request());

      expect(result.failure?.kind, LlmFailure.network);
      expect(client.callCount, lessThanOrEqualTo(3));
    });
  });

  test('an existing id blocks instead of silently overwriting', () async {
    final client = FakeLlmClient([goodReply]);
    final result = await AiContentGenerator(client: client).generateStage(
      request(),
      existingLevelIds: {'english-stage2-3'},
    );

    expect(result.drafts.first.blocking.map((i) => i.rule),
        contains(DraftRule.levelIdCollision));
    expect(result.drafts.first.canApprove, isFalse);
    expect(result.drafts.last.canApprove, isTrue,
        reason: 'the other level is unaffected');
  });
}
