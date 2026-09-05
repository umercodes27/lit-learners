import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../models/activity_pack.dart';
import 'asset_availability.dart';

/// The outcome of loading one age pack, including what it asks for but the
/// bundle does not have.
class ActivityPackLoadResult {
  const ActivityPackLoadResult({
    required this.pack,
    required this.missingAssets,
    this.repairedAssets = const {},
    this.error,
  });

  final ActivityPack? pack;

  /// Paths the JSON references that are not in the bundle. Reported rather
  /// than thrown: the levels that do have their assets still play.
  final List<String> missingAssets;

  /// Paths the pack got wrong that were matched to a real file by name, as
  /// `authored -> used`. Surfaced so the JSON can be corrected at source
  /// rather than quietly depending on the repair.
  final Map<String, String> repairedAssets;

  /// Set when the pack file itself could not be read or parsed.
  final String? error;

  bool get hasPack => pack != null;
  bool get hasMissingAssets => missingAssets.isNotEmpty;
  bool get hasRepairedAssets => repairedAssets.isNotEmpty;
}

/// Reads a `little-learners-ageN-data.json` out of the bundle and parses it.
///
/// Pointing [load] at a different path is the whole extension story for a new
/// age group: same models, same widgets, different content.
class ActivityPackLoader {
  ActivityPackLoader({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  static const age2Path = 'assets/age2/little-learners-age2-data.json';
  static const age3Path = 'assets/age3/little-learners-age3-data.json';

  /// The instance the screens use, so the pack is parsed and audited once per
  /// run rather than on every navigation.
  static final ActivityPackLoader shared = ActivityPackLoader();

  static final Map<String, ActivityPackLoader> _byPath = {};

  /// One loader per pack, so each keeps its own parsed copy and asset audit.
  /// Age 2 keeps using [shared] so nothing about its behaviour changes.
  static ActivityPackLoader forPath(String path) {
    if (path == age2Path) return shared;
    return _byPath.putIfAbsent(path, ActivityPackLoader.new);
  }

  final AssetBundle _bundle;

  ActivityPackLoadResult? _cached;

  Future<ActivityPackLoadResult> load({String path = age2Path}) async {
    final cached = _cached;
    if (cached != null) return cached;

    await AssetAvailability.instance.populate(bundle: _bundle);

    ActivityPackLoadResult result;
    try {
      final raw = await _bundle.loadString(path);
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        result = ActivityPackLoadResult(
          pack: null,
          missingAssets: const [],
          error: 'The pack at $path is not a JSON object.',
        );
      } else {
        final repairs = <String, String>{};
        final pack = ActivityPack.fromJson(
          _rebaseAssetPaths(decoded, path, repairs)! as Map<String, dynamic>,
        );
        final missing =
            AssetAvailability.instance.missingFrom(pack.referencedAssets);
        _reportMissing(path, missing, repairs);
        result = ActivityPackLoadResult(
          pack: pack,
          missingAssets: missing,
          repairedAssets: repairs,
        );
      }
    } on Exception catch (error) {
      result = ActivityPackLoadResult(
        pack: null,
        missingAssets: const [],
        error: 'Could not read $path: $error',
      );
    }

    _cached = result;
    return result;
  }

  void clearCache() => _cached = null;

  /// Rewrites `assets/…` paths that are missing into the pack's own folder.
  ///
  /// A pack is authored against the media folder it shipped with, so it says
  /// `assets/audio/en/letter_A.mp3` — but the media lives under
  /// `assets/age2/audio/…` here, namespaced so several age packs can coexist.
  /// Rather than make whoever writes the JSON know about that, a path the
  /// bundle does not have is retried under the pack's own directory, and only
  /// swapped when that version actually exists.
  ///
  /// Paths that already resolve are untouched, so a pack authored with the
  /// full prefix keeps working and a genuinely missing file stays missing and
  /// still gets reported.
  /// Repairs recorded in [repairs] as `authored path -> path actually used`,
  /// so the screen can show what was corrected instead of hiding it.
  Object? _rebaseAssetPaths(
    Object? node,
    String packPath,
    Map<String, String> repairs,
  ) {
    final packDir = packPath.substring(0, packPath.lastIndexOf('/') + 1);
    if (packDir.isEmpty) return node;

    String resolve(String authored) {
      if (AssetAvailability.instance.has(authored)) return authored;

      // 1. Same layout, under the pack's own folder.
      final rebased = '$packDir${authored.substring('assets/'.length)}';
      if (AssetAvailability.instance.has(rebased)) return rebased;

      // 2. Right file, wrong folder — accepted only when the name is unique
      //    inside the pack, so a repair can never pick between two candidates.
      final basename = authored.split('/').last;
      final matches = AssetAvailability.instance
          .findByBasename(basename, prefix: packDir);
      if (matches.length == 1) {
        repairs[authored] = matches.first;
        return matches.first;
      }

      return authored;
    }

    Object? walk(Object? value) {
      if (value is String) {
        return value.startsWith('assets/') ? resolve(value) : value;
      }
      if (value is List) return value.map(walk).toList();
      if (value is Map<String, dynamic>) {
        return value.map((key, item) => MapEntry(key, walk(item)));
      }
      return value;
    }

    return walk(node);
  }

  void _reportMissing(
    String path,
    List<String> missing,
    Map<String, String> repairs,
  ) {
    if (!kDebugMode || (missing.isEmpty && repairs.isEmpty)) return;
    debugPrint('=' * 72);
    if (repairs.isNotEmpty) {
      debugPrint('$path points at ${repairs.length} asset(s) in the wrong '
          'folder. Matched by file name — fix the paths at source:');
      repairs.forEach((authored, used) {
        debugPrint('  ! $authored');
        debugPrint('    -> $used');
      });
    }
    if (missing.isNotEmpty) {
      debugPrint('$path references ${missing.length} asset(s) not in the '
          'bundle at all.');
      debugPrint('These are skipped with a placeholder, not crashed on:');
      for (final asset in missing) {
        debugPrint('  - $asset');
      }
    }
    debugPrint('=' * 72);
  }
}
