import 'package:flutter/foundation.dart';

import 'app_sounds.dart';

/// The app's one speaker.
///
/// Two channels, never one. Music is a single looping player that has to
/// survive navigation; effects are short one-shots that have to be able to
/// overlap. Sharing a player between them means every tap stops the music,
/// which is the classic way to get this wrong.
///
/// A [ChangeNotifier] so the parent's sound settings rebuild when they change.
abstract class SoundController extends ChangeNotifier {
  /// Silences everything without forgetting the volumes underneath.
  bool get muted;

  double get musicVolume;
  double get sfxVolume;

  /// Whether the platform has let us play anything yet. Browsers refuse audio
  /// until the person has interacted with the page, so on web this stays false
  /// until the first tap.
  bool get unlocked;

  Future<void> load();

  /// Called from the first real tap. On web this is what makes sound possible
  /// at all; everywhere else it is a no-op.
  Future<void> unlock();

  Future<void> play(Sfx sfx);

  /// Starts [track] if it is not already the one playing. Calling it with the
  /// track that is already on does nothing, so screens can call it in `build`
  /// without restarting the bed on every rebuild.
  Future<void> playMusic(MusicTrack track);

  Future<void> stopMusic();

  /// Drops the music to a whisper while something else needs to be heard — a
  /// video lesson, mostly. Returns it afterwards with [unduck].
  Future<void> duck();

  Future<void> unduck();

  Future<void> setMuted(bool value);

  Future<void> setMusicVolume(double value);

  Future<void> setSfxVolume(double value);
}

/// A [SoundController] that plays nothing.
///
/// The default everywhere, which is what keeps the widget tests silent and
/// free of the pending timers a real player would leave behind. The real one
/// is swapped in by `app.dart` at startup.
class SilentSoundController extends SoundController {
  SilentSoundController();

  bool _muted = false;
  double _musicVolume = _defaultMusicVolume;
  double _sfxVolume = _defaultSfxVolume;

  @override
  bool get muted => _muted;

  @override
  double get musicVolume => _musicVolume;

  @override
  double get sfxVolume => _sfxVolume;

  @override
  bool get unlocked => true;

  @override
  Future<void> load() async {}

  @override
  Future<void> unlock() async {}

  @override
  Future<void> play(Sfx sfx) async {}

  @override
  Future<void> playMusic(MusicTrack track) async {}

  @override
  Future<void> stopMusic() async {}

  @override
  Future<void> duck() async {}

  @override
  Future<void> unduck() async {}

  @override
  Future<void> setMuted(bool value) async {
    _muted = value;
    notifyListeners();
  }

  @override
  Future<void> setMusicVolume(double value) async {
    _musicVolume = value.clamp(0.0, 1.0);
    notifyListeners();
  }

  @override
  Future<void> setSfxVolume(double value) async {
    _sfxVolume = value.clamp(0.0, 1.0);
    notifyListeners();
  }
}

/// Background music sits well under the effects on purpose. A bed a parent
/// notices is a bed a parent turns off.
const _defaultMusicVolume = 0.28;
const _defaultSfxVolume = 0.75;

/// Where the app reaches for sound.
///
/// A single mutable instance rather than a `Provider` lookup, because the
/// widget that needs it most — `Squishy` — is used in dozens of places and in
/// tests that build no providers at all. It starts silent, so a test that
/// knows nothing about audio stays silent.
class AppSound {
  const AppSound._();

  /// Starts silent and is swapped for the real player by `app.dart`.
  static SoundController instance = SilentSoundController();

  /// Fire and forget. Nothing in the UI should ever wait on a sound.
  static void play(Sfx sfx) {
    instance.play(sfx);
  }
}
