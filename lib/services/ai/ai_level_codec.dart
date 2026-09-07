import 'dart:convert';

import '../../models/ai_level_draft.dart';
import '../../models/content_item.dart';
import '../../models/learning_level.dart';

class AiDecodeException implements Exception {
  const AiDecodeException(this.message);

  /// Written to be shown to the admin *and* fed back to the model, so it says
  /// what is wrong in terms the model can act on.
  final String message;

  @override
  String toString() => message;
}

/// Translates between the app's level model and the flat JSON the model is
/// asked for.
///
/// The same encoder renders both the worked examples in the prompt and the
/// schema those examples are supposed to demonstrate, so the two cannot drift
/// apart as the schema changes.
class AiLevelCodec {
  const AiLevelCodec();

  /// Pulls the first balanced JSON object out of whatever the model replied.
  ///
  /// Models wrap JSON in markdown fences, apologise before it, and explain
  /// after it, all while having been told not to. Rather than forbid that
  /// harder, this just finds the object. Returns null when there is no
  /// balanced object at all.
  static String? extractJsonObject(String raw) {
    final start = raw.indexOf('{');
    if (start < 0) return null;

    var depth = 0;
    var inString = false;
    var escaped = false;

    for (var i = start; i < raw.length; i++) {
      final char = raw[i];

      if (escaped) {
        escaped = false;
        continue;
      }
      if (char == r'\' && inString) {
        escaped = true;
        continue;
      }
      if (char == '"') {
        inString = !inString;
        continue;
      }
      if (inString) continue;

      if (char == '{') {
        depth++;
      } else if (char == '}') {
        depth--;
        if (depth == 0) return raw.substring(start, i + 1);
      }
    }
    return null;
  }

  /// Decodes a whole reply into level payloads.
  ///
  /// Deliberately lenient about anything the app is going to overwrite —
  /// a stray `id`, `moduleId` or `portionLabel` is ignored rather than
  /// fought over — and strict about the shape it actually needs.
  List<AiLevelPayload> decodeEnvelope(String raw) {
    final json = extractJsonObject(raw);
    if (json == null) {
      throw const AiDecodeException(
        'The reply contained no JSON object at all.',
      );
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(json);
    } on FormatException catch (error) {
      throw AiDecodeException('The reply was not valid JSON: ${error.message}');
    }

    if (decoded is! Map<String, Object?>) {
      throw const AiDecodeException('The reply was not a JSON object.');
    }

    final levels = decoded['levels'];
    if (levels is! List) {
      throw const AiDecodeException(
        'The object has no "levels" array at the top level.',
      );
    }

    return [
      for (var i = 0; i < levels.length; i++) _level(levels[i], i),
    ];
  }

  AiLevelPayload _level(Object? raw, int index) {
    if (raw is! Map) {
      throw AiDecodeException('levels[$index] is not an object.');
    }
    final map = raw.cast<String, Object?>();

    return AiLevelPayload(
      title: _string(map['title']),
      subtitle: _string(map['subtitle']),
      // 70 matches the default the Firestore reader already applies to a
      // level document with no passing score.
      passingScore: _int(map['passingScore'], 70),
      contentItems: _list(map['contentItems'])
          .map((item) => ContentItem(
                title: _string(item['title']),
                prompt: _string(item['prompt']),
                displayText: _string(item['displayText']),
                visualLabel: _string(item['visualLabel']),
                // Never taken from the model: a cue key it invented would
                // resolve to an asset that does not exist.
              ))
          .toList(),
      quizQuestions: _list(map['quizQuestions'])
          .map((q) => AiQuizPayload(
                prompt: _string(q['prompt']),
                options: [
                  for (final option in _rawList(q['options']))
                    _string(option),
                ],
                correctIndex: _int(q['correctIndex'], 0),
                visualLabel: _stringOrNull(q['visualLabel']),
                explanation: _stringOrNull(q['explanation']),
              ))
          .toList(),
      videoLessons: _list(map['videoLessons'])
          .map((v) => AiVideoPayload(
                title: _string(v['title']),
                description: _string(v['description']),
                durationLabel: _string(v['durationLabel']),
                videoUrl: _string(v['videoUrl']),
                thumbnailLabel: _string(v['thumbnailLabel']),
              ))
          .toList(),
    );
  }

  List<Map<String, Object?>> _list(Object? value) => [
        for (final entry in _rawList(value))
          if (entry is Map) entry.cast<String, Object?>(),
      ];

  List<Object?> _rawList(Object? value) => value is List ? value : const [];

  String _string(Object? value) => value is String ? value.trim() : '';

  String? _stringOrNull(Object? value) {
    final text = _string(value);
    return text.isEmpty ? null : text;
  }

  int _int(Object? value, int fallback) {
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim()) ?? fallback;
    return fallback;
  }

  /// Renders a real level as the model is asked to write one.
  ///
  /// Everything the app computes is stripped out, so a worked example never
  /// shows the model a field it must not send. That is why examples are
  /// generated from `seedLevels` rather than written by hand: a hand-written
  /// example drifts, a rendered one cannot.
  Map<String, Object?> encodeLevel(LearningLevel level) {
    return {
      'title': level.title,
      'subtitle': level.subtitle,
      'passingScore': level.passingScore,
      if (level.contentItems.isNotEmpty)
        'contentItems': [
          for (final item in level.contentItems)
            {
              'title': item.title,
              'prompt': item.prompt,
              'displayText': item.displayText,
              'visualLabel': item.visualLabel,
            },
        ],
      if (level.quizQuestions.isNotEmpty)
        'quizQuestions': [
          for (final question in level.quizQuestions)
            {
              'prompt': question.prompt,
              'options': question.options,
              'correctIndex': question.correctIndex,
              if (question.visualLabel != null)
                'visualLabel': question.visualLabel,
              if (question.explanation != null)
                'explanation': question.explanation,
            },
        ],
      if (level.videoLessons.isNotEmpty)
        'videoLessons': [
          for (final lesson in level.videoLessons)
            {
              'title': lesson.title,
              'description': lesson.description,
              'durationLabel': lesson.durationLabel,
              'videoUrl': lesson.videoUrl,
              'thumbnailLabel': lesson.thumbnailLabel,
            },
        ],
    };
  }

  /// The full reply shape, ready to paste into a prompt as a worked example.
  String encodeEnvelope(List<LearningLevel> levels) {
    return const JsonEncoder.withIndent('  ').convert({
      'levels': [for (final level in levels) encodeLevel(level)],
    });
  }
}
