import 'package:flutter_test/flutter_test.dart';
import 'package:little_learners/data/seed_content.dart';
import 'package:little_learners/models/learning_level.dart';
import 'package:little_learners/services/ai/ai_level_codec.dart';

const codec = AiLevelCodec();

void main() {
  group('finding the JSON in a reply', () {
    test('a bare object', () {
      expect(AiLevelCodec.extractJsonObject('{"a":1}'), '{"a":1}');
    });

    test('wrapped in a markdown fence', () {
      const reply = '```json\n{"a":1}\n```';
      expect(AiLevelCodec.extractJsonObject(reply), '{"a":1}');
    });

    test('with an apology before it and an explanation after', () {
      const reply = 'Sure! Here are the levels:\n\n{"a":1}\n\n'
          'Let me know if you want changes.';
      expect(AiLevelCodec.extractJsonObject(reply), '{"a":1}');
    });

    test('nested braces are balanced, not stopped at the first close', () {
      const reply = '{"a":{"b":{"c":1}},"d":2}';
      expect(AiLevelCodec.extractJsonObject(reply), reply);
    });

    test('a closing brace inside a string does not end the object', () {
      const reply = '{"a":"} not the end","b":1}';
      expect(AiLevelCodec.extractJsonObject(reply), reply);
    });

    test('an escaped quote does not end the string', () {
      const reply = r'{"a":"say \"hi\" now","b":1}';
      expect(AiLevelCodec.extractJsonObject(reply), reply);
    });

    test('no object at all returns null', () {
      expect(AiLevelCodec.extractJsonObject('I cannot help with that.'),
          isNull);
      expect(AiLevelCodec.extractJsonObject('{"unbalanced":1'), isNull);
    });
  });

  group('round trip against content the app already ships', () {
    test('a real level survives encode then decode', () {
      // Needs a quiz on it, or the quiz half of the round trip proves nothing.
      final original = seedLevels.firstWhere(
        (l) => l.type == LevelType.counting && l.quizQuestions.isNotEmpty,
      );

      final payload =
          codec.decodeEnvelope(codec.encodeEnvelope([original])).single;

      expect(payload.title, original.title);
      expect(payload.subtitle, original.subtitle);
      expect(payload.passingScore, original.passingScore);
      expect(payload.contentItems.length, original.contentItems.length);
      expect(payload.contentItems.first.displayText,
          original.contentItems.first.displayText);
      expect(payload.quizQuestions.length, original.quizQuestions.length);
      expect(payload.quizQuestions.first.correctIndex,
          original.quizQuestions.first.correctIndex);
      expect(payload.quizQuestions.first.options,
          original.quizQuestions.first.options);
    });

    test('an Urdu level keeps its script through the round trip', () {
      final original = seedLevels.firstWhere((l) => l.moduleId == 'urdu');
      final payload =
          codec.decodeEnvelope(codec.encodeEnvelope([original])).single;

      expect(payload.title, original.title);
      expect(payload.contentItems.first.displayText,
          original.contentItems.first.displayText);
    });

    test('a video level survives', () {
      final original = seedLevels.firstWhere((l) => l.type == LevelType.video);
      final payload =
          codec.decodeEnvelope(codec.encodeEnvelope([original])).single;

      expect(payload.videoLessons.single.videoUrl,
          original.videoLessons.single.videoUrl);
      expect(payload.videoLessons.single.durationLabel,
          original.videoLessons.single.durationLabel);
    });
  });

  group('what an example never shows the model', () {
    test('encode strips every field the app computes itself', () {
      final tracing = seedLevels.firstWhere(
        (l) => l.type == LevelType.tracing && l.portionLabel != null,
      );
      final encoded = codec.encodeLevel(tracing);

      for (final forbidden in [
        'id',
        'levelId',
        'moduleId',
        'stage',
        'levelNumber',
        'portionLabel',
        'isBundled',
        'type',
        'levelType',
      ]) {
        expect(encoded.containsKey(forbidden), isFalse,
            reason: 'an example must never show the model a $forbidden');
      }

      // The seed level this came from does carry audio cues; the example
      // must not, or the model will invent cue keys for assets that do not
      // exist.
      expect(tracing.contentItems.first.audioCueKey, isNotNull);
      final items = encoded['contentItems']! as List;
      expect((items.first as Map).containsKey('audioCueKey'), isFalse);
    });

    test('empty child lists are omitted rather than shown as empty', () {
      final noQuiz =
          seedLevels.firstWhere((l) => l.quizQuestions.isEmpty);
      final encoded = codec.encodeLevel(noQuiz);
      expect(encoded.containsKey('quizQuestions'), isFalse);
      expect(encoded.containsKey('videoLessons'), isFalse);
    });
  });

  group('decoding a reply that is wrong', () {
    test('no JSON at all', () {
      expect(
        () => codec.decodeEnvelope('I am sorry, I cannot do that.'),
        throwsA(isA<AiDecodeException>()),
      );
    });

    test('valid JSON but no levels array', () {
      expect(
        () => codec.decodeEnvelope('{"result":"ok"}'),
        throwsA(isA<AiDecodeException>()),
      );
    });

    test('a level that is not an object', () {
      expect(
        () => codec.decodeEnvelope('{"levels":["a level"]}'),
        throwsA(isA<AiDecodeException>()),
      );
    });

    test('missing text fields decode as empty, for the validator to reject',
        () {
      final payload = codec.decodeEnvelope('{"levels":[{"title":"Only"}]}').single;

      expect(payload.title, 'Only');
      expect(payload.subtitle, isEmpty);
      expect(payload.contentItems, isEmpty);
      expect(payload.passingScore, 70);
    });

    test('fields the app owns are ignored rather than fought over', () {
      final payload = codec.decodeEnvelope(
        '{"levels":[{"title":"A","subtitle":"B","id":"nonsense",'
        '"moduleId":"wrong","portionLabel":"X - Y","levelNumber":99}]}',
      ).single;

      expect(payload.title, 'A');
      expect(payload.subtitle, 'B');
    });

    test('a numeric field sent as a string is still read', () {
      final payload = codec
          .decodeEnvelope('{"levels":[{"title":"A","passingScore":"65"}]}')
          .single;
      expect(payload.passingScore, 65);
    });
  });
}
