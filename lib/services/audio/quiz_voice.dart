import 'dart:async';

import '../../core/localization/urdu_letters.dart';
import 'glyph_speech.dart';

/// Reads a quiz out loud.
///
/// A quiz is the one place in the app that was pure text. Every activity
/// speaks its prompt — the recorded clip where the pack has one, the device
/// voice where it does not — but both quizzes asked their question in writing
/// and waited for an answer from a child who cannot read. The words were there
/// for whoever was sitting next to them, not for the child.
///
/// This says the question instead, through the same [GlyphSpeech] the tracing
/// and word-building levels use, so a quiz sounds like the rest of the app
/// rather than like a form.
///
/// Only the question and the verdict are spoken. The options are not: reading
/// four of them aloud in turn makes a child wait through the answer they
/// already want to tap, and by the fourth they have forgotten the first.
class QuizVoice {
  QuizVoice({GlyphSpeech? speech}) : _speech = speech ?? GlyphSpeech();

  final GlyphSpeech _speech;

  /// The question already spoken, so a rebuild does not start it again.
  ///
  /// These pages rebuild on every tap — the answer grid, the confetti, the
  /// footer all watch the view model — and speaking from `build` without this
  /// would restart the sentence under the child's finger.
  String? _spokenFor;

  bool _disposed = false;

  /// Speaks [text] once for [questionId], and stays quiet on later calls for
  /// the same question.
  void askQuestion({
    required String questionId,
    required String? text,
    required bool urdu,
  }) {
    if (_spokenFor == questionId) return;
    _spokenFor = questionId;
    _say(text, urdu: urdu);
  }

  /// Says the question again on demand — the "Listen again" button.
  ///
  /// Deliberately not guarded by [_spokenFor]: asking twice is the entire
  /// point, and a child who missed it the first time gets it as often as they
  /// tap.
  void repeatQuestion({required String? text, required bool urdu}) {
    _say(text, urdu: urdu);
  }

  /// Speaks the answer feedback: "Well done", or which one was right.
  ///
  /// The verdict carries the teaching — especially the wrong-answer one, which
  /// is the only moment the quiz explains anything — so it is spoken in the
  /// language of the level rather than left as text above a moving timer.
  void sayVerdict(String text, {required bool urdu}) => _say(text, urdu: urdu);

  void _say(String? text, {required bool urdu}) {
    if (_disposed) return;
    final line = text?.trim();
    if (line == null || line.isEmpty) return;
    // Not awaited: speaking runs as long as the sentence takes, and the page
    // has a quiz to draw in the meantime. Failures are already swallowed by
    // [GlyphSpeech], which treats a missing engine as silence.
    unawaited(_speech.speak(line, urdu: urdu));
  }

  /// Whether [text] should be spoken by the Urdu voice.
  ///
  /// The level's own direction decides it, but a mixed pack can put an Urdu
  /// prompt inside a left-to-right level, so the script wins where it is
  /// unambiguous.
  static bool urduFor(String? text, {required bool levelIsRtl}) {
    if (text != null && UrduLetters.isUrduScript(text)) return true;
    return levelIsRtl;
  }

  Future<void> stop() => _speech.stop();

  Future<void> dispose() async {
    _disposed = true;
    await _speech.stop();
  }
}
