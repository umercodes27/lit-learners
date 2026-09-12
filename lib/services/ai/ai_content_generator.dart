import '../../models/ai_level_draft.dart';
import '../../models/content_item.dart';
import '../../models/learning_level.dart';
import '../../models/quiz_question.dart';
import '../../models/video_lesson.dart';
import 'ai_level_codec.dart';
import 'content_draft_repairer.dart';
import 'content_draft_validator.dart';
import 'level_prompt_builder.dart';
import 'llm_client.dart';

class AiGenerationResult {
  const AiGenerationResult({
    required this.drafts,
    required this.attempts,
    this.batchIssues = const [],
    this.failure,
  });

  final List<AiLevelDraft> drafts;

  /// How many times the model was asked. 1 means it got it right first go.
  final int attempts;

  /// Problems with the batch as a whole rather than with one level, such as
  /// the wrong number of levels coming back.
  final List<DraftIssue> batchIssues;

  /// Set when the run stopped because of the service rather than the content
  /// — a bad key, a rate limit, no connection.
  final LlmException? failure;

  bool get hasDrafts => drafts.isNotEmpty;

  bool get isClean =>
      failure == null &&
      drafts.isNotEmpty &&
      batchIssues.every((issue) => !issue.isBlocking) &&
      drafts.every((draft) => !draft.isBlocked);
}

/// Turns one request into reviewable level drafts.
///
/// Everything deterministic is filled in here rather than asked for: ids,
/// module, stage, numbering, level type, portion labels, and every child id.
/// That is not tidiness — each of those was a rule the model could otherwise
/// break, and the cheapest way to survive a broken rule is to never let the
/// model near it.
///
/// Depends on [LlmClient] and nothing else network-shaped, so the whole
/// pipeline including the retry loop is testable against a scripted fake.
class AiContentGenerator {
  const AiContentGenerator({
    required this.client,
    this.promptBuilder = const LevelPromptBuilder(),
    this.codec = const AiLevelCodec(),
    this.validator = const ContentDraftValidator(),
    this.repairer = const ContentDraftRepairer(),
    this.maxAttempts = 3,
    this.maxTransportRetries = 1,
  });

  final LlmClient client;
  final LevelPromptBuilder promptBuilder;
  final AiLevelCodec codec;
  final ContentDraftValidator validator;
  final ContentDraftRepairer repairer;

  /// One first go plus two repair rounds. Each round is real money and up to
  /// a minute, and a violation that survives two *targeted* corrections is
  /// almost always a judgement problem a fourth round will not fix either.
  final int maxAttempts;

  /// A dropped connection should not eat the repair budget, so transport
  /// retries are counted separately from schema rounds.
  final int maxTransportRetries;

  Future<AiGenerationResult> generateStage(
    AiGenerationRequest request, {
    Set<String> existingLevelIds = const {},
    Set<String> existingQuizIds = const {},
    Set<String> existingTitles = const {},
    Set<String> knownModuleIds = const {},
  }) async {
    var messages = promptBuilder.build(request);
    var attempts = 0;
    var transportRetries = 0;

    var drafts = <AiLevelDraft>[];
    var batchIssues = <DraftIssue>[];

    while (attempts < maxAttempts) {
      attempts++;

      final LlmCompletion completion;
      try {
        completion = await client.complete(
          LlmCompletionRequest(messages: messages),
        );
      } on LlmException catch (error) {
        final canRetry =
            error.isRetryable && transportRetries < maxTransportRetries;
        if (!canRetry) {
          return AiGenerationResult(
            drafts: drafts,
            attempts: attempts,
            batchIssues: batchIssues,
            failure: error,
          );
        }
        transportRetries++;
        attempts--; // the model never saw this one
        continue;
      }

      final List<AiLevelPayload> payloads;
      try {
        payloads = codec.decodeEnvelope(completion.text);
      } on AiDecodeException catch (error) {
        if (attempts >= maxAttempts) {
          return AiGenerationResult(
            drafts: drafts,
            attempts: attempts,
            batchIssues: [
              ...batchIssues,
              _unreadable(error, truncated: completion.wasTruncated),
            ],
          );
        }
        messages = [
          ...messages,
          LlmMessage.assistant(completion.text),
          LlmMessage.user(promptBuilder.repairForUnreadableReply(
            completion.wasTruncated
                ? '${error.message} The reply was also cut off before it '
                    'finished, so return fewer levels if you must.'
                : error.message,
          )),
        ];
        continue;
      }

      final repaired = [
        for (var i = 0; i < payloads.length; i++)
          repairer.repair(_assemble(payloads[i], i, request)),
      ];

      final validation = validator.validateStage(
        [for (final r in repaired) r.level],
        expectedLevelCount: request.levelCount,
        expectedFirstLevelNumber: request.firstLevelNumber,
        existingLevelIds: existingLevelIds,
        existingQuizIds: existingQuizIds,
        existingTitles: existingTitles,
        knownModuleIds: knownModuleIds,
      );

      drafts = _toDrafts(repaired, validation.issues);
      batchIssues = _batchIssues(validation.issues);

      final blocked = validation.isBlocked;
      if (!blocked) {
        return AiGenerationResult(
          drafts: drafts,
          attempts: attempts,
          batchIssues: batchIssues,
        );
      }

      if (attempts >= maxAttempts) break;

      messages = [
        ...messages,
        LlmMessage.assistant(completion.text),
        LlmMessage.user(promptBuilder.repairForIssues(
          validation.issues,
          levelCount: request.levelCount,
          correctLevelNumbers: {
            for (final draft in drafts)
              if (!draft.isBlocked) draft.level.levelNumber,
          },
        )),
      ];
    }

    // Out of attempts. Every draft comes back with its problems attached
    // rather than being thrown away: a level the model could not fix is
    // usually one edit away from correct, and that edit is why the review
    // screen exists.
    return AiGenerationResult(
      drafts: drafts,
      attempts: attempts,
      batchIssues: batchIssues,
    );
  }

  /// Re-checks drafts after the admin has edited one by hand.
  ///
  /// Runs the same whole-batch validation as generation rather than checking
  /// the edited level alone, because some problems only exist between levels:
  /// renaming a level can collide with another title, and fixing one glyph
  /// does not change whether the numbering still runs unbroken.
  ///
  /// Repairs are carried over untouched and the repairer is deliberately not
  /// run again — it exists to clean up what a model produced, and re-running
  /// it over an admin's typing would argue with them mid-edit.
  AiGenerationResult revalidate(
    List<AiLevelDraft> drafts, {
    required AiGenerationRequest request,
    Set<String> existingLevelIds = const {},
    Set<String> existingQuizIds = const {},
    Set<String> existingTitles = const {},
    Set<String> knownModuleIds = const {},
  }) {
    final validation = validator.validateStage(
      [for (final draft in drafts) draft.level],
      expectedLevelCount: request.levelCount,
      expectedFirstLevelNumber: request.firstLevelNumber,
      existingLevelIds: existingLevelIds,
      existingQuizIds: existingQuizIds,
      existingTitles: existingTitles,
      knownModuleIds: knownModuleIds,
    );

    return AiGenerationResult(
      drafts: [
        for (var i = 0; i < drafts.length; i++)
          drafts[i].copyWith(
            issues: [
              for (final issue in validation.issues)
                if (_belongsTo(issue, i)) issue,
            ],
          ),
      ],
      attempts: 0,
      batchIssues: _batchIssues(validation.issues),
    );
  }

  /// Fills in everything the model was never asked for.
  LearningLevel _assemble(
    AiLevelPayload payload,
    int index,
    AiGenerationRequest request,
  ) {
    final levelNumber = request.firstLevelNumber + index;
    // A rewrite keeps the id of the level it replaces. Built-in ids do not all
    // follow the '<module>-stage<n>-<m>' pattern, so the pattern cannot be
    // relied on to land on the same one.
    final id = request.revising?.id ??
        '${request.moduleId}-stage${request.stage}-$levelNumber';

    return LearningLevel(
      id: id,
      moduleId: request.moduleId,
      stage: request.stage,
      // Assigned by position, which is what makes the numbering unbroken by
      // construction rather than by asking nicely.
      levelNumber: levelNumber,
      title: payload.title,
      subtitle: payload.subtitle,
      type: request.type,
      passingScore: payload.passingScore,
      // Generated content is not in the APK, so it is never bundled — unless
      // it is a rewrite of a level that is, which keeps its offline flag.
      isBundled: request.revising?.isBundled ?? false,
      portionLabel: _portionLabel(request.type, payload.contentItems),
      contentItems: payload.contentItems,
      quizQuestions: [
        for (var i = 0; i < payload.quizQuestions.length; i++)
          QuizQuestion(
            // The primary key in sqflite, so it is derived from the level id
            // rather than trusted to be unique.
            id: '$id-q${i + 1}',
            prompt: payload.quizQuestions[i].prompt,
            options: payload.quizQuestions[i].options,
            correctIndex: payload.quizQuestions[i].correctIndex,
            visualLabel: payload.quizQuestions[i].visualLabel,
            explanation: payload.quizQuestions[i].explanation,
          ),
      ],
      videoLessons: [
        for (var i = 0; i < payload.videoLessons.length; i++)
          VideoLesson(
            id: '$id-video${i + 1}',
            title: payload.videoLessons[i].title,
            description: payload.videoLessons[i].description,
            durationLabel: payload.videoLessons[i].durationLabel,
            videoUrl: payload.videoLessons[i].videoUrl,
            thumbnailLabel: payload.videoLessons[i].thumbnailLabel,
          ),
      ],
    );
  }

  /// Levels that walk through a sequence get a portion label; a story, a
  /// drawing or a video is not a slice of anything, so it gets none. Matches
  /// which shipped levels carry one.
  static const _sequenceTypes = {
    LevelType.flashcards,
    LevelType.counting,
    LevelType.matching,
    LevelType.tracing,
  };

  String? _portionLabel(LevelType type, List<ContentItem> items) {
    if (!_sequenceTypes.contains(type) || items.isEmpty) return null;

    final first = items.first.title.trim();
    final last = items.last.title.trim();
    if (first.isEmpty || last.isEmpty) return null;

    // A spaced en-dash, which is what the shipped labels use and what the
    // portion ladder test checks for. Not a hyphen.
    return first == last ? first : '$first \u2013 $last';
  }

  List<AiLevelDraft> _toDrafts(
    List<RepairedLevel> repaired,
    List<DraftIssue> issues,
  ) {
    return [
      for (var i = 0; i < repaired.length; i++)
        AiLevelDraft(
          level: repaired[i].level,
          issues: [
            for (final issue in issues)
              if (_belongsTo(issue, i)) issue,
          ],
          repairs: repaired[i].notes,
        ),
    ];
  }

  /// Matches on the path the validator builds. Compared exactly rather than
  /// by prefix, or `levels[1]` would claim everything belonging to
  /// `levels[10]`.
  bool _belongsTo(DraftIssue issue, int index) {
    final prefix = 'levels[$index]';
    return issue.path == prefix || issue.path.startsWith('$prefix.');
  }

  List<DraftIssue> _batchIssues(List<DraftIssue> issues) => [
        for (final issue in issues)
          if (!issue.path.startsWith('levels[')) issue,
      ];

  DraftIssue _unreadable(AiDecodeException error, {required bool truncated}) {
    return DraftIssue(
      rule: DraftRule.unreadableReply,
      severity: DraftSeverity.blocking,
      path: 'levels',
      message: truncated
          ? 'The reply was cut off before it finished. Try asking for fewer '
              'levels.'
          : 'The reply could not be read: ${error.message}',
      modelHint: error.message,
    );
  }
}
