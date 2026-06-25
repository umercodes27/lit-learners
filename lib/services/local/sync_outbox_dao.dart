import 'package:sqflite/sqflite.dart';

import '../../models/sync_outbox_item.dart';
import 'db_helper.dart';
import 'db_schema.dart';
import 'sync_outbox_mapper.dart';

abstract class SyncOutboxDao {
  Future<void> enqueue(SyncOutboxItem item);
  Future<List<SyncOutboxItem>> getPending();
  Future<void> markCompleted(String id);
  Future<void> markFailed({
    required String id,
    required String error,
  });
}

class SqfliteSyncOutboxDao implements SyncOutboxDao {
  SqfliteSyncOutboxDao(this._dbHelper);

  final LocalDbHelper _dbHelper;

  @override
  Future<void> enqueue(SyncOutboxItem item) async {
    final db = await _dbHelper.database;
    await db.insert(
      LocalDbSchema.syncOutbox,
      SyncOutboxMapper.toLocalMap(item),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<List<SyncOutboxItem>> getPending() async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      LocalDbSchema.syncOutbox,
      orderBy: 'createdAt ASC',
    );
    return rows.map(SyncOutboxMapper.fromLocalMap).toList();
  }

  @override
  Future<void> markCompleted(String id) async {
    final db = await _dbHelper.database;
    await db.delete(
      LocalDbSchema.syncOutbox,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> markFailed({
    required String id,
    required String error,
  }) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      LocalDbSchema.syncOutbox,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return;

    final item = SyncOutboxMapper.fromLocalMap(rows.first);
    await db.update(
      LocalDbSchema.syncOutbox,
      SyncOutboxMapper.toLocalMap(
        item.copyWith(
          attemptCount: item.attemptCount + 1,
          lastError: error,
        ),
      ),
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}

class InMemorySyncOutboxDao implements SyncOutboxDao {
  final Map<String, SyncOutboxItem> _itemsById = {};

  @override
  Future<void> enqueue(SyncOutboxItem item) async {
    _itemsById[item.id] = item;
  }

  @override
  Future<List<SyncOutboxItem>> getPending() async {
    return _itemsById.values.toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  @override
  Future<void> markCompleted(String id) async {
    _itemsById.remove(id);
  }

  @override
  Future<void> markFailed({
    required String id,
    required String error,
  }) async {
    final item = _itemsById[id];
    if (item == null) return;
    _itemsById[id] = item.copyWith(
      attemptCount: item.attemptCount + 1,
      lastError: error,
    );
  }
}
