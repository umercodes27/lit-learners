import 'package:flutter/foundation.dart';

import '../models/ai_level_draft.dart';
import '../core/utils/age_stage_helper.dart';
import '../models/learning_level.dart';
import '../models/learning_module.dart';
import '../services/ai/ai_content_generator.dart';
import '../services/ai/content_draft_validator.dart';
import '../services/ai/llm_client.dart';
import '../services/ai/llm_credential_store.dart';
import '../services/ai/llm_provider_profile.dart';

/// Drives the AI authoring screen: the key, the request form, the drafts and
/// the save.
///
/// Holds no reference to [AdminContentViewModel]. What it needs from the rest
/// of the admin panel — which modules exist, what a stage already contains,
/// which ids are taken — is passed in when generating, and saving is handed a
/// function rather than a repository. That keeps every branch here testable
/// with a plain list and a closure.
class AiContentViewModel extends ChangeNotifier {
  AiContentViewModel({
    required AiContentGenerator generator,
    required LlmCredentialStore credentialStore,
  })  : _generator = generator,
        _credentialStore = credentialStore;

  final AiContentGenerator _generator;
  final LlmCredentialStore _credentialStore;

  LlmCredentials _credentials = const LlmCredentials.unset();
  LlmCredentials get credentials => _credentials;
  bool get hasKey => _credentials.isConfigured;

  String? _moduleId;
  int _stage = AgeStageHelper.minStage;
  int _levelCount = 3;
  LevelType _type = LevelType.flashcards;
  String _guidance = '';

  String? get moduleId => _moduleId;
  int get stage => _stage;
  int get levelCount => _levelCount;
  LevelType get type => _type;
  String get guidance => _guidance;

  /// Ten is a deliberate ceiling. A larger batch costs more, takes longer,
  /// is likelier to be cut off mid-reply, and produces more review than
  /// anyone does carefully in one sitting.
  static const maxLevelCount = 10;

  bool _isGenerating = false;
  bool _isSaving = false;
  bool get isGenerating => _isGenerating;
  bool get isSaving => _isSaving;
  bool get isBusy => _isGenerating || _isSaving;

  List<AiLevelDraft> _drafts = [];
  List<DraftIssue> _batchIssues = [];
  int _attempts = 0;

  List<AiLevelDraft> get drafts => List.unmodifiable(_drafts);
  List<DraftIssue> get batchIssues => List.unmodifiable(_batchIssues);
  int get attempts => _attempts;

  String? _errorMessage;
  String? _infoMessage;
  String? get errorMessage => _errorMessage;
  String? get infoMessage => _infoMessage;

  /// What the request will produce, worked out before anything is generated,
  /// so the admin can see the numbering they are about to extend.
  int _firstLevelNumber = 1;
  int get firstLevelNumber => _firstLevelNumber;
  int get lastLevelNumber => _firstLevelNumber + _levelCount - 1;

  List<AiLevelDraft> get approvedDrafts =>
      [for (final draft in _drafts) if (draft.isApproved) draft];

  int get approvedCount => approvedDrafts.length;

  /// The level being rewritten, or null when generating new levels.
  LearningLevel? _revising;
  LearningLevel? get revising => _revising;

  /// Every module id the admin panel knows, so a draft for a custom module
  /// is not flagged as belonging to a module that does not exist.
  Set<String> _knownModuleIds = const {};

  /// Switches the screen to rewriting one existing level — built-in or not.
  ///
  /// Module, stage, type and number all come from the level and are not
  /// offered for change: the rewrite takes the original's place in the
  /// ladder, so moving it would open a gap.
  void startRevision(LearningLevel level) {
    _revising = level;
    _moduleId = level.moduleId;
    _stage = level.stage;
    _type = level.type;
    _levelCount = 1;
    _firstLevelNumber = level.levelNumber;
    _drafts = [];
    _batchIssues = [];
    _request = null;
    _errorMessage = null;
    _infoMessage = null;
    notifyListeners();
  }

  /// Back to generating new levels.
  void cancelRevision() {
    if (_revising == null) return;
    _revising = null;
    _levelCount = 3;
    _drafts = [];
    _batchIssues = [];
    _request = null;
    notifyListeners();
  }

  /// Saves the one approved rewrite over the level it came from.
  Future<bool> saveRevision(
    Future<bool> Function(LearningLevel level) save,
  ) async {
    final approved = approvedDrafts;
    if (_revising == null || approved.length != 1) {
      _setError('Approve the rewritten level before saving.');
      return false;
    }

    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    final saved = await save(approved.single.level);

    _isSaving = false;
    if (saved) {
      _drafts = [];
      _revising = null;
      _levelCount = 3;
      _infoMessage = 'Rewrite saved.';
    } else {
      _errorMessage = 'Nothing was saved. The rewrite is still here.';
    }
    notifyListeners();
    return saved;
  }


  Future<void> loadCredentials() async {
    _credentials = await _credentialStore.read();
    notifyListeners();
  }

  Future<bool> saveKey({
    required String apiKey,
    required LlmProviderProfile profile,
  }) async {
    try {
      final next = LlmCredentials(apiKey: apiKey.trim(), profile: profile);
      await _credentialStore.write(next);
      _credentials = next;
      _infoMessage = 'API key saved on this device.';
      _errorMessage = null;
      notifyListeners();
      return true;
    } on LlmCredentialException catch (error) {
      _setError(error.message);
      return false;
    }
  }

  Future<bool> forgetKey() async {
    try {
      await _credentialStore.clear();
      _credentials = const LlmCredentials.unset();
      _infoMessage = 'API key removed from this device.';
      _errorMessage = null;
      notifyListeners();
      return true;
    } on LlmCredentialException catch (error) {
      _setError(error.message);
      return false;
    }
  }

  void selectModule(String? moduleId, {List<LearningModule> modules = const []}) {
    _moduleId = moduleId;

    // Tracing does not start until stage 2, so a module's own range decides
    // what can be asked for rather than the form offering all four.
    final module = modules.where((m) => m.id == moduleId).firstOrNull;
    if (module != null) {
      _stage = _stage.clamp(module.minStage, module.maxStage);
    }
    notifyListeners();
  }

  void setStage(int stage) {
    _stage = stage;
    notifyListeners();
  }

  void setLevelCount(int count) {
    _levelCount = count.clamp(1, maxLevelCount);
    notifyListeners();
  }

  void setType(LevelType type) {
    _type = type;
    notifyListeners();
  }

  void setGuidance(String guidance) {
    _guidance = guidance;
  }

  List<int> stagesFor(List<LearningModule> modules) {
    final module = modules.where((m) => m.id == _moduleId).firstOrNull;
    if (module == null) {
      return [
        for (var stage = AgeStageHelper.minStage; stage <= 4; stage++) stage,
      ];
    }
    return [
      for (var stage = module.minStage; stage <= module.maxStage; stage++)
        stage,
    ];
  }

  /// Recomputes where this stage continues from, so the form can say what it
  /// is about to create before anyone spends money finding out.
  void refreshPreview(List<LearningLevel> existingLevels) {
    _firstLevelNumber =
        _revising?.levelNumber ?? _nextLevelNumber(existingLevels);
    notifyListeners();
  }

  int _nextLevelNumber(List<LearningLevel> existingLevels) {
    final inStage = _levelsInStage(existingLevels);
    if (inStage.isEmpty) return 1;
    return inStage
            .map((level) => level.levelNumber)
            .reduce((a, b) => a > b ? a : b) +
        1;
  }

  List<LearningLevel> _levelsInStage(List<LearningLevel> existingLevels) => [
        for (final level in existingLevels)
          if (level.moduleId == _moduleId && level.stage == _stage) level,
      ];

  Future<void> generate({
    required List<LearningModule> modules,
    required List<LearningLevel> existingLevels,
  }) async {
    final moduleId = _moduleId;
    if (moduleId == null) {
      _setError('Choose a module first.');
      return;
    }
    if (!hasKey) {
      _setError('Add an API key before generating.');
      return;
    }

    final module = modules.where((m) => m.id == moduleId).firstOrNull;
    if (module == null) {
      _setError('That module no longer exists. Reload and try again.');
      return;
    }

    _isGenerating = true;
    _errorMessage = null;
    _infoMessage = null;
    _drafts = [];
    _batchIssues = [];
    notifyListeners();

    final revising = _revising;
    // Measured against the rest of the app. The level being rewritten is left
    // out, or its own id, title and question ids would read as collisions
    // with itself.
    final others = [
      for (final level in existingLevels)
        if (level.id != revising?.id) level,
    ];
    final inStage = _levelsInStage(others);
    _firstLevelNumber = revising?.levelNumber ?? _nextLevelNumber(others);
    _knownModuleIds = {for (final m in modules) m.id};

    final request = AiGenerationRequest(
      moduleId: moduleId,
      moduleTitle: module.title,
      category: module.category,
      stage: _stage,
      levelCount: _levelCount,
      type: _type,
      firstLevelNumber: _firstLevelNumber,
      guidance: _guidance,
      revising: revising,
      existingTitles: [for (final level in inStage) level.title],
      existingPortions: [
        for (final level in inStage)
          if (level.portionLabel != null) level.portionLabel!,
      ],
    );

    _request = request;

    final result = await _generator.generateStage(
      request,
      // Checked against every level in the app, not just this stage: ids and
      // quiz ids are database keys and must be unique everywhere.
      existingLevelIds: {for (final level in others) level.id},
      existingQuizIds: {
        for (final level in others)
          for (final question in level.quizQuestions) question.id,
      },
      existingTitles: {for (final level in inStage) level.title},
      knownModuleIds: _knownModuleIds,
    );

    _isGenerating = false;
    _drafts = result.drafts;
    _batchIssues = result.batchIssues;
    _attempts = result.attempts;

    final failure = result.failure;
    if (failure != null) {
      _errorMessage = failure.message;
    } else if (result.isClean) {
      _infoMessage = 'Generated ${result.drafts.length} '
          '${result.drafts.length == 1 ? 'level' : 'levels'}'
          '${result.attempts > 1 ? ' after ${result.attempts} attempts' : ''}. '
          'Check each one before saving.';
    } else if (result.hasDrafts) {
      _errorMessage = 'Some levels still have problems. Fix them below, or '
          'generate again.';
    } else {
      _errorMessage = 'Nothing usable came back. Try again.';
    }
    notifyListeners();
  }

  AiGenerationRequest? _request;

  void toggleApproved(int index, bool approved) {
    if (index < 0 || index >= _drafts.length) return;
    // copyWith refuses approval on a blocked draft, so a broken level cannot
    // be approved even by a caller that tries.
    _drafts[index] = _drafts[index].copyWith(isApproved: approved);
    notifyListeners();
  }

  /// Applies an admin's hand edit and re-checks the whole batch.
  void updateDraft(int index, LearningLevel level) {
    if (index < 0 || index >= _drafts.length) return;
    final request = _request;
    if (request == null) return;

    final edited = [..._drafts];
    edited[index] = edited[index].copyWith(level: level);

    final result = _generator.revalidate(
      edited,
      request: request,
      knownModuleIds: _knownModuleIds,
    );
    _drafts = result.drafts;
    _batchIssues = result.batchIssues;
    notifyListeners();
  }

  /// Null when the approved drafts can be saved, or the reason they cannot.
  ///
  /// Atomicity protects against a connection dropping mid-save, but it does
  /// nothing about approving levels 1, 2 and 4: that commits a ladder with a
  /// hole in it just as surely, and a hole locks every level after it. So the
  /// approved set must be an unbroken run from where the stage continues.
  String? get approvalProblem {
    final approved = approvedDrafts;
    if (approved.isEmpty) return 'Approve at least one level before saving.';

    final numbers = [for (final draft in approved) draft.level.levelNumber]
      ..sort();
    for (var i = 0; i < numbers.length; i++) {
      if (numbers[i] != _firstLevelNumber + i) {
        return 'Levels have to be saved as an unbroken run starting at '
            '$_firstLevelNumber. Saving ${numbers.join(', ')} would leave a '
            'gap, and a gap locks every level after it.';
      }
    }
    return null;
  }

  bool get canSave => approvalProblem == null && !isBusy;

  /// Hands the approved levels to one all-or-nothing write.
  ///
  /// Because that write is atomic there is no partial outcome to report: on
  /// success every approved draft is gone, and on failure every one is still
  /// here to retry.
  Future<bool> saveApproved(
    Future<bool> Function(List<LearningLevel> levels) save,
  ) async {
    final problem = approvalProblem;
    if (problem != null) {
      _setError(problem);
      return false;
    }

    _isSaving = true;
    _errorMessage = null;
    _infoMessage = null;
    notifyListeners();

    final levels = [for (final draft in approvedDrafts) draft.level]
      ..sort((a, b) => a.levelNumber.compareTo(b.levelNumber));

    final saved = await save(levels);

    _isSaving = false;
    if (saved) {
      _drafts = [for (final draft in _drafts) if (!draft.isApproved) draft];
      _infoMessage = 'Saved ${levels.length} '
          '${levels.length == 1 ? 'level' : 'levels'} as '
          '${levels.length == 1 ? 'a draft' : 'drafts'}.';
      _firstLevelNumber += levels.length;
    } else {
      _errorMessage = 'Nothing was saved. The levels are all still here.';
    }
    notifyListeners();
    return saved;
  }

  void clearMessages() {
    _errorMessage = null;
    _infoMessage = null;
    notifyListeners();
  }

  void _setError(String message) {
    _errorMessage = message;
    _infoMessage = null;
    _isGenerating = false;
    _isSaving = false;
    notifyListeners();
  }
}
