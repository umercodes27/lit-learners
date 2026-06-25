import 'package:sqflite/sqflite.dart';

import '../../models/child_profile.dart';
import 'child_profile_mapper.dart';
import 'db_helper.dart';
import 'db_schema.dart';

abstract class ChildProfileDao {
  Future<List<ChildProfile>> getByParent(String parentId);
  Future<ChildProfile?> getById(String childId);
  Future<List<ChildProfile>> getUnsynced();
  Future<void> upsert(ChildProfile profile);
  Future<void> delete({
    required String parentId,
    required String childId,
  });
  Future<int> deleteSyncedProfilesNotIn({
    required String parentId,
    required Set<String> childIds,
  });
  Future<void> markSynced(String childId);
}

class SqfliteChildProfileDao implements ChildProfileDao {
  SqfliteChildProfileDao(this._dbHelper);

  final LocalDbHelper _dbHelper;

  @override
  Future<void> delete({
    required String parentId,
    required String childId,
  }) async {
    final db = await _dbHelper.database;
    await db.delete(
      LocalDbSchema.childProfiles,
      where: 'parentId = ? AND childId = ?',
      whereArgs: [parentId, childId],
    );
  }

  @override
  Future<int> deleteSyncedProfilesNotIn({
    required String parentId,
    required Set<String> childIds,
  }) async {
    final db = await _dbHelper.database;
    if (childIds.isEmpty) {
      return db.delete(
        LocalDbSchema.childProfiles,
        where: 'parentId = ? AND isSynced = ?',
        whereArgs: [parentId, 1],
      );
    }

    final placeholders = List.filled(childIds.length, '?').join(', ');
    return db.delete(
      LocalDbSchema.childProfiles,
      where: 'parentId = ? AND isSynced = ? AND childId NOT IN ($placeholders)',
      whereArgs: [parentId, 1, ...childIds],
    );
  }

  @override
  Future<List<ChildProfile>> getByParent(String parentId) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      LocalDbSchema.childProfiles,
      where: 'parentId = ?',
      whereArgs: [parentId],
      orderBy: 'createdAt ASC',
    );
    return rows.map(ChildProfileMapper.fromLocalMap).toList();
  }

  @override
  Future<ChildProfile?> getById(String childId) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      LocalDbSchema.childProfiles,
      where: 'childId = ?',
      whereArgs: [childId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return ChildProfileMapper.fromLocalMap(rows.first);
  }

  @override
  Future<List<ChildProfile>> getUnsynced() async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      LocalDbSchema.childProfiles,
      where: 'isSynced = ?',
      whereArgs: [0],
      orderBy: 'updatedAt ASC',
    );
    return rows.map(ChildProfileMapper.fromLocalMap).toList();
  }

  @override
  Future<void> markSynced(String childId) async {
    final db = await _dbHelper.database;
    await db.update(
      LocalDbSchema.childProfiles,
      {'isSynced': 1},
      where: 'childId = ?',
      whereArgs: [childId],
    );
  }

  @override
  Future<void> upsert(ChildProfile profile) async {
    final db = await _dbHelper.database;
    await db.insert(
      LocalDbSchema.childProfiles,
      ChildProfileMapper.toLocalMap(profile),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}

class InMemoryChildProfileDao implements ChildProfileDao {
  final Map<String, ChildProfile> _profilesById = {};

  @override
  Future<void> delete({
    required String parentId,
    required String childId,
  }) async {
    final profile = _profilesById[childId];
    if (profile?.parentId != parentId) return;
    _profilesById.remove(childId);
  }

  @override
  Future<int> deleteSyncedProfilesNotIn({
    required String parentId,
    required Set<String> childIds,
  }) async {
    final removableIds = _profilesById.values
        .where((profile) =>
            profile.parentId == parentId &&
            profile.isSynced &&
            !childIds.contains(profile.id))
        .map((profile) => profile.id)
        .toList();

    for (final childId in removableIds) {
      _profilesById.remove(childId);
    }
    return removableIds.length;
  }

  @override
  Future<List<ChildProfile>> getByParent(String parentId) async {
    final profiles = _profilesById.values
        .where((profile) => profile.parentId == parentId)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return profiles;
  }

  @override
  Future<ChildProfile?> getById(String childId) async {
    return _profilesById[childId];
  }

  @override
  Future<List<ChildProfile>> getUnsynced() async {
    final profiles = _profilesById.values
        .where((profile) => !profile.isSynced)
        .toList()
      ..sort((a, b) => a.updatedAt.compareTo(b.updatedAt));
    return profiles;
  }

  @override
  Future<void> markSynced(String childId) async {
    final profile = _profilesById[childId];
    if (profile == null) return;
    _profilesById[childId] = profile.copyWith(isSynced: true);
  }

  @override
  Future<void> upsert(ChildProfile profile) async {
    _profilesById[profile.id] = profile;
  }
}
