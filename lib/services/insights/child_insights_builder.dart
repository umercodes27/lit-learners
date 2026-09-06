import '../../core/utils/age_stage_helper.dart';
import '../../models/learning_level.dart';
import '../../models/learning_module.dart';
import '../../models/parent_report.dart';
import 'child_insights.dart';

/// Turns a child's raw progress into the handful of things worth telling a
/// parent.
///
/// Every threshold here is a judgement about small children rather than a
/// statistic, so each one is named and explained instead of appearing as a
/// number in a condition.
class ChildInsightsBuilder {
  const ChildInsightsBuilder({DateTime Function()? clock}) : _clock = clock;

  final DateTime Function()? _clock;
  DateTime get _now => _clock?.call() ?? DateTime.now();

  /// Two thirds of the stars available. A child at this level is not just
  /// getting through the subject, they are getting it right.
  static const strongMastery = 0.66;

  /// Under a third. Finished, but on one star a level — the sign of guessing
  /// rather than knowing.
  static const weakMastery = 0.34;

  /// A week untouched counts as put down rather than in progress. Short
  /// enough to catch a subject going cold, long enough that a family taking
  /// a few days off is not told they have a problem.
  static const idleDays = 7;

  ChildInsights build({
    required ChildReport report,
    required List<LearningModule> modules,
    required List<LearningLevel> levels,
  }) {
    final stage = AgeStageHelper.stageForAge(report.profile.age);

    // Only what this child can actually reach. Measuring a two-year-old
    // against the four-year-old ladder would make every report look like
    // failure.
    final reachable = [
      for (final level in levels)
        if (level.stage == stage) level,
    ];

    final progressByLevel = {
      for (final entry in report.progressReports)
        entry.progress.levelId: entry.progress,
    };

    final moduleInsights = <ModuleInsight>[];
    for (final module in modules) {
      final moduleLevels = [
        for (final level in reachable)
          if (level.moduleId == module.id) level,
      ];
      if (moduleLevels.isEmpty) continue;

      var completed = 0;
      var attempted = 0;
      var stars = 0;
      final scores = <int>[];
      DateTime? lastPlayed;

      for (final level in moduleLevels) {
        final progress = progressByLevel[level.id];
        if (progress == null) continue;

        attempted++;
        if (progress.completed) completed++;
        stars += progress.starsEarned;
        if (progress.score != null) scores.add(progress.score!);

        final touched = progress.lastWatchedAt ?? progress.updatedAt;
        if (lastPlayed == null || touched.isAfter(lastPlayed)) {
          lastPlayed = touched;
        }
      }

      moduleInsights.add(ModuleInsight(
        moduleId: module.id,
        moduleTitle: module.title,
        levelsAvailable: moduleLevels.length,
        levelsCompleted: completed,
        levelsAttempted: attempted,
        starsEarned: stars,
        averageScore: scores.isEmpty
            ? null
            : (scores.reduce((a, b) => a + b) / scores.length).round(),
        lastPlayedAt: lastPlayed,
      ));
    }

    final allScores = [
      for (final entry in report.progressReports)
        if (entry.progress.score != null) entry.progress.score!,
    ];

    final weekAgo = _now.subtract(const Duration(days: idleDays));
    final completedThisWeek = report.progressReports
        .where((entry) =>
            entry.progress.completed && entry.progress.updatedAt.isAfter(weekAgo))
        .length;

    final insights = ChildInsights(
      profile: report.profile,
      stage: stage,
      modules: moduleInsights,
      findings: const [],
      totalStars: moduleInsights.fold(0, (sum, m) => sum + m.starsEarned),
      completedLevels:
          moduleInsights.fold(0, (sum, m) => sum + m.levelsCompleted),
      availableLevels:
          moduleInsights.fold(0, (sum, m) => sum + m.levelsAvailable),
      averageScore: allScores.isEmpty
          ? null
          : (allScores.reduce((a, b) => a + b) / allScores.length).round(),
      lastActiveAt: report.lastActivityAt,
      levelsCompletedThisWeek: completedThisWeek,
      nextUp: _nextUp(moduleInsights),
    );

    return ChildInsights(
      profile: insights.profile,
      stage: insights.stage,
      modules: insights.modules,
      findings: _findings(insights, weekAgo),
      totalStars: insights.totalStars,
      completedLevels: insights.completedLevels,
      availableLevels: insights.availableLevels,
      averageScore: insights.averageScore,
      lastActiveAt: insights.lastActiveAt,
      levelsCompletedThisWeek: insights.levelsCompletedThisWeek,
      nextUp: insights.nextUp,
    );
  }

  /// The one subject worth opening next.
  ///
  /// Something already begun and unfinished beats something new: a child who
  /// half-learned their letters is better served finishing them than being
  /// handed a fresh subject to half-learn as well.
  ModuleInsight? _nextUp(List<ModuleInsight> modules) {
    final unfinished = [
      for (final module in modules)
        if (module.isStarted && !module.isFinished) module,
    ];
    if (unfinished.isNotEmpty) {
      return unfinished.reduce((a, b) => b.mastery < a.mastery ? b : a);
    }

    final fresh = [for (final m in modules) if (!m.isStarted) m];
    if (fresh.isNotEmpty) return fresh.first;

    return null;
  }

  /// The findings, in the order a parent should read them.
  ///
  /// Something good first, always. A report that opens with what is wrong
  /// gets closed, and a parent who closes it does not help anyone.
  List<Insight> _findings(ChildInsights insights, DateTime weekAgo) {
    final findings = <Insight>[];
    final name = insights.profile.name;

    if (!insights.hasStarted) {
      return [
        Insight(
          kind: InsightKind.notStarted,
          headline: 'Not started yet',
          detail: '$name has not opened a lesson yet. Anything at all makes '
              'a first report; try one short subject together.',
        ),
      ];
    }

    if (insights.levelsCompletedThisWeek > 0) {
      final count = insights.levelsCompletedThisWeek;
      findings.add(Insight(
        kind: InsightKind.momentum,
        headline: '$count this week',
        detail: '$name finished $count '
            '${count == 1 ? 'lesson' : 'lessons'} in the last week.',
      ));
    }

    final strongest = insights.strongest;
    if (strongest != null && strongest.mastery >= strongMastery) {
      findings.add(Insight(
        kind: InsightKind.strength,
        moduleId: strongest.moduleId,
        moduleTitle: strongest.moduleTitle,
        headline: 'Strong at ${strongest.moduleTitle}',
        detail: '${strongest.starsEarned} of ${strongest.starsPossible} stars '
            'in ${strongest.moduleTitle}. This one is going well.',
      ));
    }

    // Weak by stars rather than by how far through: a child who finished
    // everything on one star each has not learned it, and completion alone
    // would call that a success.
    for (final module in insights.started) {
      if (module.levelsCompleted == 0) continue;
      if (module.mastery >= weakMastery) continue;
      if (module.moduleId == strongest?.moduleId) continue;

      findings.add(Insight(
        kind: InsightKind.needsPractice,
        moduleId: module.moduleId,
        moduleTitle: module.moduleTitle,
        headline: '${module.moduleTitle} needs another go',
        detail: '${module.moduleTitle} is getting through on '
            '${module.starsEarned} of ${module.starsPossible} stars. Playing '
            'the same levels again is worth more here than new ones.',
      ));
    }

    for (final module in insights.started) {
      final last = module.lastPlayedAt;
      if (module.isFinished || last == null || last.isAfter(weekAgo)) continue;

      findings.add(Insight(
        kind: InsightKind.stalled,
        moduleId: module.moduleId,
        moduleTitle: module.moduleTitle,
        headline: '${module.moduleTitle} paused',
        detail: '${module.moduleTitle} was left part-finished — '
            '${module.levelsCompleted} of ${module.levelsAvailable} done — '
            'and has not been opened in over a week.',
      ));
    }

    // Named individually rather than counted, because "3 subjects untouched"
    // tells a parent nothing they can act on.
    final untouched = [
      for (final module in insights.modules)
        if (!module.isStarted) module,
    ];
    if (untouched.isNotEmpty) {
      findings.add(Insight(
        kind: InsightKind.notStarted,
        moduleId: untouched.first.moduleId,
        moduleTitle: untouched.first.moduleTitle,
        headline: untouched.length == 1
            ? '${untouched.first.moduleTitle} not tried'
            : '${untouched.length} subjects not tried',
        detail: untouched.length == 1
            ? '${untouched.first.moduleTitle} has not been opened yet.'
            : 'Not opened yet: '
                '${untouched.map((m) => m.moduleTitle).join(', ')}.',
      ));
    }

    final lastActive = insights.lastActiveAt;
    if (lastActive != null && lastActive.isBefore(weekAgo)) {
      final days = _now.difference(lastActive).inDays;
      findings.add(Insight(
        kind: InsightKind.idle,
        headline: 'Quiet for $days days',
        detail: 'Nothing has been played for $days days. A few minutes is '
            'enough to pick the habit back up.',
      ));
    }

    return findings;
  }
}
