import '../../data/seed_content.dart';
import '../../models/ai_level_draft.dart';
import '../../models/learning_level.dart';
import 'ai_level_codec.dart';
import 'content_draft_validator.dart';
import 'llm_client.dart';

/// Writes the messages sent to the model.
///
/// Three things do the work here, in increasing order of how much they help:
/// the schema, the rules for the one level type being asked for, and two
/// worked examples taken from content the app already ships. The examples
/// matter most — `matching` levels, where the card titles silently become the
/// answer options, are close to impossible to infer from a schema and obvious
/// from a single real example.
class LevelPromptBuilder {
  const LevelPromptBuilder({this.codec = const AiLevelCodec()});

  final AiLevelCodec codec;

  /// How many real levels to show. Two is enough to establish the shape
  /// without turning every request into a long prompt.
  static const exampleCount = 2;

  List<LlmMessage> build(AiGenerationRequest request) => [
        LlmMessage.system(systemPrompt(request)),
        LlmMessage.user(userMessage(request)),
      ];

  String systemPrompt(AiGenerationRequest request) {
    final examples = examplesFor(request);

    return '''
You write learning content for an app used by children aged 1 to 4. They
cannot read. A grown-up sits with them and reads every prompt aloud.

Reply with one JSON object and nothing else. It has exactly this shape:

{
  "levels": [
    {
      "title": "short name for the level",
      "subtitle": "one line saying what the child will do",
      "passingScore": 60,
      "contentItems": [
        {
          "title": "what this card is",
          "prompt": "the sentence a grown-up reads aloud",
          "displayText": "the big thing shown on the card",
          "visualLabel": "a description of the picture"
        }
      ],
      "quizQuestions": [
        {
          "prompt": "the question",
          "options": ["first answer", "second answer"],
          "correctIndex": 0,
          "explanation": "why that answer is right"
        }
      ]
    }
  ]
}

${_rulesFor(request)}

Never do any of these. Each one breaks the app:
- Do not reply with a bare array. The top level is an object with "levels".
- Do not add a "type" field. The level type is already decided.
- Do not put "displayText" on a level. It belongs on each card.
- Do not write "question" for a quiz. The field is "prompt".
- Do not make options into objects, and do not use "isCorrect". "options" is
  a flat list of plain strings and "correctIndex" is a number pointing into
  that list.
- Do not send "id", "levelId", "moduleId", "stage", "levelNumber",
  "portionLabel", "isBundled" or "audioCueKey". All of those are filled in
  for you and anything you send is discarded.
- Do not wrap the JSON in markdown fences, and do not write anything before
  or after it.
- Every card needs all four of title, prompt, displayText and visualLabel.
  None of them may be empty.

Here are ${examples.length} real levels from the app, written in exactly the
shape you must reply in:

${codec.encodeEnvelope(examples)}
''';
  }

  /// Only the rules for the type being asked for.
  ///
  /// Showing all seven would be longer, more expensive, and would give the
  /// model six sets of constraints it could accidentally apply.
  String _rulesFor(AiGenerationRequest request) {
    final canvasBand =
        '${ContentDraftValidator.canvasMinPassingScore} and '
        '${ContentDraftValidator.canvasMaxPassingScore}';

    return switch (request.type) {
      LevelType.flashcards => '''
These are flashcard levels. Each card shows one thing and the grown-up says
it aloud. "displayText" is the letter, word or number on the card.
passingScore should be between 55 and 70.''',
      LevelType.counting => '''
These are counting levels. The child taps until they reach a number.
"displayText" must be the digits of that number and nothing else: "3", never
"three" and never "3 apples". Keep every target at 12 or below.
passingScore should be between 55 and 70.''',
      LevelType.matching => '''
These are matching levels. The child picks the right answer from a list, and
that list is built from the "title" of every card in the level. So the titles
are the answer options: give each level at least 2 cards with different
titles, and make the titles short enough to fit on a button.
passingScore should be between 55 and 70.''',
      LevelType.story => '''
These are story levels. Each card is one page. "prompt" is the sentence read
aloud and "displayText" is a very short line the child sees.
passingScore should be between 55 and 70.''',
      LevelType.drawing => '''
These are drawing levels. The child draws on a blank canvas and a grown-up
grades the result, so each card is one step of the same picture.
passingScore MUST be between $canvasBand.''',
      LevelType.tracing => '''
These are tracing levels. Each card shows one character as a dotted guide the
child traces over. "displayText" must be EXACTLY ONE character: "A", never
"AB", never "A B". It must be a Latin letter, a digit, or an Urdu letter,
because those are the only ones the app has a font to draw.
passingScore MUST be between $canvasBand.''',
      LevelType.video => '''
These are video levels. Each level needs a "videoLessons" list with a real,
working https:// link to a video file. Never invent a URL. If you do not have
a real one, say so instead of guessing.
Never write a path beginning "assets/". Those name files shipped inside the
app, and you cannot add one, so the lesson would open to nothing.
passingScore should be between 55 and 70.''',
    };
  }

  /// Two real levels, chosen to be as close to the request as the shipped
  /// content allows: same type first, then same module, then same script.
  ///
  /// Taken from `seedLevels` rather than written by hand, and rendered by the
  /// same codec that defines the schema, so an example cannot drift away from
  /// what the decoder accepts.
  List<LearningLevel> examplesFor(AiGenerationRequest request) {
    final wantsUrdu = request.moduleId == 'urdu';

    int score(LearningLevel level) {
      var points = 0;
      if (level.type == request.type) points += 4;
      if (level.moduleId == request.moduleId) points += 2;
      if ((level.moduleId == 'urdu') == wantsUrdu) points += 1;
      // A level with a quiz shows more of the schema than one without.
      if (level.quizQuestions.isNotEmpty) points += 1;
      return points;
    }

    final ranked = [...seedLevels]..sort((a, b) {
        final diff = score(b) - score(a);
        return diff != 0 ? diff : a.id.compareTo(b.id);
      });

    return ranked.take(exampleCount).toList();
  }

  String userMessage(AiGenerationRequest request) {
    final lines = <String>[
      'Module: ${request.moduleId} ("${request.moduleTitle}")',
      'Stage: ${request.stage} of 4, for children around '
          '${request.stage} year${request.stage == 1 ? '' : 's'} old.',
      'Generate exactly ${request.levelCount} '
          'level${request.levelCount == 1 ? '' : 's'}, which will be numbered '
          '${request.firstLevelNumber} to ${request.lastLevelNumber} in order.',
    ];

    if (request.existingTitles.isNotEmpty) {
      lines.add(
        'This stage already covers: '
        '${request.existingTitles.map((t) => '"$t"').join(', ')}.',
      );
      if (request.existingPortions.isNotEmpty) {
        lines.add(
          'Those levels covered: ${request.existingPortions.join(', ')}.',
        );
      }
      lines.add('Carry on from there. Do not repeat what is already covered.');
    } else {
      lines.add('This stage is empty, so start at the beginning.');
    }

    lines.add(
      request.moduleId == 'urdu'
          ? 'Write every title, subtitle, prompt and answer option in Urdu '
              'script. The app lays this module out right to left.'
          : 'Write everything in simple English.',
    );

    final guidance = request.guidance.trim();
    lines.add(guidance.isEmpty
        ? 'The admin added no extra instructions.'
        : 'Extra instructions from the admin: $guidance');

    return lines.join('\n');
  }

  /// Sent when the reply could not be read at all.
  String repairForUnreadableReply(String problem) => '''
$problem

Reply again with ONLY the JSON object described earlier. Start with { and end
with }. No markdown fences, no explanation, nothing before or after it.''';

  /// Sent when the reply parsed but broke the rules.
  ///
  /// Carries the errors and nothing else — no restated schema, no scolding —
  /// because the system prompt and the examples are still in the conversation
  /// above it. Naming the levels that were already right matters as much as
  /// naming the broken ones: without it, a model tends to rewrite everything
  /// and break something that previously worked.
  String repairForIssues(
    List<DraftIssue> issues, {
    required int levelCount,
    required Set<int> correctLevelNumbers,
  }) {
    final problems = issues
        .where((issue) => issue.isBlocking)
        .map((issue) => '- ${issue.path}: ${issue.message}\n  ${issue.modelHint}')
        .join('\n');

    final buffer = StringBuffer()
      ..writeln('${issues.where((i) => i.isBlocking).length} problem(s). '
          'Return the WHOLE object again, with all $levelCount levels, '
          'fixing only these:')
      ..writeln()
      ..writeln(problems);

    if (correctLevelNumbers.isNotEmpty) {
      final list = (correctLevelNumbers.toList()..sort()).join(', ');
      buffer
        ..writeln()
        ..writeln('Level $list ${correctLevelNumbers.length == 1 ? 'was' : 'were'} '
            'correct. Return ${correctLevelNumbers.length == 1 ? 'it' : 'them'} '
            'unchanged.');
    }

    return buffer.toString();
  }
}
