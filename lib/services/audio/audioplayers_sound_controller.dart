import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import 'app_sounds.dart';
import 'sound_controller.dart';
import 'sound_settings_store.dart';

/// The real speaker.
///
/// Everything in here is wrapped so a failure is silent. A missing file, a
/// platform that will not play, a browser that has not been tapped yet — none
/// of those are worth an error in front of a child, and none of them should
/// stop the screen working.
class AudioplayersSoundController extends SoundController {
  AudioplayersSoundController({
    required SoundSettingsStore store,
    bool requiresUserGesture = kIsWeb,
  })  : _store = store,
        _unlocked = !requiresUserGesture;

  final SoundSettingsStore _store;

  final Map<Sfx, AudioPool> _pools = {};
  final Set<Sfx> _loading = {};
  AudioPlayer? _musicPlayer;
  MusicTrack? _currentTrack;

  bool _muted = false;
  bool _ducked = false;
  bool _unlocked;
  double _musicVolume = 0.28;
  double _sfxVolume = 0.75;

  /// How far the bed drops while a video lesson is speaking.
  static const _duckFactor = 0.18;

  @override
  bool get muted => _muted;

  @override
  double get musicVolume => _musicVolume;

  @override
  double get sfxVolume => _sfxVolume;

  @override
  bool get unlocked => _unlocked;

  double get _effectiveMusicVolume {
    if (_muted) return 0;
    return _musicVolume * (_ducked ? _duckFactor : 1.0);
  }

  @override
  Future<void> load() async {
    final settings = await _store.read();
    _muted = settings.muted;
    _musicVolume = settings.musicVolume;
    _sfxVolume = settings.sfxVolume;
    notifyListeners();
  }

  @override
  Future<void> unlock() async {
    if (_unlocked) return;
    _unlocked = true;
    // A track asked for before the browser allowed sound is remembered rather
    // than dropped, so the music starts on the first tap instead of on the
    // second screen.
    final pending = _currentTrack;
    if (pending != null) {
      _currentTrack = null;
      await playMusic(pending);
    }
    notifyListeners();
  }

  @override
  Future<void> play(Sfx sfx) async {
    if (_muted || !_unlocked) return;

    final pool = _pools[sfx];
    if (pool == null) {
      unawaited(_warmUp(sfx, thenPlay: true));
      return;
    }

    try {
      await pool.start(volume: _sfxVolume);
    } on Object {
      // Nothing to do: a missing effect is not worth interrupting anything.
    }
  }

  Future<void> _warmUp(Sfx sfx, {bool thenPlay = false}) async {
    if (_loading.contains(sfx) || _pools.containsKey(sfx)) return;
    _loading.add(sfx);
    try {
      final pool = await AudioPool.createFromAsset(
        path: sfx.asset,
        // Three at once is enough for stars landing one after another without
        // holding open a player per sound.
        maxPlayers: 3,
      );
      _pools[sfx] = pool;
      if (thenPlay && !_muted && _unlocked) {
        await pool.start(volume: _sfxVolume);
      }
    } on Object {
      // Leave it out of the map so a later tap tries again.
    } finally {
      _loading.remove(sfx);
    }
  }

  @override
  Future<void> playMusic(MusicTrack track) async {
    if (_currentTrack == track && _musicPlayer != null) return;
    _currentTrack = track;
    if (!_unlocked) return;

    try {
      final player = _musicPlayer ??= AudioPlayer();
      await player.setReleaseMode(ReleaseMode.loop);
      await player.setVolume(_effectiveMusicVolume);
      await player.play(AssetSource(track.asset), volume: _effectiveMusicVolume);
    } on Object {
      _currentTrack = null;
    }
  }

  @override
  Future<void> stopMusic() async {
    _currentTrack = null;
    try {
      await _musicPlayer?.stop();
    } on Object {
      // Already gone.
    }
  }

  @override
  Future<void> duck() async {
    if (_ducked) return;
    _ducked = true;
    await _applyMusicVolume();
  }

  @override
  Future<void> unduck() async {
    if (!_ducked) return;
    _ducked = false;
    await _applyMusicVolume();
  }

  Future<void> _applyMusicVolume() async {
    try {
      await _musicPlayer?.setVolume(_effectiveMusicVolume);
    } on Object {
      // Nothing playing.
    }
  }

  @override
  Future<void> setMuted(bool value) async {
    if (_muted == value) return;
    _muted = value;
    notifyListeners();

    if (value) {
      // Stop rather than silence: a paused-but-loaded track keeps an audio
      // focus claim on Android, which stops other apps from playing.
      final track = _currentTrack;
      await stopMusic();
      _currentTrack = track;
    } else {
      final track = _currentTrack;
      if (track != null) {
        _currentTrack = null;
        await playMusic(track);
      }
    }
    await _persist();
  }

  @override
  Future<void> setMusicVolume(double value) async {
    _musicVolume = value.clamp(0.0, 1.0);
    notifyListeners();
    await _applyMusicVolume();
    await _persist();
  }

  @override
  Future<void> setSfxVolume(double value) async {
    _sfxVolume = value.clamp(0.0, 1.0);
    notifyListeners();
    await _persist();
  }

  Future<void> _persist() {
    return _store.write(
      SoundSettings(
        muted: _muted,
        musicVolume: _musicVolume,
        sfxVolume: _sfxVolume,
      ),
    );
  }

  @override
  void dispose() {
    for (final pool in _pools.values) {
      pool.dispose();
    }
    _pools.clear();
    _musicPlayer?.dispose();
    super.dispose();
  }
}
