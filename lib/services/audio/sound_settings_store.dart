import 'package:sqflite/sqflite.dart';

import '../local/db_helper.dart';
import '../local/db_schema.dart';

/// Where the parent's sound choices live between runs.
///
/// Backed by the `appMeta` key/value table the content revision already uses,
/// so this needs no migration and no new dependency.
abstract class SoundSettingsStore {
  Future<SoundSettings> read();

  Future<void> write(SoundSettings settings);
}

class SoundSettings {
  const SoundSettings({
    required this.muted,
    required this.musicVolume,
    required this.sfxVolume,
  });

  final bool muted;
  final double musicVolume;
  final double sfxVolume;

  SoundSettings copyWith({
    bool? muted,
    double? musicVolume,
    double? sfxVolume,
  }) {
    return SoundSettings(
      muted: muted ?? this.muted,
      musicVolume: musicVolume ?? this.musicVolume,
      sfxVolume: sfxVolume ?? this.sfxVolume,
    );
  }
}

/// Forgets everything when the app closes. The default, and what the tests
/// get.
class InMemorySoundSettingsStore implements SoundSettingsStore {
  InMemorySoundSettingsStore(this._settings);

  SoundSettings _settings;

  @override
  Future<SoundSettings> read() async => _settings;

  @override
  Future<void> write(SoundSettings settings) async => _settings = settings;
}

class LocalSoundSettingsStore implements SoundSettingsStore {
  LocalSoundSettingsStore({
    required LocalDbHelper dbHelper,
    required SoundSettings defaults,
  })  : _dbHelper = dbHelper,
        _defaults = defaults;

  final LocalDbHelper _dbHelper;
  final SoundSettings _defaults;

  static const _mutedKey = 'soundMuted';
  static const _musicKey = 'soundMusicVolume';
  static const _sfxKey = 'soundSfxVolume';

  @override
  Future<SoundSettings> read() async {
    try {
      final db = await _dbHelper.database;
      final rows = await db.query(
        LocalDbSchema.appMeta,
        where: 'metaKey IN (?, ?, ?)',
        whereArgs: [_mutedKey, _musicKey, _sfxKey],
      );
      final values = {
        for (final row in rows)
          row['metaKey'] as String: row['metaValue'] as String,
      };

      return SoundSettings(
        muted: values[_mutedKey] == 'true',
        musicVolume:
            double.tryParse(values[_musicKey] ?? '') ?? _defaults.musicVolume,
        sfxVolume:
            double.tryParse(values[_sfxKey] ?? '') ?? _defaults.sfxVolume,
      );
    } on Object {
      // A settings read must never be the reason the app fails to start.
      return _defaults;
    }
  }

  @override
  Future<void> write(SoundSettings settings) async {
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

      put(_mutedKey, settings.muted.toString());
      put(_musicKey, settings.musicVolume.toString());
      put(_sfxKey, settings.sfxVolume.toString());
      await batch.commit(noResult: true);
    } on Object {
      // Losing a volume preference is not worth an error in front of a parent.
    }
  }
}
