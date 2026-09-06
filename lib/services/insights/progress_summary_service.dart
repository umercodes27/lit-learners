import 'dart:convert';

import '../ai/ai_level_codec.dart';
import '../ai/llm_client.dart';
import 'child_insights.dart';
import 'progress_summary_store.dart';

/// Writes a parent a few sentences about how their child is doing.
///
/// The model is given the findings, never the raw progress rows, so it is
/// putting words around an analysis the app already stands behind rather than
/// drawing its own conclusions from numbers. If the model is unavailable the
/// findings are still there and the report still works — this makes the
/// report warmer, it does not make it possible.
class ProgressSummaryService {
  const ProgressSummaryService({
    required LlmClient client,
    required ProgressSummaryStore store,
  })  : _client = client,
        _store = store;

  final LlmClient _client;
  final ProgressSummaryStore _store;

  /// A stored summary, but only while it is still true of this child.
  Future<ProgressSummary?> cachedFor(ChildInsights insights) async {
    final stored = await _store.read(insights.profile.id);
    if (stored == null) return null;
    return stored.matches(insights.fingerprint) ? stored : null;
  }

  Future<ProgressSummary> generate(ChildInsights insights) async {
    final completion = await _client.complete(
      LlmCompletionRequest(
        messages: [
          const LlmMessage.system(_systemPrompt),
          LlmMessage.user(describe(insights)),
        ],
        // Lower than content generation. This is a factual note to a parent
        // about their own child, not somewhere to be inventive.
        temperature: 0.3,
        maxTokens: 700,
      ),
    );

    final parsed = _parse(completion.text, insights);
    await _store.write(parsed);
    return parsed;
  }

  static const _systemPrompt = '''
You write a short note to a parent about how their young child is getting on
with a learning app. The child is between one and four years old.

You will be given findings the app has already worked out. Put them into
words. Do not invent progress, subjects, scores or behaviour that is not in
the findings, and do not guess at why a child is doing well or badly.

Write warmly and plainly, the way a good nursery teacher speaks to a parent.
No jargon, no percentages, no bullet symbols in the summary itself. Two or
three short sentences at most. Say something true and good before anything
that needs work.

These are very young children. Never suggest a child is behind, slow, or
should be compared with anyone else.

Reply with one JSON object and nothing else:

{
  "summary": "two or three sentences to the parent",
  "suggestions": ["something to try", "something else to try"]
}

Give two or three suggestions. Each one is a single short sentence naming
something a parent can actually do this week.''';

  /// The findings, written out for the model.
  ///
  /// Public so a test can assert what the model is and is not told — in
  /// particular that it receives the analysis rather than raw progress rows
  /// it might interpret differently from the report shown alongside it.
  String describe(ChildInsights insights) {
    final buffer = StringBuffer()
      ..writeln('Child: ${insights.profile.name}, age '
          '${insights.profile.age}.')
      ..writeln('Finished ${insights.completedLevels} of '
          '${insights.availableLevels} lessons available at their level.')
      ..writeln('Stars: ${insights.totalStars} of '
          '${insights.totalStarsPossible}.');

    if (insights.averageScore != null) {
      buffer.writeln('Average quiz score: ${insights.averageScore}.');
    }
    buffer.writeln(
      'Lessons finished in the last week: ${insights.levelsCompletedThisWeek}.',
    );

    buffer.writeln('\nBy subject:');
    for (final module in insights.modules) {
      buffer.writeln(
        '- ${module.moduleTitle}: ${module.levelsCompleted} of '
        '${module.levelsAvailable} finished, ${module.starsEarned} of '
        '${module.starsPossible} stars'
        '${module.isStarted ? '' : ', never opened'}.',
      );
    }

    buffer.writeln('\nWhat the app has concluded:');
    for (final finding in insights.findings) {
      buffer.writeln('- ${finding.detail}');
    }

    final next = insights.nextUp;
    if (next != null) {
      buffer.writeln('\nSuggested next subject: ${next.moduleTitle}.');
    }

    return buffer.toString();
  }

  ProgressSummary _parse(String reply, ChildInsights insights) {
    final json = AiLevelCodec.extractJsonObject(reply);
    Object? decoded;
    if (json != null) {
      try {
        decoded = jsonDecode(json);
      } on FormatException {
        decoded = null;
      }
    }

    // A summary is prose, so unlike generated content there is nothing here
    // worth a repair round: if the JSON did not arrive, use the reply as the
    // summary and let the findings supply the suggestions. The parent gets
    // something useful either way.
    if (decoded is! Map) {
      return ProgressSummary(
        childId: insights.profile.id,
        fingerprint: insights.fingerprint,
        summary: reply.trim(),
        suggestions: _fallbackSuggestions(insights),
        generatedAt: DateTime.now(),
      );
    }

    final summary = (decoded['summary'] as String?)?.trim() ?? '';
    final suggestions = [
      for (final item in (decoded['suggestions'] as List? ?? const []))
        if (item is String && item.trim().isNotEmpty) item.trim(),
    ];

    return ProgressSummary(
      childId: insights.profile.id,
      fingerprint: insights.fingerprint,
      summary: summary.isEmpty ? reply.trim() : summary,
      suggestions:
          suggestions.isEmpty ? _fallbackSuggestions(insights) : suggestions,
      generatedAt: DateTime.now(),
    );
  }

  List<String> _fallbackSuggestions(ChildInsights insights) {
    final next = insights.nextUp;
    return [
      if (next != null) 'Try ${next.moduleTitle} together this week.',
      for (final finding in insights.findingsOf(InsightKind.needsPractice))
        'Play the ${finding.moduleTitle} lessons again rather than new ones.',
      if (insights.findingsOf(InsightKind.idle).isNotEmpty)
        'A few minutes is enough to get going again.',
    ];
  }
}
