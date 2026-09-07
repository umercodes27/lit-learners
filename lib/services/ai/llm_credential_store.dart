import 'package:sqflite/sqflite.dart';

import '../local/db_helper.dart';
import '../local/db_schema.dart';
import 'llm_client.dart';
import 'llm_provider_profile.dart';

class LlmCredentialException implements Exception {
  const LlmCredentialException(this.message);
  final String message;
  @override
  String toString() => message;
}

abstract class LlmCredentialStore {
  Future<LlmCredentials> read();
  Future<void> write(LlmCredentials credentials);
  Future<void> clear();
}

class InMemoryLlmCredentialStore implements LlmCredentialStore {
  InMemoryLlmCredentialStore([this._credentials = const LlmCredentials.unset()]);

  LlmCredentials _credentials;

  @override
  Future<LlmCredentials> read() async => _credentials;

  @override
  Future<void> write(LlmCredentials credentials) async {
    _credentials = credentials;
  }

  @override
  Future<void> clear() async {
    _credentials = const LlmCredentials.unset();
  }
}

/// The admin's own API key, on the admin's own device.
///
/// Stored in the `appMeta` key/value table the sound settings and the content
/// revision already use, so this needs no migration and no new dependency.
///
/// Be clear about what this is and is not. The key is held in plain text in
/// the app's sqflite database, protected by nothing but the platform's app
/// sandbox; on a rooted or jailbroken device it is readable. It is stored
/// here rather than shipped in the binary because the admin panel is part of
/// the same app parents install — a build-time key, whether from a dart-define
/// or a bundled .env asset, would land on every family's phone, where it is
/// the developer's key being spent by strangers. This way the key belongs to
/// the admin who pasted it and reaches only their device.
///
/// Do not "protect" it with base64 or an XOR: that stops nobody who can read
/// the file and leaves everyone believing it was encrypted. The honest
/// mitigations are the Forget key button, the warning on the key card, and
/// using a key with a spend cap.
class LocalLlmCredentialStore implements LlmCredentialStore {
  LocalLlmCredentialStore({
    required LocalDbHelper dbHelper,
    LlmProviderProfile defaults = LlmProviderProfile.deepseek,
  })  : _dbHelper = dbHelper,
        _defaults = defaults;

  final LocalDbHelper _dbHelper;
  final LlmProviderProfile _defaults;

  static const _apiKeyKey = 'aiApiKey';
  static const _providerKey = 'aiProviderId';
  static const _baseUrlKey = 'aiBaseUrl';
  static const _modelKey = 'aiModel';
  static const _jsonModeKey = 'aiJsonMode';

  static const _keys = [
    _apiKeyKey,
    _providerKey,
    _baseUrlKey,
    _modelKey,
    _jsonModeKey,
  ];

  @override
  Future<LlmCredentials> read() async {
    try {
      final db = await _dbHelper.database;
      final rows = await db.query(
        LocalDbSchema.appMeta,
        where: 'metaKey IN (?, ?, ?, ?, ?)',
        whereArgs: _keys,
      );
      final values = {
        for (final row in rows)
          row['metaKey'] as String: row['metaValue'] as String?,
      };

      return LlmCredentials(
        apiKey: values[_apiKeyKey] ?? '',
        profile: values[_providerKey] == null
            ? _defaults
            : LlmProviderProfile.fromMap({
                'id': values[_providerKey],
                'baseUrl': values[_baseUrlKey],
                'model': values[_modelKey],
                'jsonMode': values[_jsonModeKey],
              }),
      );
    } on Object {
      // Reading settings must never be why the admin panel fails to open.
      // The generate button will simply report that no key is set.
      return LlmCredentials(apiKey: '', profile: _defaults);
    }
  }

  /// Unlike the sound settings, a failure here is raised rather than
  /// swallowed. Losing a volume preference quietly is kind; losing an API key
  /// the admin just pasted means they press Generate and are told there is no
  /// key, with no idea why.
  @override
  Future<void> write(LlmCredentials credentials) async {
    try {
      final db = await _dbHelper.database;
      final batch = db.batch();
      void put(String key, String value) {
        batch.insert(
          LocalDbSchema.appMeta,
          {'metaKey': key, 'metaValue': value},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      final profile = credentials.profile.toMap();
      put(_apiKeyKey, credentials.apiKey.trim());
      put(_providerKey, profile['id']!);
      put(_baseUrlKey, profile['baseUrl']!);
      put(_modelKey, profile['model']!);
      put(_jsonModeKey, profile['jsonMode']!);
      await batch.commit(noResult: true);
    } on Object catch (error) {
      throw LlmCredentialException('The API key could not be saved: $error');
    }
  }

  /// Deletes the rows rather than blanking them, so Forget key leaves nothing
  /// on disk to find.
  @override
  Future<void> clear() async {
    try {
      final db = await _dbHelper.database;
      await db.delete(
        LocalDbSchema.appMeta,
        where: 'metaKey IN (?, ?, ?, ?, ?)',
        whereArgs: _keys,
      );
    } on Object catch (error) {
      throw LlmCredentialException('The API key could not be removed: $error');
    }
  }
}
