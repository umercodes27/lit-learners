import 'package:flutter/services.dart';

/// What the bundle actually shipped.
///
/// A content pack is authored separately from the art and audio, so it will
/// always drift: a level asks for `letter_B.mp3` that nobody recorded yet.
/// Loading that asset would throw inside a widget build and take the screen
/// down. Instead the pack loader fills this registry once from the asset
/// manifest, and the activity widgets consult it before they render, showing a
/// visible placeholder for the gap and playing nothing for a missing sound.
///
/// Empty until [populate] runs, and [isKnown] reports that so callers can tell
/// "not loaded yet" apart from "definitely missing" and stay optimistic.
class AssetAvailability {
  AssetAvailability._();

  static final AssetAvailability instance = AssetAvailability._();

  Set<String> _assets = const {};
  bool _populated = false;

  bool get isKnown => _populated;

  Future<void> populate({AssetBundle? bundle}) async {
    if (_populated) return;
    try {
      final manifest =
          await AssetManifest.loadFromAssetBundle(bundle ?? rootBundle);
      _assets = manifest.listAssets().toSet();
      _populated = true;
    } on Exception {
      // No manifest (some test harnesses) — stay optimistic rather than
      // declaring every asset missing and blanking out every screen.
      _assets = const {};
      _populated = false;
    }
  }

  /// True when [path] is safe to load. Unknown manifests answer true so the
  /// app behaves exactly as it did before this check existed.
  bool has(String? path) {
    if (path == null || path.isEmpty) return false;
    if (!_populated) return true;
    return _assets.contains(path);
  }

  /// Assets under [prefix] whose file name is exactly [basename].
  ///
  /// Used as the last resort when a pack points at the right file in the wrong
  /// folder. Returning every hit rather than the first is deliberate: a repair
  /// is only safe when there is exactly one candidate, and the caller has to
  /// be able to see that.
  List<String> findByBasename(String basename, {required String prefix}) {
    if (!_populated) return const [];
    return _assets
        .where((asset) =>
            asset.startsWith(prefix) && asset.endsWith('/$basename'))
        .toList()
      ..sort();
  }

  /// The subset of [paths] that the bundle does not contain.
  List<String> missingFrom(Iterable<String> paths) {
    if (!_populated) return const [];
    final missing = paths.where((path) => !_assets.contains(path)).toSet().toList()
      ..sort();
    return missing;
  }

  /// Test seam.
  void debugSeed(Set<String> assets) {
    _assets = assets;
    _populated = true;
  }

  /// Puts the registry back to never-loaded.
  ///
  /// [debugSeed] marks it populated, and this is a singleton, so without a way
  /// back one seeded test makes every later test in the file believe the
  /// manifest was read and that everything it does not name is missing.
  void debugReset() {
    _assets = const {};
    _populated = false;
  }
}
