import '../../models/learning_level.dart';
import '../../models/learning_module.dart';

class ContentBundle {
  const ContentBundle({
    required this.modules,
    required this.levels,
  });

  final List<LearningModule> modules;
  final List<LearningLevel> levels;

  bool get isEmpty => modules.isEmpty && levels.isEmpty;
}

abstract class ContentRemoteDataSource {
  Future<ContentBundle> getPublishedContent();
}

class InMemoryContentRemoteDataSource implements ContentRemoteDataSource {
  InMemoryContentRemoteDataSource({
    List<LearningModule> modules = const [],
    List<LearningLevel> levels = const [],
  }) {
    for (final module in modules) {
      upsertModule(module: module, isPublished: true);
    }
    for (final level in levels) {
      upsertLevel(level: level, isPublished: true);
    }
  }

  final Map<String, LearningModule> _modulesById = {};
  final Map<String, LearningLevel> _levelsById = {};
  final Set<String> _publishedModuleIds = {};
  final Set<String> _publishedLevelIds = {};

  @override
  Future<ContentBundle> getPublishedContent() async {
    final modules = _modulesById.values
        .where((module) => _publishedModuleIds.contains(module.id))
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    final moduleIds = modules.map((module) => module.id).toSet();
    final levels = _levelsById.values
        .where((level) =>
            _publishedLevelIds.contains(level.id) &&
            moduleIds.contains(level.moduleId))
        .toList()
      ..sort(_sortLevels);

    return ContentBundle(modules: modules, levels: levels);
  }

  List<LearningModule> getAllModules() {
    return _modulesById.values.toList()
      ..sort((a, b) => a.order.compareTo(b.order));
  }

  List<LearningLevel> getAllLevels({String? moduleId}) {
    return _levelsById.values
        .where((level) => moduleId == null || level.moduleId == moduleId)
        .toList()
      ..sort(_sortLevels);
  }

  bool isModulePublished(String moduleId) {
    return _publishedModuleIds.contains(moduleId);
  }

  bool isLevelPublished(String levelId) {
    return _publishedLevelIds.contains(levelId);
  }

  void upsertModule({
    required LearningModule module,
    required bool isPublished,
  }) {
    _modulesById[module.id] = module;
    if (isPublished) {
      _publishedModuleIds.add(module.id);
    } else {
      _publishedModuleIds.remove(module.id);
    }
  }

  void upsertLevel({
    required LearningLevel level,
    required bool isPublished,
  }) {
    _levelsById[level.id] = level;
    if (isPublished) {
      _publishedLevelIds.add(level.id);
    } else {
      _publishedLevelIds.remove(level.id);
    }
  }

  void deleteModule(String moduleId) {
    _modulesById.remove(moduleId);
    _publishedModuleIds.remove(moduleId);
    final levelIds = _levelsById.values
        .where((level) => level.moduleId == moduleId)
        .map((level) => level.id)
        .toList();
    for (final levelId in levelIds) {
      deleteLevel(levelId);
    }
  }

  void deleteLevel(String levelId) {
    _levelsById.remove(levelId);
    _publishedLevelIds.remove(levelId);
  }
}

int _sortLevels(LearningLevel a, LearningLevel b) {
  final moduleCompare = a.moduleId.compareTo(b.moduleId);
  if (moduleCompare != 0) return moduleCompare;

  final stageCompare = a.stage.compareTo(b.stage);
  if (stageCompare != 0) return stageCompare;

  return a.levelNumber.compareTo(b.levelNumber);
}
