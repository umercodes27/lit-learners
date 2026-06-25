import '../data/seed_content.dart';
import '../models/learning_level.dart';
import '../models/learning_module.dart';
import '../services/local/content_dao.dart';
import '../services/sync/content_sync_service.dart';

abstract class ContentRepository {
  Future<List<LearningModule>> getModulesForStage(int stage);
  Future<LearningModule?> getModuleById(String moduleId);
  Future<List<LearningLevel>> getLevelsForModule({
    required String moduleId,
    required int stage,
  });
  Future<LearningLevel?> getLevelById(String levelId);
  Future<void> markLevelDownloaded(String levelId);
}

class CachedContentRepository implements ContentRepository {
  CachedContentRepository({
    required ContentDao contentDao,
    ContentSyncService? contentSyncService,
    this.bundledModules = seedModules,
    this.bundledLevels = seedLevels,
  })  : _contentDao = contentDao,
        _contentSyncService = contentSyncService;

  final ContentDao _contentDao;
  final ContentSyncService? _contentSyncService;
  final List<LearningModule> bundledModules;
  final List<LearningLevel> bundledLevels;
  bool _didCheckSeed = false;
  bool _didCheckRemoteContent = false;

  @override
  Future<LearningModule?> getModuleById(String moduleId) async {
    await _ensureSeeded();
    return _contentDao.getModuleById(moduleId);
  }

  @override
  Future<List<LearningModule>> getModulesForStage(int stage) async {
    await _ensureSeeded();
    final allModules = await _contentDao.getModules();
    final modules = allModules.where((module) => module.supportsStage(stage));
    return modules.toList()..sort((a, b) => a.order.compareTo(b.order));
  }

  @override
  Future<List<LearningLevel>> getLevelsForModule({
    required String moduleId,
    required int stage,
  }) async {
    await _ensureSeeded();
    final moduleLevels = await _contentDao.getLevelsForModule(moduleId);
    return _levelsForStage(moduleLevels, stage);
  }

  @override
  Future<LearningLevel?> getLevelById(String levelId) async {
    await _ensureSeeded();
    return _contentDao.getLevelById(levelId);
  }

  @override
  Future<void> markLevelDownloaded(String levelId) async {
    await _ensureSeeded();
    await _contentDao.markLevelDownloaded(levelId);
  }

  Future<void> _ensureSeeded() async {
    if (_didCheckSeed) return;

    final hasModules = await _contentDao.hasModules();
    if (!hasModules) {
      await _contentDao.seedContent(
        modules: bundledModules,
        levels: bundledLevels,
      );
    }
    _didCheckSeed = true;
    await _syncRemoteContentIfAvailable();
  }

  Future<void> _syncRemoteContentIfAvailable() async {
    if (_didCheckRemoteContent) return;

    _didCheckRemoteContent = true;
    await _contentSyncService?.syncNow();
  }

  List<LearningLevel> _levelsForStage(
    List<LearningLevel> moduleLevels,
    int stage,
  ) {
    final exactStageLevels = moduleLevels.where((level) {
      return level.stage == stage;
    }).toList()
      ..sort((a, b) => a.levelNumber.compareTo(b.levelNumber));

    if (exactStageLevels.isNotEmpty) return exactStageLevels;

    final lowerStageLevels =
        moduleLevels.where((level) => level.stage <= stage).toList()
          ..sort((a, b) {
            final stageCompare = b.stage.compareTo(a.stage);
            if (stageCompare != 0) return stageCompare;
            return a.levelNumber.compareTo(b.levelNumber);
          });

    if (lowerStageLevels.isNotEmpty) {
      final fallbackStage = lowerStageLevels.first.stage;
      return lowerStageLevels
          .where((level) => level.stage == fallbackStage)
          .toList();
    }

    return moduleLevels.toList()
      ..sort((a, b) => a.levelNumber.compareTo(b.levelNumber));
  }
}

class SeedContentRepository extends CachedContentRepository {
  SeedContentRepository() : super(contentDao: InMemoryContentDao());
}
