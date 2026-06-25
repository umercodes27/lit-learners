import 'content_item.dart';
import 'quiz_question.dart';
import 'video_lesson.dart';

enum LevelType {
  flashcards,
  counting,
  matching,
  story,
  drawing,
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
  final bool isDownloaded;
  final List<ContentItem> contentItems;
  final List<QuizQuestion> quizQuestions;
  final List<VideoLesson> videoLessons;

  bool get isAvailableOffline => isBundled || isDownloaded;

  LearningLevel copyWith({
    bool? isDownloaded,
  }) {
    return LearningLevel(
      id: id,
      moduleId: moduleId,
      stage: stage,
      levelNumber: levelNumber,
      title: title,
      subtitle: subtitle,
      type: type,
      passingScore: passingScore,
      isBundled: isBundled,
      isDownloaded: isDownloaded ?? this.isDownloaded,
      contentItems: contentItems,
      quizQuestions: quizQuestions,
      videoLessons: videoLessons,
    );
  }
}
