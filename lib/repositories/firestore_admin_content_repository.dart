import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/admin_content.dart';
import '../models/content_item.dart';
import '../models/learning_level.dart';
import '../models/learning_module.dart';
import '../models/quiz_question.dart';
import '../models/video_lesson.dart';
import '../services/firebase/firestore_content_remote_data_source.dart';
import 'admin_content_repository.dart';

class FirestoreAdminContentRepository implements AdminContentRepository {
  /// [firestore] must be Firestore on the *admin* app — see
  /// [AdminFirebaseApp]. Required rather than defaulted, because the default
  /// instance runs as the parent and every write here would be denied.
  const FirestoreAdminContentRepository({required FirebaseFirestore firestore})
      : _firestore = firestore;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _modulesRef {
    return _firestore.collection(
      FirestoreContentRemoteDataSource.modulesCollection,
    );
  }

  CollectionReference<Map<String, dynamic>> get _levelsRef {
    return _firestore.collection(
      FirestoreContentRemoteDataSource.levelsCollection,
    );
  }

  @override
  Future<void> deleteLevel(String levelId) async {
    await _levelsRef.doc(levelId).delete();
  }

  @override
  Future<void> deleteModule(String moduleId) async {
    final moduleLevels =
        await _levelsRef.where('moduleId', isEqualTo: moduleId).get();
    final batch = _firestore.batch();
    batch.delete(_modulesRef.doc(moduleId));
    for (final doc in moduleLevels.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  @override
  Future<List<AdminContentLevel>> getLevels({String? moduleId}) async {
    final snapshot = moduleId == null
        ? await _levelsRef.get()
        : await _levelsRef.where('moduleId', isEqualTo: moduleId).get();
    final levels = snapshot.docs.map(_levelFromDoc).toList()
      ..sort((a, b) {
        final moduleCompare = a.level.moduleId.compareTo(b.level.moduleId);
        if (moduleCompare != 0) return moduleCompare;
        final stageCompare = a.level.stage.compareTo(b.level.stage);
        if (stageCompare != 0) return stageCompare;
        return a.level.levelNumber.compareTo(b.level.levelNumber);
      });
    return levels;
  }

  @override
  Future<List<AdminContentModule>> getModules() async {
    final snapshot = await _modulesRef.orderBy('sortOrder').get();
    return snapshot.docs.map(_moduleFromDoc).toList();
  }

  @override
  Future<AdminContentLevel> upsertLevel(AdminContentLevel level) async {
    final now = DateTime.now();
    final updated = level.copyWith(updatedAt: now);
    await _levelsRef.doc(level.level.id).set(
          _levelToRemoteMap(updated),
          SetOptions(merge: true),
        );
    return updated;
  }

  /// Commits every level in one [WriteBatch].
  ///
  /// Firestore applies a batch atomically on the server: all the documents
  /// land or none of them do. That is the whole point here — a connection
  /// that drops halfway through a five-level stage must not leave a ladder
  /// with a hole in it, because a missing levelNumber locks everything after
  /// it permanently rather than merely being absent.
  @override
  Future<List<AdminContentLevel>> upsertLevels(
    List<AdminContentLevel> levels,
  ) async {
    if (levels.isEmpty) return const [];
    if (levels.length > _batchWriteLimit) {
      throw ArgumentError(
        'A batch can hold at most $_batchWriteLimit levels, '
        'got ${levels.length}.',
      );
    }

    final now = DateTime.now();
    final updated = [for (final level in levels) level.copyWith(updatedAt: now)];

    final batch = _firestore.batch();
    for (final level in updated) {
      batch.set(
        _levelsRef.doc(level.level.id),
        _levelToRemoteMap(level),
        SetOptions(merge: true),
      );
    }
    await batch.commit();

    return updated;
  }

  /// Firestore's own ceiling on operations in one batch.
  static const _batchWriteLimit = 500;

  @override
  Future<AdminContentModule> upsertModule(AdminContentModule module) async {
    final now = DateTime.now();
    final updated = module.copyWith(updatedAt: now);
    await _modulesRef.doc(module.module.id).set(
          _moduleToRemoteMap(updated),
          SetOptions(merge: true),
        );
    return updated;
  }

  AdminContentModule _moduleFromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final now = DateTime.now();
    return AdminContentModule(
      module: LearningModule(
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
      ),
      isPublished: (data['isPublished'] as bool?) ?? false,
      createdAt: _dateFromRemoteValue(data['createdAt']) ?? now,
      updatedAt: _dateFromRemoteValue(data['updatedAt']) ?? now,
      publishStatus: _publishStatusFromRemote(
        data['publishStatus'],
        (data['isPublished'] as bool?) ?? false,
      ),
      version: (data['version'] as num?)?.toInt() ?? 1,
      submittedAt: _dateFromRemoteValue(data['submittedAt']),
      publishedAt: _dateFromRemoteValue(data['publishedAt']),
    );
  }

  AdminContentLevel _levelFromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final now = DateTime.now();
    return AdminContentLevel(
      level: LearningLevel(
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
        // Written by _levelToRemoteMap but, until this line, never read back —
        // so a portion label survived the save and vanished on the next load.
        portionLabel: data['portionLabel'] as String?,
        contentItems: _contentItemsFromRemoteValue(data['contentItems']),
        quizQuestions: _quizQuestionsFromRemoteValue(data['quizQuestions']),
        videoLessons: _videoLessonsFromRemoteValue(data['videoLessons']),
      ),
      isPublished: (data['isPublished'] as bool?) ?? false,
      createdAt: _dateFromRemoteValue(data['createdAt']) ?? now,
      updatedAt: _dateFromRemoteValue(data['updatedAt']) ?? now,
      publishStatus: _publishStatusFromRemote(
        data['publishStatus'],
        (data['isPublished'] as bool?) ?? false,
      ),
      version: (data['version'] as num?)?.toInt() ?? 1,
      submittedAt: _dateFromRemoteValue(data['submittedAt']),
      publishedAt: _dateFromRemoteValue(data['publishedAt']),
    );
  }

  Map<String, Object?> _moduleToRemoteMap(AdminContentModule module) {
    return {
      'moduleId': module.module.id,
      'title': module.module.title,
      'description': module.module.description,
      'category': module.module.category.name,
      'minStage': module.module.minStage,
      'maxStage': module.module.maxStage,
      'sortOrder': module.module.order,
      'isPublished': module.isPublished,
      'publishStatus': module.publishStatus.name,
      'version': module.version,
      'createdAt': Timestamp.fromDate(module.createdAt),
      'updatedAt': Timestamp.fromDate(module.updatedAt),
      'submittedAt': _timestampOrNull(module.submittedAt),
      'publishedAt': _timestampOrNull(module.publishedAt),
    };
  }

  Map<String, Object?> _levelToRemoteMap(AdminContentLevel level) {
    return {
      'levelId': level.level.id,
      'moduleId': level.level.moduleId,
      'stage': level.level.stage,
      'levelNumber': level.level.levelNumber,
      'title': level.level.title,
      'subtitle': level.level.subtitle,
      'levelType': level.level.type.name,
      'passingScore': level.level.passingScore,
      'isBundled': level.level.isBundled,
      'portionLabel': level.level.portionLabel,
      'isPublished': level.isPublished,
      'publishStatus': level.publishStatus.name,
      'version': level.version,
      'contentItems': level.level.contentItems.map(_contentItemToMap).toList(),
      'quizQuestions':
          level.level.quizQuestions.map(_quizQuestionToMap).toList(),
      'videoLessons': level.level.videoLessons.map(_videoLessonToMap).toList(),
      'createdAt': Timestamp.fromDate(level.createdAt),
      'updatedAt': Timestamp.fromDate(level.updatedAt),
      'submittedAt': _timestampOrNull(level.submittedAt),
      'publishedAt': _timestampOrNull(level.publishedAt),
    };
  }

  Map<String, Object?> _contentItemToMap(ContentItem item) {
    return {
      'title': item.title,
      'prompt': item.prompt,
      'displayText': item.displayText,
      'visualLabel': item.visualLabel,
      'audioCueKey': item.audioCueKey,
    };
  }

  Map<String, Object?> _quizQuestionToMap(QuizQuestion question) {
    return {
      'questionId': question.id,
      'prompt': question.prompt,
      'options': question.options,
      'correctIndex': question.correctIndex,
      'visualLabel': question.visualLabel,
      'explanation': question.explanation,
    };
  }

  Map<String, Object?> _videoLessonToMap(VideoLesson lesson) {
    return {
      'videoLessonId': lesson.id,
      'title': lesson.title,
      'description': lesson.description,
      'durationLabel': lesson.durationLabel,
      'videoUrl': lesson.videoUrl,
      'thumbnailLabel': lesson.thumbnailLabel,
    };
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

  DateTime? _dateFromRemoteValue(Object? value) {
    return switch (value) {
      Timestamp timestamp => timestamp.toDate(),
      DateTime dateTime => dateTime,
      String text => DateTime.tryParse(text),
      _ => null,
    };
  }

  Timestamp? _timestampOrNull(DateTime? value) {
    if (value == null) return null;
    return Timestamp.fromDate(value);
  }

  AdminPublishStatus _publishStatusFromRemote(
    Object? value,
    bool isPublished,
  ) {
    if (value is String) {
      return _enumByName(
        AdminPublishStatus.values,
        value,
        isPublished ? AdminPublishStatus.published : AdminPublishStatus.draft,
      );
    }

    return isPublished
        ? AdminPublishStatus.published
        : AdminPublishStatus.draft;
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
