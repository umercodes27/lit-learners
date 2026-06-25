import 'package:sqflite/sqflite.dart';

import '../../models/progress.dart';
import 'db_helper.dart';
import 'db_schema.dart';
import 'progress_mapper.dart';

abstract class ProgressDao {
  Future<List<LevelProgress>> getByChild(String childId);

  Future<LevelProgress?> getByLevel({
    required String childId,
    required String levelId,
  });

  Future<List<LevelProgress>> getUnsynced();

  Future<void> upsert(LevelProgress progress);

  Future<void> markSynced({
    required String childId,
    required String levelId,
  });
}

class SqfliteProgressDao implements ProgressDao {
  SqfliteProgressDao(this._dbHelper);

  final LocalDbHelper _dbHelper;

  @override
  Future<List<LevelProgress>> getByChild(String childId) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      LocalDbSchema.levelProgress,
      where: 'childId = ?',
      whereArgs: [childId],
      orderBy: 'updatedAt DESC',
    );
    return rows.map(ProgressMapper.fromLocalMap).toList();
  }

  @override
  Future<LevelProgress?> getByLevel({
    required String childId,
    required String levelId,
  }) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      LocalDbSchema.levelProgress,
      where: 'childId = ? AND levelId = ?',
      whereArgs: [childId, levelId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return ProgressMapper.fromLocalMap(rows.first);
  }

  @override
  Future<List<LevelProgress>> getUnsynced() async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      LocalDbSchema.levelProgress,
      where: 'isSynced = ?',
      whereArgs: [0],
      orderBy: 'updatedAt ASC',
    );
    return rows.map(ProgressMapper.fromLocalMap).toList();
  }

  @override
  Future<void> markSynced({
    required String childId,
    required String levelId,
  }) async {
    final db = await _dbHelper.database;
    await db.update(
      LocalDbSchema.levelProgress,
      {'isSynced': 1},
      where: 'childId = ? AND levelId = ?',
      whereArgs: [childId, levelId],
    );
  }

  @override
  Future<void> upsert(LevelProgress progress) async {
    final db = await _dbHelper.database;
    await db.insert(
      LocalDbSchema.levelProgress,
      ProgressMapper.toLocalMap(progress),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}

class InMemoryProgressDao implements ProgressDao {
  final Map<String, LevelProgress> _progressByKey = {};

  @override
  Future<List<LevelProgress>> getByChild(String childId) async {
    return _progressByKey.values
        .where((progress) => progress.childId == childId)
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  @override
  Future<LevelProgress?> getByLevel({
    required String childId,
    required String levelId,
  }) async {
    return _progressByKey[_key(childId, levelId)];
  }

  @override
  Future<List<LevelProgress>> getUnsynced() async {
    return _progressByKey.values
        .where((progress) => !progress.isSynced)
        .toList()
      ..sort((a, b) => a.updatedAt.compareTo(b.updatedAt));
  }

  @override
  Future<void> markSynced({
    required String childId,
    required String levelId,
  }) async {
    final key = _key(childId, levelId);
    final progress = _progressByKey[key];
    if (progress == null) return;
    _progressByKey[key] = progress.copyWith(isSynced: true);
  }

  @override
  Future<void> upsert(LevelProgress progress) async {
    _progressByKey[_key(progress.childId, progress.levelId)] = progress;
  }

  String _key(String childId, String levelId) => '$childId::$levelId';
}
