import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import 'db_schema.dart';

class LocalDbHelper {
  Database? _database;

  Future<Database> get database async {
    final existing = _database;
    if (existing != null) return existing;

    final databasePath = await getDatabasesPath();
    final fullPath = path.join(databasePath, LocalDbSchema.databaseName);
    final opened = await openDatabase(
      fullPath,
      version: LocalDbSchema.version,
      onCreate: (db, version) async {
        for (final statement in LocalDbSchema.createStatements) {
          await db.execute(statement);
        }
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          for (final statement in LocalDbSchema.version2Statements) {
            await db.execute(statement);
          }
        }
        if (oldVersion < 3) {
          for (final statement in LocalDbSchema.version3Statements) {
            await db.execute(statement);
          }
        }
        if (oldVersion < 4) {
          for (final statement in LocalDbSchema.version4Statements) {
            await db.execute(statement);
          }
        }
      },
    );
    _database = opened;
    return opened;
  }

  Future<void> close() async {
    final existing = _database;
    if (existing == null) return;

    await existing.close();
    _database = null;
  }
}
