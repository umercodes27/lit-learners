import 'package:flutter_test/flutter_test.dart';
import 'package:little_learners/data/seed_content.dart';
import 'package:little_learners/models/ai_level_draft.dart';
import 'package:little_learners/models/learning_level.dart';
import 'package:little_learners/models/learning_module.dart';
import 'package:little_learners/services/ai/ai_level_codec.dart';
import 'package:little_learners/services/ai/level_prompt_builder.dart';
import 'package:little_learners/services/ai/llm_client.dart';

const builder = LevelPromptBuilder();

AiGenerationRequest request({
  String moduleId = 'urdu',
  ModuleCategory category = ModuleCategory.urdu,
  LevelType type = LevelType.tracing,
  int stage = 2,
  int levelCount = 5,
  int firstLevelNumber = 4,
  String guidance = '',
  List<String> existingTitles = const [],
}) =>
    AiGenerationRequest(
      moduleId: moduleId,
      moduleTitle: 'اردو',
      category: category,
      stage: stage,
      levelCount: levelCount,
      type: type,
      firstLevelNumber: firstLevelNumber,
      guidance: guidance,
      existingTitles: existingTitles,
    );

void main() {
  group('the prohibitions match what a model actually gets wrong', () {
    // Each of these was observed in a real DeepSeek reply before the prompt
    // named it. They are cheap to state and expensive to repair, so a
    // regression here would cost real money on every generation.
    late String prompt;
    setUp(() => prompt = builder.systemPrompt(request()));

    test('it forbids a bare array instead of the levels envelope', () {
      expect(prompt, contains('bare array'));
      expect(prompt, contains('"levels"'));
    });

    test('it forbids inventing a type field', () {
      expect(prompt, contains('Do not add a "type" field'));
    });

    test('it forbids displayText on the level', () {
      expect(prompt, contains('Do not put "displayText" on a level'));
    });

    test('it names the quiz field prompt, not question', () {
      expect(prompt, contains('The field is "prompt"'));
    });

    test('it forbids option objects and isCorrect', () {
      expect(prompt, contains('isCorrect'));
      expect(prompt, contains('flat list of plain strings'));
    });

    test('it forbids every field the app computes for itself', () {
      for (final field in [
        'moduleId',
        'levelNumber',
        'portionLabel',
        'isBundled',
        'audioCueKey',
      ]) {
        expect(prompt, contains(field), reason: 'must forbid $field');
      }
    });
  });

  group('only the rules for the type being asked for', () {
    test('a tracing request states the one-character rule', () {
      final prompt = builder.systemPrompt(request(type: LevelType.tracing));
      expect(prompt, contains('EXACTLY ONE character'));
      expect(prompt, isNot(contains('never "three"')),
          reason: 'counting rules are noise on a tracing request');
    });

    test('a counting request states the digits rule and not the glyph rule',
        () {
      final prompt = builder.systemPrompt(request(type: LevelType.counting));
      expect(prompt, contains('digits of that number'));
      expect(prompt, isNot(contains('EXACTLY ONE character')));
    });

    test('a matching request explains that titles become the options', () {
      final prompt = builder.systemPrompt(request(type: LevelType.matching));
      expect(prompt, contains('are the answer options'));
    });

    test('canvas types carry the derived passing band', () {
      for (final type in [LevelType.drawing, LevelType.tracing]) {
        expect(builder.systemPrompt(request(type: type)),
            contains('MUST be between 46 and 70'),
            reason: type.name);
      }
    });

    test('every level type produces rules of its own', () {
      final seen = <String>{};
      for (final type in LevelType.values) {
        final prompt = builder.systemPrompt(request(type: type));
        expect(prompt, isNotEmpty);
        seen.add(prompt);
      }
      expect(seen, hasLength(LevelType.values.length),
          reason: 'no two types may share a rules block');
    });
  });

  group('worked examples', () {
    test('they are real levels from the app, not invented', () {
      final examples = builder.examplesFor(request());
      expect(examples, hasLength(LevelPromptBuilder.exampleCount));
      for (final example in examples) {
        expect(seedLevels, contains(example));
      }
    });

    test('an Urdu tracing request is shown Urdu tracing content', () {
      final examples = builder.examplesFor(request(type: LevelType.tracing));
      expect(examples.first.type, LevelType.tracing);
    });

    test('the examples never leak a field the model must not send', () {
      // Checked against the rendered examples rather than the whole prompt:
      // the prohibition list names these fields too, so searching the prompt
      // would match the very sentence forbidding them.
      final rendered =
          const AiLevelCodec().encodeEnvelope(builder.examplesFor(request()));

      for (final leak in [
        'levelId',
        'audioCueKey',
        'isBundled',
        'moduleId',
        'portionLabel',
      ]) {
        expect(rendered, isNot(contains(leak)), reason: 'leaked $leak');
      }
    });
  });

  group('the user message', () {
    test('it states the exact numbering the app will assign', () {
      final message = builder.userMessage(request());
      expect(message, contains('exactly 5 levels'));
      expect(message, contains('numbered 4 to 8'));
    });

    test('an Urdu module is told to write in Urdu script', () {
      expect(builder.userMessage(request()), contains('Urdu script'));
    });

    test('a non-Urdu module is told to write in English', () {
      final message = builder.userMessage(
        request(moduleId: 'math', category: ModuleCategory.math),
      );
      expect(message, contains('simple English'));
    });

    test('existing titles are listed so the ladder continues', () {
      final message = builder.userMessage(
        request(existingTitles: ['حرف ا', 'حرف ب']),
      );
      expect(message, contains('حرف ا'));
      expect(message, contains('Carry on from there'));
    });

    test('an empty stage says so instead of listing nothing', () {
      expect(builder.userMessage(request()), contains('stage is empty'));
    });

    test('admin guidance is passed through untouched', () {
      final message =
          builder.userMessage(request(guidance: 'Use animals, not fruit.'));
      expect(message, contains('Use animals, not fruit.'));
    });
  });

  test('build produces a system message then a user message', () {
    final messages = builder.build(request());
    expect(messages, hasLength(2));
    expect(messages.first.role, LlmRole.system);
    expect(messages.last.role, LlmRole.user);
  });
}
