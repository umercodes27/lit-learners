import 'package:flutter_test/flutter_test.dart';
import 'package:little_learners/models/child_profile.dart';
import 'package:little_learners/models/learning_level.dart';
import 'package:little_learners/models/learning_module.dart';
import 'package:little_learners/models/parent_report.dart';
import 'package:little_learners/models/progress.dart';
import 'package:little_learners/services/insights/child_insights.dart';
import 'package:little_learners/services/insights/child_insights_builder.dart';

final fixedNow = DateTime(2026, 9, 6, 12);
final builder = ChildInsightsBuilder(clock: () => fixedNow);

ChildProfile child({int age = 3}) => ChildProfile(
      id: 'c1',
      parentId: 'p1',
      name: 'Ayesha',
      age: age,
      avatarAsset: 'a.png',
      leaderboardOptIn: false,
      displayPreference: 'en',
      createdAt: fixedNow,
      updatedAt: fixedNow,
      isSynced: true,
    );

LearningModule module(String id, String title) => LearningModule(
      id: id,
      title: title,
      description: '',
      category: ModuleCategory.values
          .firstWhere((c) => c.name == id, orElse: () => ModuleCategory.math),
      minStage: 1,
      maxStage: 4,
      order: 1,
    );

LearningLevel lvl(String moduleId, int number, {int stage = 3}) =>
    LearningLevel(
      id: '$moduleId-stage$stage-$number',
      moduleId: moduleId,
      stage: stage,
      levelNumber: number,
      title: '$moduleId $number',
      subtitle: '',
      type: LevelType.flashcards,
      passingScore: 60,
      isBundled: true,
    );

LevelProgressReport done(
  String levelId,
  String moduleId, {
  int stars = 3,
  int? score,
  bool completed = true,
  Duration ago = Duration.zero,
}) =>
    LevelProgressReport(
      progress: LevelProgress(
        childId: 'c1',
        moduleId: moduleId,
        levelId: levelId,
        completed: completed,
        starsEarned: stars,
        rewardEarned: false,
        updatedAt: fixedNow.subtract(ago),
        isSynced: true,
        score: score,
      ),
      levelTitle: levelId,
      moduleTitle: moduleId,
      levelType: LevelType.flashcards,
      watchedLessonTitles: const [],
    );

ChildInsights buildFor(
  List<LevelProgressReport> progress, {
  List<LearningModule>? modules,
  List<LearningLevel>? levels,
  int age = 3,
}) =>
    builder.build(
      report: ChildReport(profile: child(age: age), progressReports: progress),
      modules:
          modules ?? [module('math', 'Math'), module('english', 'English')],
      levels: levels ??
          [
            for (var n = 1; n <= 4; n++) lvl('math', n),
            for (var n = 1; n <= 4; n++) lvl('english', n),
          ],
    );

void main() {
  test('a child who has done nothing gets one honest finding', () {
    final insights = buildFor([]);

    expect(insights.hasStarted, isFalse);
    expect(insights.findings, hasLength(1));
    expect(insights.findings.single.kind, InsightKind.notStarted);
    expect(insights.completedLevels, 0);
    expect(insights.availableLevels, 8);
  });

  test('only levels the child can actually reach are counted', () {
    // A three-year-old is on stage 3. Stage 4 levels exist but must not make
    // this child look behind.
    final insights = buildFor(
      [done('math-stage3-1', 'math')],
      levels: [
        lvl('math', 1),
        lvl('math', 2),
        lvl('math', 1, stage: 4),
        lvl('math', 2, stage: 4),
        lvl('english', 1),
      ],
    );

    expect(insights.stage, 3);
    expect(insights.availableLevels, 3);
    final math = insights.modules.firstWhere((m) => m.moduleId == 'math');
    expect(math.levelsAvailable, 2);
    expect(math.levelsCompleted, 1);
  });

  test('completion and mastery are different questions', () {
    // Every math level finished, but on one star each.
    final insights = buildFor([
      for (var n = 1; n <= 4; n++) done('math-stage3-$n', 'math', stars: 1),
    ]);

    final math = insights.modules.firstWhere((m) => m.moduleId == 'math');
    expect(math.completion, 1.0, reason: 'all four are finished');
    expect(math.mastery, closeTo(4 / 12, 0.001), reason: 'but barely');
    expect(math.isFinished, isTrue);
  });

  test('finishing everything badly is still flagged for practice', () {
    final insights = buildFor([
      for (var n = 1; n <= 4; n++) done('math-stage3-$n', 'math', stars: 1),
      for (var n = 1; n <= 4; n++) done('english-stage3-$n', 'english'),
    ]);

    expect(
      insights.findingsOf(InsightKind.needsPractice).map((i) => i.moduleId),
      contains('math'),
      reason: 'completion alone would have called this a success',
    );
  });

  test('the strongest subject is named', () {
    final insights = buildFor([
      for (var n = 1; n <= 4; n++) done('english-stage3-$n', 'english'),
      done('math-stage3-1', 'math', stars: 1),
    ]);

    expect(insights.strongest?.moduleId, 'english');
    expect(insights.findingsOf(InsightKind.strength).single.moduleId,
        'english');
  });

  test('something good is always said before anything critical', () {
    final insights = buildFor([
      for (var n = 1; n <= 4; n++) done('math-stage3-$n', 'math', stars: 1),
    ]);

    // A report that opens with what is wrong gets closed unread.
    expect(
      insights.findings.first.kind,
      anyOf(InsightKind.momentum, InsightKind.strength),
    );
  });

  test('a subject left part-finished for a week is called paused', () {
    final insights = buildFor([
      done('math-stage3-1', 'math', ago: const Duration(days: 20)),
      done('math-stage3-2', 'math', ago: const Duration(days: 20)),
    ]);

    final stalled = insights.findingsOf(InsightKind.stalled);
    expect(stalled.single.moduleId, 'math');
    expect(stalled.single.detail, contains('2 of 4'));
  });

  test('a subject played yesterday is not called paused', () {
    final insights = buildFor([
      done('math-stage3-1', 'math', ago: const Duration(days: 1)),
    ]);

    expect(insights.findingsOf(InsightKind.stalled), isEmpty);
  });

  test('untouched subjects are named, not counted', () {
    final insights = buildFor([done('math-stage3-1', 'math')]);

    expect(insights.findingsOf(InsightKind.notStarted).single.detail,
        contains('English'));
  });

  test('recent work is counted, and a long silence is noticed', () {
    final recent = buildFor([
      done('math-stage3-1', 'math', ago: const Duration(days: 2)),
    ]);
    expect(recent.levelsCompletedThisWeek, 1);
    expect(recent.findingsOf(InsightKind.momentum), hasLength(1));
    expect(recent.findingsOf(InsightKind.idle), isEmpty);

    final quiet = buildFor([
      done('math-stage3-1', 'math', ago: const Duration(days: 30)),
    ]);
    expect(quiet.levelsCompletedThisWeek, 0);
    expect(quiet.findingsOf(InsightKind.idle), hasLength(1));
    expect(quiet.findingsOf(InsightKind.idle).single.headline, contains('30'));
  });

  test('what to do next prefers finishing over starting something new', () {
    final insights = buildFor([done('math-stage3-1', 'math', stars: 1)]);

    expect(insights.nextUp?.moduleId, 'math',
        reason: 'half-learned letters beat a fresh subject to half-learn');
  });

  test('with nothing half-done, next up is something untried', () {
    final insights = buildFor([
      for (var n = 1; n <= 4; n++) done('math-stage3-$n', 'math'),
    ]);

    expect(insights.nextUp?.moduleId, 'english');
  });

  test('the fingerprint moves on progress and not on the clock', () {
    final first = buildFor([done('math-stage3-1', 'math')]);
    final again = buildFor([done('math-stage3-1', 'math')]);
    expect(first.fingerprint, again.fingerprint,
        reason: 'reopening the report must not pay for the same summary');

    final more = buildFor([
      done('math-stage3-1', 'math'),
      done('math-stage3-2', 'math'),
    ]);
    expect(more.fingerprint, isNot(first.fingerprint));

    final fewerStars = buildFor([done('math-stage3-1', 'math', stars: 1)]);
    expect(fewerStars.fingerprint, isNot(first.fingerprint),
        reason: 'stars change what a summary would say');
  });
}
