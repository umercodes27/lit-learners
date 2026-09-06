import 'package:flutter/foundation.dart';

import '../models/admin_content.dart';
import '../models/content_item.dart';
import '../models/learning_level.dart';
import '../models/learning_module.dart';
import '../models/quiz_question.dart';
import '../models/video_lesson.dart';
import '../repositories/admin_authorization_repository.dart';
import '../repositories/admin_content_repository.dart';
import '../services/sync/content_sync_service.dart';

class AdminContentViewModel extends ChangeNotifier {
  AdminContentViewModel(
    this._adminContentRepository, {
    ContentSyncService? contentSyncService,
  }) : _contentSyncService = contentSyncService;

  final AdminContentRepository _adminContentRepository;
  final ContentSyncService? _contentSyncService;

  List<AdminContentModule> _modules = [];
  List<AdminContentLevel> _levels = [];
  bool _isLoading = false;
  String? _errorMessage;
  String? _infoMessage;

  List<AdminContentModule> get modules => List.unmodifiable(_modules);
  List<AdminContentLevel> get levels => List.unmodifiable(_levels);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get infoMessage => _infoMessage;

  Future<void> loadContent() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _modules = await _adminContentRepository.getModules();
      _levels = await _adminContentRepository.getLevels();
    } catch (error) {
      _errorMessage = _messageFor(
        error,
        fallback: 'Admin content could not load.',
      );
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> createModule({
    required String id,
    required String title,
    required String description,
    required ModuleCategory category,
    required int minStage,
    required int maxStage,
    required int order,
    required bool isPublished,
    bool allowOverwrite = false,
  }) async {
    final moduleId = _slug(id.isEmpty ? title : id);
    final validationError = _validateModule(
      id: moduleId,
      title: title,
      minStage: minStage,
      maxStage: maxStage,
    );
    if (validationError != null) {
      _setError(validationError);
      return false;
    }

    // Saving is an upsert keyed on the id, so without this a second module
    // called "Math" did not fail — it quietly replaced the first one and took
    // every level under it. Overwriting stays possible, because with no edit
    // screen it is the only way to change a module, but it has to be asked
    // for rather than happening by reusing a name.
    if (!allowOverwrite && _modules.any((m) => m.module.id == moduleId)) {
      _setError(
        'A module with the ID "$moduleId" already exists. Choose a different '
        'ID, or turn on "Replace existing" to overwrite it.',
      );
      return false;
    }

    final now = DateTime.now();
    final module = AdminContentModule(
      module: LearningModule(
        id: moduleId,
        title: title.trim(),
        description: description.trim(),
        category: category,
        minStage: minStage,
        maxStage: maxStage,
        order: order,
      ),
      isPublished: isPublished,
      createdAt: now,
      updatedAt: now,
      publishStatus:
          isPublished ? AdminPublishStatus.published : AdminPublishStatus.draft,
      publishedAt: isPublished ? now : null,
    );

    return _saveModule(module, 'Module saved.');
  }

  Future<bool> createLevel({
    required String id,
    required String moduleId,
    required int stage,
    required int levelNumber,
    required String title,
    required String subtitle,
    required LevelType type,
    required int passingScore,
    required bool isPublished,
    String contentTitle = '',
    String contentPrompt = '',
    String contentDisplayText = '',
    String contentVisualLabel = '',
    String quizPrompt = '',
    List<String> quizOptions = const [],
    int quizCorrectIndex = 0,
    String videoTitle = '',
    String videoUrl = '',
    bool allowOverwrite = false,
  }) async {
    final levelId = _slug(
      id.isEmpty ? '$moduleId-stage$stage-$levelNumber' : id,
    );
    final validationError = _validateLevel(
      id: levelId,
      moduleId: moduleId,
      stage: stage,
      levelNumber: levelNumber,
      title: title,
      passingScore: passingScore,
    );
    if (validationError != null) {
      _setError(validationError);
      return false;
    }

    // The default id is built from the module, stage and number, so saving a
    // second "level 1" of the same stage silently replaced the first. As with
    // modules, overwriting stays possible but has to be asked for.
    if (!allowOverwrite && _levels.any((l) => l.level.id == levelId)) {
      _setError(
        'A level with the ID "$levelId" already exists. Change the level '
        'number or ID, or turn on "Replace existing" to overwrite it.',
      );
      return false;
    }

    final now = DateTime.now();
    final level = AdminContentLevel(
      level: LearningLevel(
        id: levelId,
        moduleId: moduleId,
        stage: stage,
        levelNumber: levelNumber,
        title: title.trim(),
        subtitle: subtitle.trim(),
        type: type,
        passingScore: passingScore,
        isBundled: false,
        contentItems: _contentItems(
          title: contentTitle,
          prompt: contentPrompt,
          displayText: contentDisplayText,
          visualLabel: contentVisualLabel,
        ),
        quizQuestions: _quizQuestions(
          levelId: levelId,
          prompt: quizPrompt,
          options: quizOptions,
          correctIndex: quizCorrectIndex,
        ),
        videoLessons: _videoLessons(
          levelId: levelId,
          title: videoTitle,
          videoUrl: videoUrl,
        ),
      ),
      isPublished: isPublished,
      createdAt: now,
      updatedAt: now,
      publishStatus:
          isPublished ? AdminPublishStatus.published : AdminPublishStatus.draft,
      publishedAt: isPublished ? now : null,
    );

    return _saveLevel(level, 'Level saved.');
  }

  Future<bool> toggleModulePublished(
    AdminContentModule module,
    bool isPublished,
  ) {
    return isPublished ? publishModule(module) : moveModuleToDraft(module);
  }

  Future<bool> toggleLevelPublished(
    AdminContentLevel level,
    bool isPublished,
  ) {
    return isPublished ? publishLevel(level) : moveLevelToDraft(level);
  }

  Future<bool> submitModuleForReview(AdminContentModule module) {
    final now = DateTime.now();
    return _saveModule(
      module.copyWith(
        isPublished: false,
        publishStatus: AdminPublishStatus.inReview,
        submittedAt: now,
        updatedAt: now,
      ),
      'Module submitted for review.',
    );
  }

  Future<bool> submitLevelForReview(AdminContentLevel level) {
    final now = DateTime.now();
    return _saveLevel(
      level.copyWith(
        isPublished: false,
        publishStatus: AdminPublishStatus.inReview,
        submittedAt: now,
        updatedAt: now,
      ),
      'Level submitted for review.',
    );
  }

  /// Number of levels currently defined for [moduleId].
  int levelCountForModule(String moduleId) {
    return _levels.where((item) => item.level.moduleId == moduleId).length;
  }

  Future<bool> publishModule(AdminContentModule module) {
    // UC-19 business rule: each module must have at least one level. Enforced
    // at publish rather than create so drafts can be built up incrementally.
    if (levelCountForModule(module.module.id) == 0) {
      _setError(
        'Add at least one level to "${module.module.title}" before publishing.',
      );
      return Future.value(false);
    }

    final now = DateTime.now();
    return _saveModule(
      module.copyWith(
        isPublished: true,
        publishStatus: AdminPublishStatus.published,
        version: module.publishStatus == AdminPublishStatus.published
            ? module.version
            : module.version + 1,
        publishedAt: now,
        updatedAt: now,
      ),
      'Module published.',
    );
  }

  Future<bool> publishLevel(AdminContentLevel level) {
    final now = DateTime.now();
    return _saveLevel(
      level.copyWith(
        isPublished: true,
        publishStatus: AdminPublishStatus.published,
        version: level.publishStatus == AdminPublishStatus.published
            ? level.version
            : level.version + 1,
        publishedAt: now,
        updatedAt: now,
      ),
      'Level published.',
    );
  }

  Future<bool> moveModuleToDraft(AdminContentModule module) {
    return _saveModule(
      module.copyWith(
        isPublished: false,
        publishStatus: AdminPublishStatus.draft,
        updatedAt: DateTime.now(),
      ),
      'Module moved to draft.',
    );
  }

  Future<bool> moveLevelToDraft(AdminContentLevel level) {
    return _saveLevel(
      level.copyWith(
        isPublished: false,
        publishStatus: AdminPublishStatus.draft,
        updatedAt: DateTime.now(),
      ),
      'Level moved to draft.',
    );
  }

  Future<bool> deleteModule(String moduleId) async {
    try {
      await _adminContentRepository.deleteModule(moduleId);
      await _syncPublishedContent();
      _infoMessage = 'Module deleted.';
      await loadContent();
      return true;
    } catch (error) {
      _setError(_messageFor(error, fallback: 'Module could not be deleted.'));
      return false;
    }
  }

  Future<bool> deleteLevel(String levelId) async {
    try {
      await _adminContentRepository.deleteLevel(levelId);
      await _syncPublishedContent();
      _infoMessage = 'Level deleted.';
      await loadContent();
      return true;
    } catch (error) {
      _setError(_messageFor(error, fallback: 'Level could not be deleted.'));
      return false;
    }
  }

  /// Saves generated levels as drafts, in one atomic write.
  ///
  /// Deliberately not a loop over [createLevel]. A stage is a ladder and
  /// unlocking walks levelNumber from 1, so a connection that drops after
  /// level 3 of 5 would not leave three useful levels — it would leave a gap
  /// that locks levels 4 and 5 permanently. The batch either lands whole or
  /// not at all.
  ///
  /// Validation is also all-or-nothing: every level is checked before any of
  /// them is written, so a bad fifth level cannot result in four saved ones.
  ///
  /// Note what this does NOT do: it never runs [_slug] on the id. The ids are
  /// already '<moduleId>-stage<n>-<m>', and slugging is ASCII-only, so an
  /// Urdu title would slug to the empty string and be rejected as missing.
  Future<bool> createLevelsFromDrafts(List<LearningLevel> levels) async {
    if (levels.isEmpty) {
      _setError('Approve at least one level before saving.');
      return false;
    }

    for (final level in levels) {
      final validationError = _validateLevel(
        id: level.id,
        moduleId: level.moduleId,
        stage: level.stage,
        levelNumber: level.levelNumber,
        title: level.title,
        passingScore: level.passingScore,
      );
      if (validationError != null) {
        _setError('${level.id}: $validationError');
        return false;
      }
    }

    final now = DateTime.now();
    final drafts = [
      for (final level in levels)
        AdminContentLevel(
          level: level,
          isPublished: false,
          createdAt: now,
          updatedAt: now,
          publishStatus: AdminPublishStatus.draft,
        ),
    ];

    try {
      await _adminContentRepository.upsertLevels(drafts);
      await _syncPublishedContent();
      _infoMessage = drafts.length == 1
          ? 'Saved 1 level as a draft.'
          : 'Saved ${drafts.length} levels as drafts.';
      await loadContent();
      return true;
    } catch (error) {
      _setError(_messageFor(error, fallback: 'Levels could not be saved.'));
      return false;
    }
  }

  Future<bool> _saveModule(
    AdminContentModule module,
    String successMessage,
  ) async {
    try {
      await _adminContentRepository.upsertModule(module);
      await _syncPublishedContent();
      _infoMessage = successMessage;
      await loadContent();
      return true;
    } catch (error) {
      _setError(_messageFor(error, fallback: 'Module could not be saved.'));
      return false;
    }
  }

  Future<bool> _saveLevel(
    AdminContentLevel level,
    String successMessage,
  ) async {
    try {
      await _adminContentRepository.upsertLevel(level);
      await _syncPublishedContent();
      _infoMessage = successMessage;
      await loadContent();
      return true;
    } catch (error) {
      _setError(_messageFor(error, fallback: 'Level could not be saved.'));
      return false;
    }
  }

  Future<void> _syncPublishedContent() async {
    await _contentSyncService?.syncNow();
  }

  List<ContentItem> _contentItems({
    required String title,
    required String prompt,
    required String displayText,
    required String visualLabel,
  }) {
    if (title.trim().isEmpty &&
        prompt.trim().isEmpty &&
        displayText.trim().isEmpty &&
        visualLabel.trim().isEmpty) {
      return const [];
    }

    return [
      ContentItem(
        title: title.trim().isEmpty ? 'Activity' : title.trim(),
        prompt: prompt.trim(),
        displayText: displayText.trim(),
        visualLabel: visualLabel.trim(),
      ),
    ];
  }

  List<QuizQuestion> _quizQuestions({
    required String levelId,
    required String prompt,
    required List<String> options,
    required int correctIndex,
  }) {
    final normalizedOptions = options
        .map((option) => option.trim())
        .where((option) => option.isNotEmpty)
        .toList();
    if (prompt.trim().isEmpty || normalizedOptions.length < 2) {
      return const [];
    }

    return [
      QuizQuestion(
        id: '$levelId-q1',
        prompt: prompt.trim(),
        options: normalizedOptions,
        correctIndex:
            correctIndex.clamp(0, normalizedOptions.length - 1).toInt(),
      ),
    ];
  }

  List<VideoLesson> _videoLessons({
    required String levelId,
    required String title,
    required String videoUrl,
  }) {
    if (videoUrl.trim().isEmpty) return const [];

    return [
      VideoLesson(
        id: '$levelId-video-1',
        title: title.trim().isEmpty ? 'Video lesson' : title.trim(),
        description: title.trim(),
        durationLabel: '0:30',
        videoUrl: videoUrl.trim(),
        thumbnailLabel: title.trim().isEmpty ? 'Video lesson' : title.trim(),
      ),
    ];
  }

  String? _validateModule({
    required String id,
    required String title,
    required int minStage,
    required int maxStage,
  }) {
    if (id.isEmpty) return 'Module ID is required.';
    if (title.trim().isEmpty) return 'Module title is required.';
    if (minStage < 1 || maxStage > 4 || minStage > maxStage) {
      return 'Choose a valid age-stage range.';
    }
    return null;
  }

  String? _validateLevel({
    required String id,
    required String moduleId,
    required int stage,
    required int levelNumber,
    required String title,
    required int passingScore,
  }) {
    if (id.isEmpty) return 'Level ID is required.';
    if (moduleId.isEmpty) return 'Choose a module first.';
    if (stage < 1 || stage > 4) return 'Stage must be between 1 and 4.';
    if (levelNumber < 1) return 'Level number must be at least 1.';
    if (title.trim().isEmpty) return 'Level title is required.';
    if (passingScore < 0 || passingScore > 100) {
      return 'Passing score must be between 0 and 100.';
    }
    return null;
  }

  void _setError(String message) {
    _errorMessage = message;
    _infoMessage = null;
    _isLoading = false;
    notifyListeners();
  }

  String _messageFor(Object error, {required String fallback}) {
    if (error is AdminPermissionException) return error.message;
    return fallback;
  }

  String _slug(String text) {
    return text
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
  }
}
