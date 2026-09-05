import '../services/ai/content_draft_validator.dart';
import 'content_item.dart';
import 'learning_level.dart';
import 'learning_module.dart';

/// What the admin asked the model for.
class AiGenerationRequest {
  const AiGenerationRequest({
    required this.moduleId,
    required this.moduleTitle,
    required this.category,
    required this.stage,
    required this.levelCount,
    required this.type,
    required this.firstLevelNumber,
    this.guidance = '',
    this.existingTitles = const [],
    this.existingPortions = const [],
  });

  final String moduleId;
  final String moduleTitle;
  final ModuleCategory category;
  final int stage;
  final int levelCount;

  /// Chosen by the admin, never by the model. Asking a model to pick between
  /// [LevelType] and [ModuleCategory] — two enums that share six of their
  /// names — invites exactly the confusion it cannot recover from.
  final LevelType type;

  /// Where this stage continues from. Numbering must be unbroken or every
  /// level after a gap stays locked forever.
  final int firstLevelNumber;

  /// Free text from the admin, passed through untouched.
  final String guidance;

  /// What the stage already covers, so the model continues the ladder
  /// instead of writing "Letters A – F" for the third time.
  final List<String> existingTitles;
  final List<String> existingPortions;

  int get lastLevelNumber => firstLevelNumber + levelCount - 1;
}

/// A quiz question as the model returns it: no id, because ids are the
/// database key and the app assigns them.
class AiQuizPayload {
  const AiQuizPayload({
    required this.prompt,
    required this.options,
    required this.correctIndex,
    this.visualLabel,
    this.explanation,
  });

  final String prompt;
  final List<String> options;
  final int correctIndex;
  final String? visualLabel;
  final String? explanation;
}

/// A video lesson as the model returns it, likewise without an id.
class AiVideoPayload {
  const AiVideoPayload({
    required this.title,
    required this.description,
    required this.durationLabel,
    required this.videoUrl,
    required this.thumbnailLabel,
  });

  final String title;
  final String description;
  final String durationLabel;
  final String videoUrl;
  final String thumbnailLabel;
}

/// One level as the model returns it, before the app fills in everything
/// deterministic: id, moduleId, stage, levelNumber, portionLabel, isBundled
/// and every child id.
class AiLevelPayload {
  const AiLevelPayload({
    required this.title,
    required this.subtitle,
    required this.passingScore,
    this.contentItems = const [],
    this.quizQuestions = const [],
    this.videoLessons = const [],
  });

  final String title;
  final String subtitle;
  final int passingScore;
  final List<ContentItem> contentItems;
  final List<AiQuizPayload> quizQuestions;
  final List<AiVideoPayload> videoLessons;
}

/// An assembled level, plus everything the admin needs to decide about it.
class AiLevelDraft {
  const AiLevelDraft({
    required this.level,
    this.issues = const [],
    this.repairs = const [],
    this.isApproved = false,
  });

  final LearningLevel level;

  /// Problems found after assembly and repair. A draft with any blocking
  /// issue cannot be approved — that is the enforcement point of the whole
  /// feature.
  final List<DraftIssue> issues;

  /// What was fixed automatically, in plain English. Shown to the admin so
  /// nothing changes invisibly.
  final List<String> repairs;

  final bool isApproved;

  bool get isBlocked => issues.any((issue) => issue.isBlocking);

  List<DraftIssue> get blocking =>
      issues.where((issue) => issue.isBlocking).toList();

  List<DraftIssue> get warnings =>
      issues.where((issue) => !issue.isBlocking).toList();

  /// Approval is not merely defaulted to false — it is unrepresentable while
  /// the draft is broken, so no caller can set it by mistake.
  bool get canApprove => !isBlocked;

  AiLevelDraft copyWith({
    LearningLevel? level,
    List<DraftIssue>? issues,
    List<String>? repairs,
    bool? isApproved,
  }) {
    final nextIssues = issues ?? this.issues;
    final wanted = isApproved ?? this.isApproved;
    return AiLevelDraft(
      level: level ?? this.level,
      issues: nextIssues,
      repairs: repairs ?? this.repairs,
      isApproved:
          wanted && !nextIssues.any((issue) => issue.isBlocking),
    );
  }
}
