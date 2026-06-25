import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/content_item.dart';
import '../../models/learning_level.dart';
import '../../models/learning_module.dart';
import '../../models/quiz_question.dart';
import '../../models/video_lesson.dart';
import '../remote/content_remote_data_source.dart';

class FirestoreContentRemoteDataSource implements ContentRemoteDataSource {
  FirestoreContentRemoteDataSource({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  static const modulesCollection = 'learningModules';
  static const levelsCollection = 'learningLevels';

  final FirebaseFirestore _firestore;

  @override
  Future<ContentBundle> getPublishedContent() async {
    final moduleSnapshot = await _firestore
        .collection(modulesCollection)
        .orderBy('sortOrder')
        .get();
    final levelSnapshot = await _firestore.collection(levelsCollection).get();

    final modules = moduleSnapshot.docs
        .where((doc) => _isPublished(doc.data()))
        .map(_moduleFromDoc)
        .toList();
    final publishedModuleIds = modules.map((module) => module.id).toSet();
    final levels = levelSnapshot.docs
        .where((doc) => _isPublished(doc.data()))
        .map(_levelFromDoc)
        .where((level) => publishedModuleIds.contains(level.moduleId))
        .toList()
      ..sort((a, b) {
        final moduleCompare = a.moduleId.compareTo(b.moduleId);
        if (moduleCompare != 0) return moduleCompare;
        final stageCompare = a.stage.compareTo(b.stage);
        if (stageCompare != 0) return stageCompare;
        return a.levelNumber.compareTo(b.levelNumber);
      });

    return ContentBundle(modules: modules, levels: levels);
  }

  bool _isPublished(Map<String, dynamic> data) {
    return data['isPublished'] != false;
  }

  LearningModule _moduleFromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    return LearningModule(
      id: (data['moduleId'] as String?) ?? doc.id,
      title: (data['title'] as String?) ?? 'Untitled Module',
      description: (data['description'] as String?) ?? '',
      category: _enumByName(
        ModuleCategory.values,
        data['category'] as String?,
        ModuleCategory.math,
      ),
      minStage: (data['minStage'] as num?)?.toInt() ?? 1,
      maxStage: (data['maxStage'] as num?)?.toInt() ?? 4,
      order: (data['sortOrder'] as num?)?.toInt() ?? 0,
    );
  }

  LearningLevel _levelFromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    return LearningLevel(
      id: (data['levelId'] as String?) ?? doc.id,
      moduleId: (data['moduleId'] as String?) ?? '',
      stage: (data['stage'] as num?)?.toInt() ?? 1,
      levelNumber: (data['levelNumber'] as num?)?.toInt() ?? 1,
      title: (data['title'] as String?) ?? 'Untitled Level',
      subtitle: (data['subtitle'] as String?) ?? '',
      type: _enumByName(
        LevelType.values,
        data['levelType'] as String?,
        LevelType.flashcards,
      ),
      passingScore: (data['passingScore'] as num?)?.toInt() ?? 70,
      isBundled: (data['isBundled'] as bool?) ?? false,
      contentItems: _contentItemsFromRemoteValue(data['contentItems']),
      quizQuestions: _quizQuestionsFromRemoteValue(data['quizQuestions']),
      videoLessons: _videoLessonsFromRemoteValue(data['videoLessons']),
    );
  }

  List<ContentItem> _contentItemsFromRemoteValue(Object? value) {
    return _mapList(value).map((data) {
      return ContentItem(
        title: (data['title'] as String?) ?? '',
        prompt: (data['prompt'] as String?) ?? '',
        displayText: (data['displayText'] as String?) ?? '',
        visualLabel: (data['visualLabel'] as String?) ?? '',
        audioCueKey: data['audioCueKey'] as String?,
      );
    }).toList();
  }

  List<QuizQuestion> _quizQuestionsFromRemoteValue(Object? value) {
    return _mapList(value).map((data) {
      return QuizQuestion(
        id: (data['questionId'] as String?) ?? (data['id'] as String?) ?? '',
        prompt: (data['prompt'] as String?) ?? '',
        options: _stringListFromRemoteValue(data['options']),
        correctIndex: (data['correctIndex'] as num?)?.toInt() ?? 0,
        visualLabel: data['visualLabel'] as String?,
        explanation: data['explanation'] as String?,
      );
    }).toList();
  }

  List<VideoLesson> _videoLessonsFromRemoteValue(Object? value) {
    return _mapList(value).map((data) {
      return VideoLesson(
        id: (data['videoLessonId'] as String?) ?? (data['id'] as String?) ?? '',
        title: (data['title'] as String?) ?? '',
        description: (data['description'] as String?) ?? '',
        durationLabel: (data['durationLabel'] as String?) ?? '',
        videoUrl: (data['videoUrl'] as String?) ?? '',
        thumbnailLabel: (data['thumbnailLabel'] as String?) ?? '',
      );
    }).toList();
  }

  List<Map<String, dynamic>> _mapList(Object? value) {
    if (value is! Iterable) return const [];
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  List<String> _stringListFromRemoteValue(Object? value) {
    if (value is! Iterable) return const [];
    return value.map((item) => item.toString()).toList();
  }

  T _enumByName<T extends Enum>(
    List<T> values,
    String? name,
    T fallback,
  ) {
    for (final value in values) {
      if (value.name == name) return value;
    }
    return fallback;
  }
}
