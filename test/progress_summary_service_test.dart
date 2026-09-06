import 'package:flutter_test/flutter_test.dart';
import 'package:little_learners/models/child_profile.dart';
import 'package:little_learners/services/ai/fake_llm_client.dart';
import 'package:little_learners/services/ai/llm_client.dart';
import 'package:little_learners/services/insights/child_insights.dart';
import 'package:little_learners/services/insights/progress_summary_service.dart';
import 'package:little_learners/services/insights/progress_summary_store.dart';

final now = DateTime(2026, 9, 6);

ChildInsights insights({
  int completed = 5,
  int stars = 9,
  List<Insight> findings = const [],
}) {
  const math = ModuleInsight(
    moduleId: 'math',
    moduleTitle: 'Math',
    levelsAvailable: 4,
    levelsCompleted: 4,
    levelsAttempted: 4,
    starsEarned: 4,
    averageScore: 62,
    lastPlayedAt: null,
  );
  const english = ModuleInsight(
    moduleId: 'english',
    moduleTitle: 'English',
    levelsAvailable: 4,
    levelsCompleted: 1,
    levelsAttempted: 1,
    starsEarned: 3,
    averageScore: null,
    lastPlayedAt: null,
  );

  return ChildInsights(
    profile: ChildProfile(
      id: 'c1',
      parentId: 'p1',
      name: 'Ayesha',
      age: 3,
      avatarAsset: 'a.png',
      leaderboardOptIn: false,
      displayPreference: 'en',
      createdAt: now,
      updatedAt: now,
      isSynced: true,
    ),
    stage: 3,
    modules: const [math, english],
    findings: findings.isEmpty
        ? const [
            Insight(
              kind: InsightKind.needsPractice,
              moduleId: 'math',
              moduleTitle: 'Math',
              headline: 'Math needs another go',
              detail: 'Math is getting through on 4 of 12 stars.',
            ),
          ]
        : findings,
    totalStars: stars,
    completedLevels: completed,
    availableLevels: 8,
    averageScore: 62,
    lastActiveAt: now,
    levelsCompletedThisWeek: 2,
    nextUp: english,
  );
}

ProgressSummaryService serviceWith(List<Object> replies,
        {ProgressSummaryStore? store}) =>
    ProgressSummaryService(
      client: FakeLlmClient(replies),
      store: store ?? InMemoryProgressSummaryStore(),
    );

const goodReply = '{"summary":"Ayesha is doing nicely with English and '
    'enjoys her stars. Math has been finished but could do with another '
    'pass.","suggestions":["Play the Math lessons again together.",'
    '"Try one English lesson this week."]}';

void main() {
  group('what the model is told', () {
    test('it gets the findings, not raw progress rows', () {
      final described = serviceWith([goodReply]).describe(insights());

      expect(described, contains('Ayesha'));
      expect(described, contains('What the app has concluded'));
      expect(described, contains('Math is getting through on 4 of 12 stars.'));
      expect(described, contains('Math: 4 of 4 finished'));
      expect(described, contains('Suggested next subject: English.'));
    });

    test('it is told what has not been opened', () {
      final described = serviceWith([goodReply]).describe(insights());
      expect(described, contains('Lessons finished in the last week: 2.'));
    });
  });

  group('generating', () {
    test('a well-formed reply becomes a summary and suggestions', () async {
      final summary = await serviceWith([goodReply]).generate(insights());

      expect(summary.summary, contains('Ayesha'));
      expect(summary.suggestions, hasLength(2));
      expect(summary.childId, 'c1');
      expect(summary.fingerprint, insights().fingerprint);
    });

    test('prose that is not JSON is still shown rather than discarded',
        () async {
      final summary = await serviceWith(
        ['Ayesha is getting on well and enjoys her stars.'],
      ).generate(insights());

      expect(summary.summary, 'Ayesha is getting on well and enjoys her stars.');
      // The findings can always supply advice even when the model did not.
      expect(summary.suggestions, isNotEmpty);
    });

    test('an empty summary field falls back to the raw reply', () async {
      final summary = await serviceWith(
        ['{"summary":"   ","suggestions":[]}'],
      ).generate(insights());

      expect(summary.summary, isNotEmpty);
      expect(summary.suggestions, isNotEmpty);
    });

    test('a failing model is not swallowed here', () async {
      final service = serviceWith([
        const LlmException(LlmFailure.unauthorized, 'Bad key.'),
      ]);

      expect(
        () => service.generate(insights()),
        throwsA(isA<LlmException>()),
      );
    });
  });

  group('caching', () {
    test('a summary is reused while it is still true', () async {
      final store = InMemoryProgressSummaryStore();
      final service = serviceWith([goodReply], store: store);

      await service.generate(insights());
      final cached = await service.cachedFor(insights());

      expect(cached, isNotNull);
      expect(cached!.summary, contains('Ayesha'));
    });

    test('it is dropped the moment the child makes progress', () async {
      final store = InMemoryProgressSummaryStore();
      final service = serviceWith([goodReply], store: store);

      await service.generate(insights());

      // One more level finished: the stored paragraph is now out of date.
      final cached = await service.cachedFor(insights(completed: 6));
      expect(cached, isNull,
          reason: 'a stale summary must not be shown as current');
    });

    test('nothing cached for a child who has never had one', () async {
      final service = serviceWith([goodReply]);
      expect(await service.cachedFor(insights()), isNull);
    });
  });

  test('the store round-trips a summary through its map form', () {
    final original = ProgressSummary(
      childId: 'c1',
      fingerprint: 'fp',
      summary: 'Doing well.',
      suggestions: const ['One thing', 'Another'],
      generatedAt: now,
    );

    final restored = ProgressSummary.fromMap(original.toMap());

    expect(restored, isNotNull);
    expect(restored!.summary, 'Doing well.');
    expect(restored.suggestions, ['One thing', 'Another']);
    expect(restored.fingerprint, 'fp');
    expect(restored.matches('fp'), isTrue);
    expect(restored.matches('other'), isFalse);
  });
}
