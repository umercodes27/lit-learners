import 'package:flutter/foundation.dart';

import '../core/utils/age_stage_helper.dart';
import '../models/child_profile.dart';
import '../models/learning_level.dart';
import '../models/learning_module.dart';
import '../models/progress.dart';
import '../repositories/content_repository.dart';
import '../repositories/progress_repository.dart';
import '../services/sync/progress_sync_service.dart';

class LearningViewModel extends ChangeNotifier {
  LearningViewModel({
    required ContentRepository contentRepository,
    required ProgressRepository progressRepository,
    ProgressSyncService? progressSyncService,
  })  : _contentRepository = contentRepository,
        _progressRepository = progressRepository,
        _progressSyncService = progressSyncService;

  final ContentRepository _contentRepository;
  final ProgressRepository _progressRepository;
  final ProgressSyncService? _progressSyncService;

  final Map<String, List<LearningLevel>> _levelsByModule = {};
  final Map<String, LearningModule> _modulesById = {};
  List<LearningModule> _modules = [];
  List<LevelProgress> _progress = [];
  String? _activeChildId;
  int? _activeStage;
  bool _isLoading = false;

  List<LearningModule> get modules => List.unmodifiable(_modules);
  bool get isLoading => _isLoading;

  Future<void> loadForProfile(ChildProfile profile) async {
    _isLoading = true;
    notifyListeners();

    _activeChildId = profile.id;
    _activeStage = AgeStageHelper.stageForAge(profile.age);
    _modules = await _contentRepository.getModulesForStage(_activeStage!);
    _modulesById
      ..clear()
      ..addEntries(_modules.map((module) => MapEntry(module.id, module)));
    await _progressSyncService?.syncNow(childId: profile.id);
    _progress = await _progressRepository.getProgressForChild(profile.id);
    _levelsByModule.clear();

    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadLevelsForModule(String moduleId) async {
    final stage = _activeStage;
    if (stage == null) return;
    if (_levelsByModule.containsKey(moduleId)) return;

    _levelsByModule[moduleId] = await _contentRepository.getLevelsForModule(
      moduleId: moduleId,
      stage: stage,
    );
    notifyListeners();
  }

  LearningModule? moduleById(String moduleId) => _modulesById[moduleId];

  List<LearningLevel> levelsFor(String moduleId) {
    return List.unmodifiable(_levelsByModule[moduleId] ?? const []);
  }

  Future<LearningLevel?> levelById(String levelId) {
    return _contentRepository.getLevelById(levelId);
  }

  bool isLevelCompleted(String levelId) {
    return _progress.any((progress) {
      return progress.levelId == levelId && progress.completed;
    });
  }

  int starsFor(String levelId) {
    final match = _progress.where((progress) => progress.levelId == levelId);
    return match.isEmpty ? 0 : match.first.starsEarned;
  }

  bool isLevelUnlocked(LearningLevel level) {
    if (level.levelNumber == 1) return true;

    final previousLevel = levelsFor(level.moduleId).where((candidate) {
      return candidate.levelNumber == level.levelNumber - 1;
    });

    if (previousLevel.isEmpty) return false;
    return isLevelCompleted(previousLevel.first.id);
  }

  bool canOpenLevel(LearningLevel level) {
    return isLevelUnlocked(level) && level.isAvailableOffline;
  }

  bool canDownloadLevel(LearningLevel level) {
    return isLevelUnlocked(level) && !level.isAvailableOffline;
  }

  String lockReasonFor(LearningLevel level) {
    if (!isLevelUnlocked(level)) {
      return 'Finish the previous level first.';
    }
    if (!level.isAvailableOffline) {
      return 'Download this level before playing.';
    }
    return '';
  }

  Future<void> downloadLevel(LearningLevel level) async {
    await _contentRepository.markLevelDownloaded(level.id);
    final stage = _activeStage;
    if (stage == null) return;

    _levelsByModule[level.moduleId] =
        await _contentRepository.getLevelsForModule(
      moduleId: level.moduleId,
      stage: stage,
    );
    notifyListeners();
  }

  Future<LevelProgress> completeLevel(
    String childId,
    LearningLevel level, {
    int? score,
  }) async {
    final progress = await _progressRepository.completeLevel(
      childId: childId,
      level: level,
      score: score,
    );
    await _progressSyncService?.syncNow(childId: childId);
    _progress = await _progressRepository.getProgressForChild(childId);
    notifyListeners();
    return progress;
  }

  Future<LevelProgress> recordVideoWatched({
    required String childId,
    required LearningLevel level,
    required String lessonId,
  }) async {
    final progress = await _progressRepository.recordVideoWatched(
      childId: childId,
      level: level,
      lessonId: lessonId,
    );
    await _progressSyncService?.syncNow(childId: childId);
    _progress = await _progressRepository.getProgressForChild(childId);
    notifyListeners();
    return progress;
  }

  bool get hasActiveProfile => _activeChildId != null && _activeStage != null;
}
