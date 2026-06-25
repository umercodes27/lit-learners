import 'package:sqflite/sqflite.dart';

import '../../models/learning_level.dart';
import '../../models/learning_module.dart';
import 'content_mapper.dart';
import 'db_helper.dart';
import 'db_schema.dart';

abstract class ContentDao {
  Future<bool> hasModules();
  Future<void> seedContent({
    required List<LearningModule> modules,
    required List<LearningLevel> levels,
  });
  Future<void> replaceContent({
    required List<LearningModule> modules,
    required List<LearningLevel> levels,
  });
  Future<List<LearningModule>> getModules();
  Future<LearningModule?> getModuleById(String moduleId);
  Future<List<LearningLevel>> getLevelsForModule(String moduleId);
  Future<LearningLevel?> getLevelById(String levelId);
  Future<void> markLevelDownloaded(String levelId);
}

class SqfliteContentDao implements ContentDao {
  SqfliteContentDao(this._dbHelper);

  final LocalDbHelper _dbHelper;

  @override
  Future<List<LearningLevel>> getLevelsForModule(String moduleId) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      LocalDbSchema.levels,
      where: 'moduleId = ?',
      whereArgs: [moduleId],
      orderBy: 'stage ASC, levelNumber ASC',
    );
    final levels = <LearningLevel>[];
    for (final row in rows) {
      levels.add(await _levelFromRow(db, row));
    }
    return levels;
  }

  @override
  Future<LearningLevel?> getLevelById(String levelId) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      LocalDbSchema.levels,
      where: 'levelId = ?',
      whereArgs: [levelId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _levelFromRow(db, rows.first);
  }

  @override
  Future<LearningModule?> getModuleById(String moduleId) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      LocalDbSchema.modules,
      where: 'moduleId = ?',
      whereArgs: [moduleId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return ContentMapper.moduleFromLocalMap(rows.first);
  }

  @override
  Future<void> markLevelDownloaded(String levelId) async {
    final db = await _dbHelper.database;
    await db.update(
      LocalDbSchema.levels,
      {'isDownloaded': 1},
      where: 'levelId = ?',
      whereArgs: [levelId],
    );
  }

  @override
  Future<List<LearningModule>> getModules() async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      LocalDbSchema.modules,
      orderBy: 'sortOrder ASC',
    );
    return rows.map(ContentMapper.moduleFromLocalMap).toList();
  }

  @override
  Future<bool> hasModules() async {
    final db = await _dbHelper.database;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS count FROM ${LocalDbSchema.modules}',
    );
    return (rows.first['count']! as int) > 0;
  }

  @override
  Future<void> seedContent({
    required List<LearningModule> modules,
    required List<LearningLevel> levels,
  }) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      await _insertContent(
        txn: txn,
        modules: modules,
        levels: levels,
        downloadedLevelIds: const {},
      );
    });
  }

  @override
  Future<void> replaceContent({
    required List<LearningModule> modules,
    required List<LearningLevel> levels,
  }) async {
    final db = await _dbHelper.database;
    final existingLevels = await getLevelsForContentReplacement(db);
    final downloadedLevelIds = existingLevels
        .where((level) => level.isDownloaded)
        .map((level) => level.id)
        .toSet();

    await db.transaction((txn) async {
      await txn.delete(LocalDbSchema.contentItems);
      await txn.delete(LocalDbSchema.quizQuestions);
      await txn.delete(LocalDbSchema.videoLessons);
      await txn.delete(LocalDbSchema.levels);
      await txn.delete(LocalDbSchema.modules);

      await _insertContent(
        txn: txn,
        modules: modules,
        levels: levels,
        downloadedLevelIds: downloadedLevelIds,
      );
    });
  }

  Future<List<LearningLevel>> getLevelsForContentReplacement(
    DatabaseExecutor db,
  ) async {
    final rows = await db.query(LocalDbSchema.levels);
    final levels = <LearningLevel>[];
    for (final row in rows) {
      levels.add(await _levelFromRow(db, row));
    }
    return levels;
  }

  Future<void> _insertContent({
    required DatabaseExecutor txn,
    required List<LearningModule> modules,
    required List<LearningLevel> levels,
    required Set<String> downloadedLevelIds,
  }) async {
    for (final module in modules) {
      await txn.insert(
        LocalDbSchema.modules,
        ContentMapper.moduleToLocalMap(module),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    for (final level in levels) {
      final levelToStore = level.copyWith(
        isDownloaded:
            level.isDownloaded || downloadedLevelIds.contains(level.id),
      );
      await txn.insert(
        LocalDbSchema.levels,
        ContentMapper.levelToLocalMap(levelToStore),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      for (var index = 0; index < level.contentItems.length; index++) {
        await txn.insert(
          LocalDbSchema.contentItems,
          ContentMapper.contentItemToLocalMap(
            item: level.contentItems[index],
            id: '${level.id}-content-$index',
            levelId: level.id,
            sortOrder: index,
          ),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      for (var index = 0; index < level.quizQuestions.length; index++) {
        await txn.insert(
          LocalDbSchema.quizQuestions,
          ContentMapper.quizQuestionToLocalMap(
            question: level.quizQuestions[index],
            levelId: level.id,
            sortOrder: index,
          ),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      for (var index = 0; index < level.videoLessons.length; index++) {
        await txn.insert(
          LocalDbSchema.videoLessons,
          ContentMapper.videoLessonToLocalMap(
            lesson: level.videoLessons[index],
            levelId: level.id,
            sortOrder: index,
          ),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    }
  }

  Future<LearningLevel> _levelFromRow(
    DatabaseExecutor db,
    Map<String, Object?> row,
  ) async {
    final levelId = row['levelId']! as String;
    final contentRows = await db.query(
      LocalDbSchema.contentItems,
      where: 'levelId = ?',
      whereArgs: [levelId],
      orderBy: 'sortOrder ASC',
    );
    final questionRows = await db.query(
      LocalDbSchema.quizQuestions,
      where: 'levelId = ?',
      whereArgs: [levelId],
      orderBy: 'sortOrder ASC',
    );
    final videoRows = await db.query(
      LocalDbSchema.videoLessons,
      where: 'levelId = ?',
      whereArgs: [levelId],
      orderBy: 'sortOrder ASC',
    );

    return ContentMapper.levelFromLocalMaps(
      levelMap: row,
      contentItems:
          contentRows.map(ContentMapper.contentItemFromLocalMap).toList(),
      quizQuestions:
          questionRows.map(ContentMapper.quizQuestionFromLocalMap).toList(),
      videoLessons:
          videoRows.map(ContentMapper.videoLessonFromLocalMap).toList(),
    );
  }
}

class InMemoryContentDao implements ContentDao {
  final Map<String, LearningModule> _modulesById = {};
  final Map<String, LearningLevel> _levelsById = {};

  @override
  Future<List<LearningLevel>> getLevelsForModule(String moduleId) async {
    return _levelsById.values
        .where((level) => level.moduleId == moduleId)
        .toList()
      ..sort((a, b) {
        final stageCompare = a.stage.compareTo(b.stage);
        if (stageCompare != 0) return stageCompare;
        return a.levelNumber.compareTo(b.levelNumber);
      });
  }

  @override
  Future<LearningLevel?> getLevelById(String levelId) async {
    return _levelsById[levelId];
  }

  @override
  Future<LearningModule?> getModuleById(String moduleId) async {
    return _modulesById[moduleId];
  }

  @override
  Future<void> markLevelDownloaded(String levelId) async {
    final level = _levelsById[levelId];
    if (level == null) return;
    _levelsById[levelId] = level.copyWith(isDownloaded: true);
  }

  @override
  Future<List<LearningModule>> getModules() async {
    return _modulesById.values.toList()
      ..sort((a, b) => a.order.compareTo(b.order));
  }

  @override
  Future<bool> hasModules() async {
    return _modulesById.isNotEmpty;
  }

  @override
  Future<void> seedContent({
    required List<LearningModule> modules,
    required List<LearningLevel> levels,
  }) async {
    for (final module in modules) {
      _modulesById[module.id] = module;
    }
    for (final level in levels) {
      _levelsById[level.id] = level;
    }
  }

  @override
  Future<void> replaceContent({
    required List<LearningModule> modules,
    required List<LearningLevel> levels,
  }) async {
    final downloadedLevelIds = _levelsById.values
        .where((level) => level.isDownloaded)
        .map((level) => level.id)
        .toSet();

    _modulesById
      ..clear()
      ..addEntries(modules.map((module) => MapEntry(module.id, module)));
    _levelsById
      ..clear()
      ..addEntries(levels.map((level) {
        return MapEntry(
          level.id,
          level.copyWith(
            isDownloaded:
                level.isDownloaded || downloadedLevelIds.contains(level.id),
          ),
        );
      }));
  }
}
