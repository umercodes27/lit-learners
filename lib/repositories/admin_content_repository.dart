import '../models/admin_content.dart';
import '../models/learning_level.dart';
import '../models/learning_module.dart';
import '../services/remote/content_remote_data_source.dart';

abstract class AdminContentRepository {
  Future<List<AdminContentModule>> getModules();

  Future<List<AdminContentLevel>> getLevels({String? moduleId});

  Future<AdminContentModule> upsertModule(AdminContentModule module);

  Future<AdminContentLevel> upsertLevel(AdminContentLevel level);

  Future<void> deleteModule(String moduleId);

  Future<void> deleteLevel(String levelId);
}

class InMemoryAdminContentRepository implements AdminContentRepository {
  InMemoryAdminContentRepository({
    required InMemoryContentRemoteDataSource contentRemoteDataSource,
  }) : _contentRemoteDataSource = contentRemoteDataSource;

  final InMemoryContentRemoteDataSource _contentRemoteDataSource;
  final Map<String, DateTime> _moduleCreatedAt = {};
  final Map<String, DateTime> _moduleUpdatedAt = {};
  final Map<String, AdminPublishStatus> _modulePublishStatus = {};
  final Map<String, int> _moduleVersion = {};
  final Map<String, DateTime?> _moduleSubmittedAt = {};
  final Map<String, DateTime?> _modulePublishedAt = {};
  final Map<String, DateTime> _levelCreatedAt = {};
  final Map<String, DateTime> _levelUpdatedAt = {};
  final Map<String, AdminPublishStatus> _levelPublishStatus = {};
  final Map<String, int> _levelVersion = {};
  final Map<String, DateTime?> _levelSubmittedAt = {};
  final Map<String, DateTime?> _levelPublishedAt = {};

  @override
  Future<void> deleteLevel(String levelId) async {
    _contentRemoteDataSource.deleteLevel(levelId);
    _levelCreatedAt.remove(levelId);
    _levelUpdatedAt.remove(levelId);
    _levelPublishStatus.remove(levelId);
    _levelVersion.remove(levelId);
    _levelSubmittedAt.remove(levelId);
    _levelPublishedAt.remove(levelId);
  }

  @override
  Future<void> deleteModule(String moduleId) async {
    final levels = _contentRemoteDataSource.getAllLevels(moduleId: moduleId);
    _contentRemoteDataSource.deleteModule(moduleId);
    _moduleCreatedAt.remove(moduleId);
    _moduleUpdatedAt.remove(moduleId);
    _modulePublishStatus.remove(moduleId);
    _moduleVersion.remove(moduleId);
    _moduleSubmittedAt.remove(moduleId);
    _modulePublishedAt.remove(moduleId);
    for (final level in levels) {
      _levelCreatedAt.remove(level.id);
      _levelUpdatedAt.remove(level.id);
      _levelPublishStatus.remove(level.id);
      _levelVersion.remove(level.id);
      _levelSubmittedAt.remove(level.id);
      _levelPublishedAt.remove(level.id);
    }
  }

  @override
  Future<List<AdminContentLevel>> getLevels({String? moduleId}) async {
    final levels = _contentRemoteDataSource.getAllLevels(moduleId: moduleId);
    return levels.map(_adminLevelFor).toList();
  }

  @override
  Future<List<AdminContentModule>> getModules() async {
    return _contentRemoteDataSource
        .getAllModules()
        .map(_adminModuleFor)
        .toList();
  }

  @override
  Future<AdminContentLevel> upsertLevel(AdminContentLevel level) async {
    final now = DateTime.now();
    final createdAt = _levelCreatedAt[level.level.id] ?? level.createdAt;
    _levelCreatedAt[level.level.id] = createdAt;
    _levelUpdatedAt[level.level.id] = now;
    _levelPublishStatus[level.level.id] = level.publishStatus;
    _levelVersion[level.level.id] = level.version;
    _levelSubmittedAt[level.level.id] = level.submittedAt;
    _levelPublishedAt[level.level.id] = level.publishedAt;
    _contentRemoteDataSource.upsertLevel(
      level: level.level,
      isPublished: level.isPublished,
    );
    return level.copyWith(updatedAt: now);
  }

  @override
  Future<AdminContentModule> upsertModule(AdminContentModule module) async {
    final now = DateTime.now();
    final createdAt = _moduleCreatedAt[module.module.id] ?? module.createdAt;
    _moduleCreatedAt[module.module.id] = createdAt;
    _moduleUpdatedAt[module.module.id] = now;
    _modulePublishStatus[module.module.id] = module.publishStatus;
    _moduleVersion[module.module.id] = module.version;
    _moduleSubmittedAt[module.module.id] = module.submittedAt;
    _modulePublishedAt[module.module.id] = module.publishedAt;
    _contentRemoteDataSource.upsertModule(
      module: module.module,
      isPublished: module.isPublished,
    );
    return module.copyWith(updatedAt: now);
  }

  AdminContentModule _adminModuleFor(LearningModule module) {
    final now = DateTime.now();
    return AdminContentModule(
      module: module,
      isPublished: _contentRemoteDataSource.isModulePublished(module.id),
      createdAt: _moduleCreatedAt[module.id] ?? now,
      updatedAt: _moduleUpdatedAt[module.id] ?? now,
      publishStatus: _modulePublishStatus[module.id] ??
          (_contentRemoteDataSource.isModulePublished(module.id)
              ? AdminPublishStatus.published
              : AdminPublishStatus.draft),
      version: _moduleVersion[module.id] ?? 1,
      submittedAt: _moduleSubmittedAt[module.id],
      publishedAt: _modulePublishedAt[module.id],
    );
  }

  AdminContentLevel _adminLevelFor(LearningLevel level) {
    final now = DateTime.now();
    return AdminContentLevel(
      level: level,
      isPublished: _contentRemoteDataSource.isLevelPublished(level.id),
      createdAt: _levelCreatedAt[level.id] ?? now,
      updatedAt: _levelUpdatedAt[level.id] ?? now,
      publishStatus: _levelPublishStatus[level.id] ??
          (_contentRemoteDataSource.isLevelPublished(level.id)
              ? AdminPublishStatus.published
              : AdminPublishStatus.draft),
      version: _levelVersion[level.id] ?? 1,
      submittedAt: _levelSubmittedAt[level.id],
      publishedAt: _levelPublishedAt[level.id],
    );
  }
}
