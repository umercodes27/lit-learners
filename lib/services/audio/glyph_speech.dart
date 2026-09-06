import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'sound_controller.dart';

/// Says a letter or numeral out loud.
///
/// The age-3 tracing levels cover A-Z, Alif-to-Yay and 1-10 — some sixty
/// glyphs. Recording a clip for each is a lot of studio time for content that
/// is one spoken syllable, so the device speaks them instead and the pack only
/// ships the handful of clips that already existed.
///
/// A recorded clip still wins where one exists: a real voice is warmer, and
/// Urdu letter names are exactly the kind of thing a general-purpose engine
/// mispronounces. This is the fallback, not the default.
///
/// Every call is best-effort. Text-to-speech is missing or muted on plenty of
/// devices, and a tracing level has to stay playable in silence.
class GlyphSpeech {
  GlyphSpeech({FlutterTts? engine}) : _tts = engine ?? FlutterTts();

  final FlutterTts _tts;
  bool _ready = false;
  bool _broken = false;

  /// Urdu letters are spoken by name rather than as script, because the
  /// engines that do have an Urdu voice read a lone glyph unreliably, and the
  /// names are what a teacher says aloud anyway.
  static const _urduVoiceLocale = 'ur-PK';
  static const _latinVoiceLocale = 'en-US';

  Future<void> _prepare({required bool urdu}) async {
    if (_broken) return;
    try {
      await _tts.setLanguage(urdu ? _urduVoiceLocale : _latinVoiceLocale);
      // Slower than default: a two-year-old is matching a sound to a shape.
      await _tts.setSpeechRate(0.4);
      await _tts.setPitch(1.1);
      // Makes `speak` wait until the words are actually finished, which is
      // what lets the music come back at the right moment instead of the
      // moment speaking started. Not supported on every platform, hence the
      // timeout below rather than a promise that it works.
      await _tts.awaitSpeakCompletion(true);
      _ready = true;
    } on Exception catch (error) {
      _broken = true;
      debugPrint('GlyphSpeech: engine unavailable ($error)');
    } on Object catch (error) {
      // Some platform channels throw plain errors rather than exceptions.
      _broken = true;
      debugPrint('GlyphSpeech: engine unavailable ($error)');
    }
  }

  /// The longest a single glyph can hold the music down.
  ///
  /// One letter at the rate set above takes about a second. If the engine
  /// never reports completion — some platforms ignore
  /// `awaitSpeakCompletion` — the bed comes back anyway rather than staying
  /// quiet for the rest of the session.
  static const _longestUtterance = Duration(seconds: 5);

  /// Speaks [text]. [urdu] picks the voice, not the script.
  Future<void> speak(String text, {bool urdu = false}) async {
    if (_broken || text.isEmpty) return;
    await _prepare(urdu: urdu);
    if (!_ready) return;
    try {
      await _tts.stop();
      // A spoken letter is the entire point of a tracing level, and it is one
      // syllable competing with a music bed. The bed comes down for it, the
      // same as for every other voice in the app.
      await AppSound.instance.duck();
      try {
        await _tts.speak(text).timeout(_longestUtterance, onTimeout: () {});
      } finally {
        await AppSound.instance.unduck();
      }
    } on Exception catch (error) {
      debugPrint('GlyphSpeech: could not speak "$text" ($error)');
    } on Object catch (error) {
      debugPrint('GlyphSpeech: could not speak "$text" ($error)');
    }
  }

  Future<void> stop() async {
    if (_broken) return;
    try {
      await _tts.stop();
    } on Object {
      // Nothing was speaking.
    }
  }
}
