import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import '../../services/audio/sound_controller.dart';
import '../../services/content/asset_availability.dart';

/// Sound for one activity screen: the spoken prompt, and the reward and retry
/// cues that every component shares.
///
/// Two players, deliberately: a prompt and a reward can overlap when a child
/// taps early, and a single player would cut the prompt off mid-word.
///
/// Every call is best-effort. A missing or unplayable file leaves the activity
/// silent and playable rather than throwing into a tap handler, which is the
/// same rule the images follow.
class ActivityAudio {
  ActivityAudio({
    this.correctSound,
    this.wrongSound,
  }) {
    // The prompt player carries every spoken word on an activity screen — the
    // instruction and the story narration both. Following its state is what
    // holds the music down for exactly as long as someone is talking, without
    // any screen having to remember to ask.
    _promptState = _prompt.onPlayerStateChanged.listen(_followPrompt);
  }

  /// audioplayers resolves [AssetSource] against its own `assets/` prefix, so
  /// the pack's full `assets/age2/...` path has to lose that first segment.
  static String _relative(String path) =>
      path.startsWith('assets/') ? path.substring('assets/'.length) : path;

  final String? correctSound;
  final String? wrongSound;

  final AudioPlayer _prompt = AudioPlayer();
  final AudioPlayer _effects = AudioPlayer();
  bool _disposed = false;

  StreamSubscription<PlayerState>? _promptState;
  bool _ducking = false;

  /// Holds the music down while the prompt player is speaking and lets it
  /// back up when it stops, whether it finished, was cut off by the next
  /// prompt, or the screen went away.
  void _followPrompt(PlayerState state) {
    _setDucking(state == PlayerState.playing);
  }

  void _setDucking(bool value) {
    if (_ducking == value) return;
    _ducking = value;
    if (value) {
      AppSound.instance.duck();
    } else {
      AppSound.instance.unduck();
    }
  }

  Future<void> playPrompt(String? assetPath) => _play(_prompt, assetPath);

  Future<void> playCorrect() => _play(_effects, correctSound);

  Future<void> playWrong() => _play(_effects, wrongSound);

  /// Used by the story component, which needs to know where the narration has
  /// got to in order to change the picture in time with it.
  AudioPlayer get narrationPlayer => _prompt;

  Future<void> stopPrompt() async {
    if (_disposed) return;
    try {
      await _prompt.stop();
    } on Exception {
      // Nothing was playing.
    }
  }

  Future<void> _play(AudioPlayer player, String? assetPath) async {
    if (_disposed || assetPath == null || assetPath.isEmpty) return;
    if (!AssetAvailability.instance.has(assetPath)) {
      debugPrint('ActivityAudio: skipping missing sound $assetPath');
      return;
    }
    try {
      await player.stop();
      await player.play(AssetSource(_relative(assetPath)));
    } on Exception catch (error) {
      debugPrint('ActivityAudio: could not play $assetPath ($error)');
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    // Before the subscription goes, or a screen closed mid-sentence leaves the
    // bed ducked for the rest of the session.
    _setDucking(false);
    await _promptState?.cancel();
    await _prompt.dispose();
    await _effects.dispose();
  }
}
