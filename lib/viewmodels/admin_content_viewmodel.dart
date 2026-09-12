import 'package:flutter/foundation.dart';

import '../core/utils/age_stage_helper.dart';
import '../data/seed_content.dart';
import '../models/admin_content.dart';
import '../models/content_item.dart';
import '../models/learning_level.dart';
import '../models/learning_module.dart';
import '../models/quiz_question.dart';
import '../models/video_lesson.dart';
import '../repositories/admin_authorization_repository.dart';
import '../repositories/admin_content_repository.dart';
import '../services/ai/content_draft_validator.dart';
import '../services/sync/content_sync_service.dart';

/// Where a module or level in the admin panel comes from.
enum ContentOrigin {
  /// Ships inside the app and has never been changed.
  builtIn,

  /// Ships inside the app, and an admin has saved a changed version of it.
  /// Children see the changed one once it is published.
  builtInEdited,

  /// Made by an admin. Exists only in the database.
  custom,
}

class AdminContentViewModel extends ChangeNotifier {
  AdminContentViewModel(
    this._adminContentRepository, {
    ContentSyncService? contentSyncService,
    List<LearningModule>? bundledModules,
    List<LearningLevel>? bundledLevels,
    ContentDraftValidator validator = const ContentDraftValidator(),
  })  : _contentSyncService = contentSyncService,
        _bundledModules = bundledModules ?? seedModules,
        _bundledLevels = bundledLevels ?? seedLevels,
        _validator = validator {
    // Built before anything loads, so the built-in curriculum is guarded
    // against from the first call rather than only after a refresh.
    _rebuildCatalog();
  }

  final AdminContentRepository _adminContentRepository;
  final ContentSyncService? _contentSyncService;
  final ContentDraftValidator _validator;

  /// The curriculum that ships in the app.
  ///
  /// The admin panel used to know only what was in the database, so to it the
  /// built-in English module did not exist. Creating a module with the ID
  /// "english" was therefore not a clash, and the child app then layered that
  /// module over the real English one — the "Phonics replaced English" report.
  /// Everything the panel checks and lists now includes these.
  final List<LearningModule> _bundledModules;
  final List<LearningLevel> _bundledLevels;

  List<AdminContentModule> _remoteModules = [];
  List<AdminContentLevel> _remoteLevels = [];
  List<AdminContentModule> _modules = [];
  List<AdminContentLevel> _levels = [];
  bool _isLoading = false;
  String? _errorMessage;
  String? _infoMessage;

  /// Every module an admin can work on: built-in ones, edited built-in ones,
  /// and custom ones, each appearing once.
  List<AdminContentModule> get modules => List.unmodifiable(_modules);

  /// Every level, on the same terms as [modules].
  List<AdminContentLevel> get levels => List.unmodifiable(_levels);

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get infoMessage => _infoMessage;

  static final _builtInDate = DateTime.utc(2026);

  ContentOrigin moduleOrigin(String moduleId) {
    final bundled = _bundledModules.where((m) => m.id == moduleId).firstOrNull;
    if (bundled == null) return ContentOrigin.custom;
    final remote =
        _remoteModules.where((m) => m.module.id == moduleId).firstOrNull;
    // Restoring a module writes the original values back, so a remote copy
    // identical to the bundled one is not an edit.
    if (remote == null || _sameModule(remote.module, bundled)) {
      return ContentOrigin.builtIn;
    }
    return ContentOrigin.builtInEdited;
  }

  ContentOrigin levelOrigin(String levelId) {
    if (!_bundledLevels.any((l) => l.id == levelId)) {
      return ContentOrigin.custom;
    }
    return _remoteLevels.any((l) => l.level.id == levelId)
        ? ContentOrigin.builtInEdited
        : ContentOrigin.builtIn;
  }

  AdminContentModule? moduleById(String moduleId) =>
      _modules.where((m) => m.module.id == moduleId).firstOrNull;

  AdminContentLevel? levelById(String levelId) =>
      _levels.where((l) => l.level.id == levelId).firstOrNull;

  /// The number a new level in [moduleId] at [stage] should take, so the
  /// ladder continues rather than colliding with a level that exists.
  int nextLevelNumber(String moduleId, int stage) {
    final numbers = [
      for (final level in _levels)
        if (level.level.moduleId == moduleId && level.level.stage == stage)
          level.level.levelNumber,
    ];
    if (numbers.isEmpty) return 1;
    return numbers.reduce((a, b) => a > b ? a : b) + 1;
  }

  Future<void> loadContent() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _remoteModules = await _adminContentRepository.getModules();
      _remoteLevels = await _adminContentRepository.getLevels();
    } catch (error) {
      _errorMessage = _messageFor(
        error,
        fallback: 'Admin content could not load.',
      );
    }
    _rebuildCatalog();

    _isLoading = false;
    notifyListeners();
  }

  void _rebuildCatalog() {
    final modules = <String, AdminContentModule>{
      for (final module in _bundledModules) module.id: _builtInModule(module),
    };
    for (final module in _remoteModules) {
      modules[module.module.id] = module;
    }
    _modules = modules.values.toList();

    final levels = <String, AdminContentLevel>{
      for (final level in _bundledLevels) level.id: _builtInLevel(level),
    };
    for (final level in _remoteLevels) {
      levels[level.level.id] = level;
    }
    _levels = levels.values.toList()
      ..sort((a, b) {
        final byModule = a.level.moduleId.compareTo(b.level.moduleId);
        if (byModule != 0) return byModule;
        final byStage = a.level.stage.compareTo(b.level.stage);
        if (byStage != 0) return byStage;
        return a.level.levelNumber.compareTo(b.level.levelNumber);
      });
  }

  AdminContentModule _builtInModule(LearningModule module) =>
      AdminContentModule(
        module: module,
        isPublished: true,
        createdAt: _builtInDate,
        updatedAt: _builtInDate,
        publishStatus: AdminPublishStatus.published,
      );

  AdminContentLevel _builtInLevel(LearningLevel level) => AdminContentLevel(
        level: level,
        isPublished: true,
        createdAt: _builtInDate,
        updatedAt: _builtInDate,
        publishStatus: AdminPublishStatus.published,
      );

  // ---------------------------------------------------------------- modules

  /// Adds a new module. Never replaces one — see [updateModule] for that.
  Future<bool> createModule({
    required String id,
    required String title,
    required String description,
    required ModuleCategory category,
    required int minStage,
    required int maxStage,
    required int order,
    required bool isPublished,
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

    // Saving is an upsert keyed on the id, so a create that reuses an id is
    // an overwrite in disguise. Creating therefore refuses every id that is
    // taken, including the built-in ones; changing an existing module is what
    // Edit is for, and Edit cannot pick the wrong module by accident.
    final existing = moduleById(moduleId);
    if (existing != null) {
      _setError(
        moduleOrigin(moduleId) == ContentOrigin.custom
            ? 'A module with the ID "$moduleId" already exists. Open it and '
                'press Edit to change it, or give this one a different ID.'
            : '"$moduleId" is the built-in ${existing.module.title} module. '
                'To change it, open it and press Edit. To add a new module '
                'alongside it, give this one its own ID, such as "phonics".',
      );
      return false;
    }

    final now = DateTime.now();
    return _saveModule(
      AdminContentModule(
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
        publishStatus: isPublished
            ? AdminPublishStatus.published
            : AdminPublishStatus.draft,
        publishedAt: isPublished ? now : null,
      ),
      'Module saved.',
    );
  }

  /// Saves changes to a module that exists, built-in or custom. Its ID never
  /// changes, because every level and every child's progress points at it.
  Future<bool> updateModule(
    AdminContentModule existing, {
    required String title,
    required String description,
    required ModuleCategory category,
    required int minStage,
    required int maxStage,
    required int order,
    required bool isPublished,
  }) async {
    final moduleId = existing.module.id;
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
    if (isPublished && levelCountForModule(moduleId) == 0) {
      _setError('Add at least one level to "${title.trim()}" before '
          'publishing.');
      return false;
    }

    final now = DateTime.now();
    final edited = LearningModule(
      id: moduleId,
      title: title.trim(),
      description: description.trim(),
      category: category,
      minStage: minStage,
      maxStage: maxStage,
      order: order,
    );
    return _saveModule(
      existing.copyWith(
        module: edited,
        isPublished: isPublished,
        publishStatus: isPublished
            ? AdminPublishStatus.published
            : AdminPublishStatus.draft,
        version: existing.version + 1,
        updatedAt: now,
        publishedAt: isPublished ? now : existing.publishedAt,
      ),
      'Module updated.',
    );
  }

  /// Puts a built-in module back to how it ships.
  ///
  /// Written as the original values rather than deleted, because deleting a
  /// module also deletes every level stored under it — which would take the
  /// admin's own new levels in that module with it.
  Future<bool> restoreBuiltInModule(String moduleId) {
    final bundled = _bundledModules.where((m) => m.id == moduleId).firstOrNull;
    if (bundled == null) {
      _setError('Only built-in modules can be restored.');
      return Future.value(false);
    }
    final now = DateTime.now();
    return _saveModule(
      AdminContentModule(
        module: bundled,
        isPublished: true,
        createdAt: now,
        updatedAt: now,
        publishStatus: AdminPublishStatus.published,
        publishedAt: now,
      ),
      '${bundled.title} is back to how it ships.',
    );
  }

  Future<bool> toggleModulePublished(
    AdminContentModule module,
    bool isPublished,
  ) {
    return isPublished ? publishModule(module) : moveModuleToDraft(module);
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

  Future<bool> moveModuleToDraft(AdminContentModule module) {
    if (moduleOrigin(module.module.id) == ContentOrigin.builtIn) {
      _setError('Built-in modules are always live. Edit it to change what '
          'children see.');
      return Future.value(false);
    }
    return _saveModule(
      module.copyWith(
        isPublished: false,
        publishStatus: AdminPublishStatus.draft,
        updatedAt: DateTime.now(),
      ),
      'Module moved to draft.',
    );
  }

  Future<bool> deleteModule(String moduleId) async {
    if (moduleOrigin(moduleId) != ContentOrigin.custom) {
      _setError('Built-in modules cannot be deleted. Use Restore to undo an '
          'edit.');
      return false;
    }
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

  // ----------------------------------------------------------------- levels

  /// Adds a new level. Never replaces one — see [updateLevel] for that.
  ///
  /// Takes every card and question the level has, not one of each: the form
  /// used to allow a single card, while the levels that ship have several.
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
    List<ContentItem> contentItems = const [],
    List<QuizQuestion> quizQuestions = const [],
    String videoTitle = '',
    String videoUrl = '',
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
    if (moduleById(moduleId) == null) {
      _setError('Module "$moduleId" does not exist. Create it first.');
      return false;
    }

    final existing = levelById(levelId);
    if (existing != null) {
      _setError(
        'A level with the ID "$levelId" already exists '
        '("${existing.level.title}"). Open it and press Edit to change it, '
        'or use level number ${nextLevelNumber(moduleId, stage)}.',
      );
      return false;
    }
    final ladderError = _ladderClash(
      moduleId: moduleId,
      stage: stage,
      levelNumber: levelNumber,
    );
    if (ladderError != null) {
      _setError(ladderError);
      return false;
    }

    final level = LearningLevel(
      id: levelId,
      moduleId: moduleId,
      stage: stage,
      levelNumber: levelNumber,
      title: title.trim(),
      subtitle: subtitle.trim(),
      type: type,
      passingScore: passingScore,
      isBundled: false,
      contentItems: _cleanItems(contentItems),
      quizQuestions: _cleanQuestions(levelId, quizQuestions),
      videoLessons: _videoLessons(
        levelId: levelId,
        title: videoTitle,
        videoUrl: videoUrl,
      ),
    );
    final contentError = _contentProblem(level);
    if (contentError != null) {
      _setError(contentError);
      return false;
    }

    final now = DateTime.now();
    return _saveLevel(
      AdminContentLevel(
        level: level,
        isPublished: isPublished,
        createdAt: now,
        updatedAt: now,
        publishStatus: isPublished
            ? AdminPublishStatus.published
            : AdminPublishStatus.draft,
        publishedAt: isPublished ? now : null,
      ),
      'Level saved.',
    );
  }

  /// Saves changes to a level that exists, built-in or custom.
  ///
  /// Editing a built-in level stores a changed copy under the same ID. Once
  /// it is published it takes the original's place on children's devices,
  /// and [restoreBuiltInLevel] removes the copy again.
  Future<bool> updateLevel(
    AdminContentLevel existing, {
    required int stage,
    required int levelNumber,
    required String title,
    required String subtitle,
    required LevelType type,
    required int passingScore,
    required bool isPublished,
    List<ContentItem> contentItems = const [],
    List<QuizQuestion> quizQuestions = const [],
    String videoTitle = '',
    String videoUrl = '',
  }) async {
    final original = existing.level;
    final validationError = _validateLevel(
      id: original.id,
      moduleId: original.moduleId,
      stage: stage,
      levelNumber: levelNumber,
      title: title,
      passingScore: passingScore,
    );
    if (validationError != null) {
      _setError(validationError);
      return false;
    }
    final ladderError = _ladderClash(
      moduleId: original.moduleId,
      stage: stage,
      levelNumber: levelNumber,
      ignoringId: original.id,
    );
    if (ladderError != null) {
      _setError(ladderError);
      return false;
    }

    final level = original.copyWith(
      stage: stage,
      levelNumber: levelNumber,
      title: title.trim(),
      subtitle: subtitle.trim(),
      type: type,
      passingScore: passingScore,
      contentItems: _cleanItems(contentItems),
      quizQuestions: _cleanQuestions(
        original.id,
        quizQuestions,
        previousIds: [for (final q in original.quizQuestions) q.id],
      ),
      videoLessons: type == LevelType.video && videoUrl.trim().isEmpty
          ? original.videoLessons
          : _videoLessons(
              levelId: original.id,
              title: videoTitle,
              videoUrl: videoUrl,
            ),
    );
    final contentError = _contentProblem(level);
    if (contentError != null) {
      _setError(contentError);
      return false;
    }

    return _saveLevel(
      _edited(existing, level, isPublished: isPublished),
      isPublished ? 'Level updated and live.' : 'Level updated as a draft.',
    );
  }

  /// Saves a level the AI rewrote, over the level it was rewritten from.
  ///
  /// The draft was already checked by the generator, so it is not put
  /// through the hand-edit checks a second time.
  Future<bool> saveRevisedLevel(
    LearningLevel revised, {
    required bool publish,
  }) async {
    final existing = levelById(revised.id);
    if (existing == null) {
      _setError('The level being rewritten no longer exists.');
      return false;
    }
    return _saveLevel(
      _edited(
        existing,
        revised.copyWith(isBundled: existing.level.isBundled),
        isPublished: publish,
      ),
      publish
          ? 'Rewritten level saved and live.'
          : 'Rewritten level saved as a draft. Publish it to replace the '
              'live version.',
    );
  }

  AdminContentLevel _edited(
    AdminContentLevel existing,
    LearningLevel level, {
    required bool isPublished,
  }) {
    final now = DateTime.now();
    return existing.copyWith(
      level: level,
      isPublished: isPublished,
      publishStatus:
          isPublished ? AdminPublishStatus.published : AdminPublishStatus.draft,
      version: existing.version + 1,
      updatedAt: now,
      publishedAt: isPublished ? now : existing.publishedAt,
    );
  }

  /// Removes an admin's edit of a built-in level, so the original shows again.
  Future<bool> restoreBuiltInLevel(String levelId) async {
    if (levelOrigin(levelId) != ContentOrigin.builtInEdited) {
      _setError('That level has no edit to undo.');
      return false;
    }
    try {
      await _adminContentRepository.deleteLevel(levelId);
      await _syncPublishedContent();
      _infoMessage = 'Level is back to how it ships.';
      await loadContent();
      return true;
    } catch (error) {
      _setError(_messageFor(error, fallback: 'Level could not be restored.'));
      return false;
    }
  }

  Future<bool> toggleLevelPublished(
    AdminContentLevel level,
    bool isPublished,
  ) {
    return isPublished ? publishLevel(level) : moveLevelToDraft(level);
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

  Future<bool> moveLevelToDraft(AdminContentLevel level) {
    if (levelOrigin(level.level.id) == ContentOrigin.builtIn) {
      _setError('Built-in levels are always live. Edit it to change what '
          'children see.');
      return Future.value(false);
    }
    return _saveLevel(
      level.copyWith(
        isPublished: false,
        publishStatus: AdminPublishStatus.draft,
        updatedAt: DateTime.now(),
      ),
      'Level moved to draft.',
    );
  }

  Future<bool> deleteLevel(String levelId) async {
    if (levelOrigin(levelId) != ContentOrigin.custom) {
      _setError('Built-in levels cannot be deleted. Use Restore to undo an '
          'edit.');
      return false;
    }
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

  // ---------------------------------------------------------------- helpers

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

  /// Two levels with the same number in one stage are not a ladder: unlocking
  /// walks level numbers, so the child would meet whichever sorted first and
  /// the other would sit behind it or beside it unpredictably.
  String? _ladderClash({
    required String moduleId,
    required int stage,
    required int levelNumber,
    String? ignoringId,
  }) {
    final clash = _levels.where((l) =>
        l.level.id != ignoringId &&
        l.level.moduleId == moduleId &&
        l.level.stage == stage &&
        l.level.levelNumber == levelNumber);
    if (clash.isEmpty) return null;
    return 'Stage $stage already has a level $levelNumber '
        '("${clash.first.level.title}"). Use level number '
        '${nextLevelNumber(moduleId, stage)}, or edit that level instead.';
  }

  /// Drops cards nobody filled in, and falls a missing picture description
  /// back to the card title — the one fix with a single right answer.
  List<ContentItem> _cleanItems(List<ContentItem> items) => [
        for (final item in items)
          if (!_blankItem(item))
            ContentItem(
              title: item.title.trim(),
              prompt: item.prompt.trim(),
              displayText: item.displayText.trim(),
              visualLabel: item.visualLabel.trim().isEmpty
                  ? item.title.trim()
                  : item.visualLabel.trim(),
              audioCueKey: item.audioCueKey,
              imageUrl: _blankToNull(item.imageUrl),
            ),
      ];

  bool _blankItem(ContentItem item) =>
      item.title.trim().isEmpty &&
      item.prompt.trim().isEmpty &&
      item.displayText.trim().isEmpty &&
      item.visualLabel.trim().isEmpty &&
      (item.imageUrl?.trim().isEmpty ?? true);

  /// Drops empty questions and empty answers, keeping the right answer
  /// pointing at the same words it pointed at before the blanks went.
  ///
  /// Keeps each question's existing id where it has one, since saved quiz
  /// answers point at it, and derives a fresh unique id for the rest.
  List<QuizQuestion> _cleanQuestions(
    String levelId,
    List<QuizQuestion> questions, {
    List<String> previousIds = const [],
  }) {
    final kept = [
      for (final question in questions)
        if (question.prompt.trim().isNotEmpty ||
            question.options.any((o) => o.trim().isNotEmpty))
          question,
    ];
    final used = <String>{};
    final cleaned = <QuizQuestion>[];
    for (var i = 0; i < kept.length; i++) {
      final question = kept[i];
      final options = <String>[];
      // -1 until the chosen answer turns out to be one that was filled in,
      // so a right answer left blank is reported rather than guessed.
      var correct = -1;
      for (var o = 0; o < question.options.length; o++) {
        final text = question.options[o].trim();
        if (text.isEmpty) continue;
        if (o == question.correctIndex) correct = options.length;
        options.add(text);
      }
      cleaned.add(QuizQuestion(
        id: _questionId(levelId, i, previousIds, used),
        prompt: question.prompt.trim(),
        options: options,
        correctIndex: correct,
        visualLabel: _blankToNull(question.visualLabel),
        explanation: _blankToNull(question.explanation),
        imageUrl: _blankToNull(question.imageUrl),
      ));
    }
    return cleaned;
  }

  String _questionId(
    String levelId,
    int index,
    List<String> previousIds,
    Set<String> used,
  ) {
    if (index < previousIds.length && used.add(previousIds[index])) {
      return previousIds[index];
    }
    var n = index + 1;
    while (!used.add('$levelId-q$n')) {
      n++;
    }
    return '$levelId-q$n';
  }

  /// Runs a hand-made level through the same checks as a generated one, so
  /// the form cannot save what would crash or mislead a child — a flashcard
  /// level with no cards, a counting card that is not a number, a correct
  /// answer that points at nothing.
  ///
  /// Two rules are relaxed for hand editing because they only protect polish,
  /// not the child: a blank subtitle, and a card field left blank.
  String? _contentProblem(LearningLevel level) {
    for (var i = 0; i < level.contentItems.length; i++) {
      if (level.contentItems[i].title.isEmpty) {
        return 'Card ${i + 1} needs a title.';
      }
    }
    final blocking = _validator
        .validateLevel(level, path: 'level')
        .blocking
        .where((issue) =>
            issue.rule != DraftRule.levelSubtitleEmpty &&
            issue.rule != DraftRule.contentFieldEmpty)
        .toList();
    if (blocking.isEmpty) return null;
    return _readable(blocking.first);
  }

  String _readable(DraftIssue issue) {
    final question = RegExp(r'quizQuestions\[(\d+)\]').firstMatch(issue.path);
    final card = RegExp(r'contentItems\[(\d+)\]').firstMatch(issue.path);
    final questionNumber =
        question == null ? null : int.parse(question.group(1)!) + 1;
    final cardNumber = card == null ? null : int.parse(card.group(1)!) + 1;

    switch (issue.rule) {
      case DraftRule.quizCorrectIndexOutOfRange:
        return 'Question $questionNumber: pick which answer is right.';
      case DraftRule.quizTooFewOptions:
        return 'Question $questionNumber needs at least two answers.';
      case DraftRule.contentItemsEmpty:
        return 'Add at least one card — this kind of level has nothing to '
            'show without one.';
      default:
        final where = cardNumber != null
            ? 'Card $cardNumber: '
            : questionNumber != null
                ? 'Question $questionNumber: '
                : '';
        return '$where${issue.message}';
    }
  }

  String? _blankToNull(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }

  bool _sameModule(LearningModule a, LearningModule b) =>
      a.title == b.title &&
      a.description == b.description &&
      a.category == b.category &&
      a.minStage == b.minStage &&
      a.maxStage == b.maxStage &&
      a.order == b.order;

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
    if (minStage < AgeStageHelper.minStage ||
        maxStage > 4 ||
        minStage > maxStage) {
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
    if (stage < AgeStageHelper.minStage || stage > 4) {
      return 'Stage must be between ${AgeStageHelper.minStage} and 4.';
    }
    if (levelNumber < 1) return 'Level number must be at least 1.';
    if (title.trim().isEmpty) return 'Level title is required.';
    if (passingScore < 0 || passingScore > 100) {
      return 'Passing score must be between 0 and 100.';
    }
    return null;
  }

  void clearMessages() {
    _errorMessage = null;
    _infoMessage = null;
    notifyListeners();
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
