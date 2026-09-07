import 'content_item.dart';
import 'quiz_question.dart';
import 'video_lesson.dart';

enum LevelType {
  flashcards,
  counting,
  matching,
  story,
  drawing,
  tracing,
  video,
}

class LearningLevel {
  const LearningLevel({
    required this.id,
    required this.moduleId,
    required this.stage,
    required this.levelNumber,
    required this.title,
    required this.subtitle,
    required this.type,
    required this.passingScore,
    required this.isBundled,
    this.portionLabel,
    this.isDownloaded = false,
    this.contentItems = const [],
    this.quizQuestions = const [],
    this.videoLessons = const [],
  });

  final String id;
  final String moduleId;
  final int stage;
  final int levelNumber;
  final String title;
  final String subtitle;
  final LevelType type;
  final int passingScore;
  final bool isBundled;

  /// The slice of the module this level covers, e.g. `A – F` or `1 – 5`.
  ///
  /// Levels are walked in order and their content is walked in order inside
  /// them, so this is what tells a parent where in the alphabet (or the number
  /// line) a level sits. Null for modules that are not a sequence, like Story.
  final String? portionLabel;
  final bool isDownloaded;
  final List<ContentItem> contentItems;
  final List<QuizQuestion> quizQuestions;
  final List<VideoLesson> videoLessons;

  bool get isAvailableOffline => isBundled || isDownloaded;

  /// [clearPortionLabel] exists because `portionLabel ?? this.portionLabel`
  /// cannot express "set this back to null". The AI draft repairer needs to,
  /// when a generated level turns out to be a kind that has no portion — a
  /// story or a video, which are not a sequence through an alphabet.
  LearningLevel copyWith({
    String? id,
    String? moduleId,
    int? stage,
    int? levelNumber,
    String? title,
    String? subtitle,
    LevelType? type,
    int? passingScore,
    bool? isBundled,
    String? portionLabel,
    bool clearPortionLabel = false,
    bool? isDownloaded,
    List<ContentItem>? contentItems,
    List<QuizQuestion>? quizQuestions,
    List<VideoLesson>? videoLessons,
  }) {
    return LearningLevel(
      id: id ?? this.id,
      moduleId: moduleId ?? this.moduleId,
      stage: stage ?? this.stage,
      levelNumber: levelNumber ?? this.levelNumber,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      type: type ?? this.type,
      passingScore: passingScore ?? this.passingScore,
      isBundled: isBundled ?? this.isBundled,
      portionLabel:
          clearPortionLabel ? null : (portionLabel ?? this.portionLabel),
      isDownloaded: isDownloaded ?? this.isDownloaded,
      contentItems: contentItems ?? this.contentItems,
      quizQuestions: quizQuestions ?? this.quizQuestions,
      videoLessons: videoLessons ?? this.videoLessons,
    );
  }
}
