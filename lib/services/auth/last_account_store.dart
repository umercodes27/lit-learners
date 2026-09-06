import 'package:sqflite/sqflite.dart';

import '../local/db_helper.dart';
import '../local/db_schema.dart';

/// The email of the last parent to sign in on this device.
///
/// A family shares one tablet and one account, so the sign-in screen asking
/// for the address again every time is asking a question it already knows the
/// answer to. Remembering it turns the return trip into one field - the
/// password - and leaves the address there to be corrected when it is wrong.
///
/// Only the address is kept. The password is never stored, and neither is
/// anything that would let the app sign in without one.
///
/// Backed by the `appMeta` key/value table, so this needs no migration.
abstract class LastAccountStore {
  Future<String?> read();

  Future<void> write(String email);

  /// Called when a parent says the remembered address is not theirs.
  Future<void> clear();
}

/// Forgets when the process does. The default, and what the tests get.
class InMemoryLastAccountStore implements LastAccountStore {
  InMemoryLastAccountStore([this._email]);

  String? _email;

  @override
  Future<String?> read() async => _email;

  @override
  Future<void> write(String email) async => _email = _normalize(email);

  @override
  Future<void> clear() async => _email = null;
}

class LocalLastAccountStore implements LastAccountStore {
  LocalLastAccountStore({required LocalDbHelper dbHelper})
      : _dbHelper = dbHelper;

  final LocalDbHelper _dbHelper;

  static const _key = 'lastParentEmail';

  @override
  Future<String?> read() async {
    try {
      final db = await _dbHelper.database;
      final rows = await db.query(
        LocalDbSchema.appMeta,
        where: 'metaKey = ?',
        whereArgs: [_key],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      final value = rows.first['metaValue'] as String?;
      return (value == null || value.isEmpty) ? null : value;
    } catch (_) {
      // Deliberately broad. This is a convenience, not a requirement: a
      // sign-in screen that cannot read the last address is a sign-in screen
      // with an empty field. The database is not always even there - a widget
      // test never configures a factory - and none of that is worth failing
      // a sign-in over.
      return null;
    }
  }

  @override
  Future<void> write(String email) async {
    final normalized = _normalize(email);
    if (normalized.isEmpty) return;
    try {
      final db = await _dbHelper.database;
      await db.insert(
        LocalDbSchema.appMeta,
        {'metaKey': _key, 'metaValue': normalized},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (_) {
      // Failing to remember must never fail the sign-in that just succeeded.
    }
  }

  @override
  Future<void> clear() async {
    try {
      final db = await _dbHelper.database;
      await db.delete(
        LocalDbSchema.appMeta,
        where: 'metaKey = ?',
        whereArgs: [_key],
      );
    } catch (_) {
      // As above.
    }
  }
}

String _normalize(String email) => email.trim().toLowerCase();
