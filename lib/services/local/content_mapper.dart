import 'dart:convert';

import '../../models/content_item.dart';
import '../../models/learning_level.dart';
import '../../models/learning_module.dart';
import '../../models/quiz_question.dart';
import '../../models/video_lesson.dart';

class ContentMapper {
  const ContentMapper._();

  static LearningModule moduleFromLocalMap(Map<String, Object?> map) {
    return LearningModule(
      id: map['moduleId']! as String,
      title: map['title']! as String,
      description: map['description']! as String,
      category: ModuleCategory.values.byName(map['category']! as String),
      minStage: map['minStage']! as int,
      maxStage: map['maxStage']! as int,
      order: map['sortOrder']! as int,
    );
  }

  static Map<String, Object?> moduleToLocalMap(LearningModule module) {
    return {
      'moduleId': module.id,
      'title': module.title,
      'description': module.description,
      'category': module.category.name,
      'minStage': module.minStage,
      'maxStage': module.maxStage,
      'sortOrder': module.order,
    };
  }

  static LearningLevel levelFromLocalMaps({
    required Map<String, Object?> levelMap,
    required List<ContentItem> contentItems,
    required List<QuizQuestion> quizQuestions,
    required List<VideoLesson> videoLessons,
  }) {
    return LearningLevel(
      id: levelMap['levelId']! as String,
      moduleId: levelMap['moduleId']! as String,
      stage: levelMap['stage']! as int,
      levelNumber: levelMap['levelNumber']! as int,
      title: levelMap['title']! as String,
      subtitle: levelMap['subtitle']! as String,
      type: LevelType.values.byName(levelMap['levelType']! as String),
      passingScore: levelMap['passingScore']! as int,
      isBundled: (levelMap['isBundled']! as int) == 1,
      isDownloaded: (levelMap['isDownloaded']! as int) == 1,
      contentItems: contentItems,
      quizQuestions: quizQuestions,
      videoLessons: videoLessons,
    );
  }

  static Map<String, Object?> levelToLocalMap(LearningLevel level) {
    return {
      'levelId': level.id,
      'moduleId': level.moduleId,
      'stage': level.stage,
      'levelNumber': level.levelNumber,
      'title': level.title,
      'subtitle': level.subtitle,
      'levelType': level.type.name,
      'passingScore': level.passingScore,
      'isBundled': level.isBundled ? 1 : 0,
      'isDownloaded': level.isAvailableOffline ? 1 : 0,
    };
  }

  static ContentItem contentItemFromLocalMap(Map<String, Object?> map) {
    return ContentItem(
      title: map['title']! as String,
      prompt: map['prompt']! as String,
      displayText: map['displayText']! as String,
      visualLabel: map['visualLabel']! as String,
      audioCueKey: map['audioCueKey'] as String?,
    );
  }

  static Map<String, Object?> contentItemToLocalMap({
    required ContentItem item,
    required String id,
    required String levelId,
    required int sortOrder,
  }) {
    return {
      'id': id,
      'levelId': levelId,
      'sortOrder': sortOrder,
      'title': item.title,
      'prompt': item.prompt,
      'displayText': item.displayText,
      'visualLabel': item.visualLabel,
      'audioCueKey': item.audioCueKey,
    };
  }

  static QuizQuestion quizQuestionFromLocalMap(Map<String, Object?> map) {
    final decodedOptions = jsonDecode(map['optionsJson']! as String) as List;
    return QuizQuestion(
      id: map['questionId']! as String,
      prompt: map['prompt']! as String,
      options: decodedOptions.cast<String>(),
      correctIndex: map['correctIndex']! as int,
      visualLabel: map['visualLabel'] as String?,
      explanation: map['explanation'] as String?,
    );
  }

  static Map<String, Object?> quizQuestionToLocalMap({
    required QuizQuestion question,
    required String levelId,
    required int sortOrder,
  }) {
    return {
      'questionId': question.id,
      'levelId': levelId,
      'sortOrder': sortOrder,
      'prompt': question.prompt,
      'optionsJson': jsonEncode(question.options),
      'correctIndex': question.correctIndex,
      'visualLabel': question.visualLabel,
      'explanation': question.explanation,
    };
  }

  static VideoLesson videoLessonFromLocalMap(Map<String, Object?> map) {
    return VideoLesson(
      id: map['videoLessonId']! as String,
      title: map['title']! as String,
      description: map['description']! as String,
      durationLabel: map['durationLabel']! as String,
      videoUrl: map['videoUrl']! as String,
      thumbnailLabel: map['thumbnailLabel']! as String,
    );
  }

  static Map<String, Object?> videoLessonToLocalMap({
    required VideoLesson lesson,
    required String levelId,
    required int sortOrder,
  }) {
    return {
      'videoLessonId': lesson.id,
      'levelId': levelId,
      'sortOrder': sortOrder,
      'title': lesson.title,
      'description': lesson.description,
      'durationLabel': lesson.durationLabel,
      'videoUrl': lesson.videoUrl,
      'thumbnailLabel': lesson.thumbnailLabel,
    };
  }
}
