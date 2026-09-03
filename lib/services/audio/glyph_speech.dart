import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

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

  /// Speaks [text]. [urdu] picks the voice, not the script.
  Future<void> speak(String text, {bool urdu = false}) async {
    if (_broken || text.isEmpty) return;
    await _prepare(urdu: urdu);
    if (!_ready) return;
    try {
      await _tts.stop();
      await _tts.speak(text);
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
