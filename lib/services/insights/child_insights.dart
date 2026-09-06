import '../../models/child_profile.dart';

/// What a parent is being told, in a form the UI and the prompt can both use.
///
/// Kept as an enum rather than free text so the report can colour and order
/// findings, and so the same finding reads identically whether a model wrote
/// the sentence around it or the app did.
enum InsightKind {
  /// Doing well here — worth saying first.
  strength,

  /// Attempted, but the scores or the stars say it needs another go.
  needsPractice,

  /// Started and then left. The most useful thing to tell a parent.
  stalled,

  /// Never opened.
  notStarted,

  /// Something finished recently. Momentum is worth naming.
  momentum,

  /// Nothing at all for a while.
  idle,
}

class Insight {
  const Insight({
    required this.kind,
    required this.headline,
    required this.detail,
    this.moduleId,
    this.moduleTitle,
  });

  final InsightKind kind;

  /// A few words. Goes on the card.
  final String headline;

  /// One sentence a parent can act on.
  final String detail;

  final String? moduleId;
  final String? moduleTitle;
}

/// How one subject is going.
class ModuleInsight {
  const ModuleInsight({
    required this.moduleId,
    required this.moduleTitle,
    required this.levelsAvailable,
    required this.levelsCompleted,
    required this.levelsAttempted,
    required this.starsEarned,
    required this.averageScore,
    required this.lastPlayedAt,
  });

  final String moduleId;
  final String moduleTitle;

  /// Levels this child can reach at their own stage — not every level in the
  /// app, or a two-year-old would look permanently behind.
  final int levelsAvailable;
  final int levelsCompleted;

  /// Opened, whether or not finished.
  final int levelsAttempted;

  final int starsEarned;
  final int? averageScore;
  final DateTime? lastPlayedAt;

  int get starsPossible => levelsAvailable * 3;

  /// How much of the subject is finished, 0..1.
  double get completion =>
      levelsAvailable == 0 ? 0 : levelsCompleted / levelsAvailable;

  /// How well it was done, 0..1. Completion says how far, this says how
  /// firmly — a child can finish everything on one star each.
  double get mastery => starsPossible == 0 ? 0 : starsEarned / starsPossible;

  bool get isStarted => levelsAttempted > 0;
  bool get isFinished => levelsAvailable > 0 && levelsCompleted >= levelsAvailable;
}

/// Everything the parent-facing report and the AI summary are both built on.
///
/// One analysis, two readers. The visual report renders it and the prompt
/// describes it, so the picture and the paragraph can never disagree about
/// what the child actually did.
class ChildInsights {
  const ChildInsights({
    required this.profile,
    required this.stage,
    required this.modules,
    required this.findings,
    required this.totalStars,
    required this.completedLevels,
    required this.availableLevels,
    required this.averageScore,
    required this.lastActiveAt,
    required this.levelsCompletedThisWeek,
    required this.nextUp,
  });

  final ChildProfile profile;

  /// The band of content this child sees, from their age.
  final int stage;

  final List<ModuleInsight> modules;
  final List<Insight> findings;

  final int totalStars;
  final int completedLevels;
  final int availableLevels;
  final int? averageScore;
  final DateTime? lastActiveAt;
  final int levelsCompletedThisWeek;

  /// The single thing worth doing next, or null when everything at this
  /// stage is finished.
  final ModuleInsight? nextUp;

  int get totalStarsPossible => availableLevels * 3;

  double get overallCompletion =>
      availableLevels == 0 ? 0 : completedLevels / availableLevels;

  double get overallMastery =>
      totalStarsPossible == 0 ? 0 : totalStars / totalStarsPossible;

  bool get hasStarted => completedLevels > 0 || modules.any((m) => m.isStarted);

  List<ModuleInsight> get started =>
      [for (final module in modules) if (module.isStarted) module];

  ModuleInsight? get strongest {
    final candidates = [for (final m in started) if (m.levelsCompleted > 0) m];
    if (candidates.isEmpty) return null;
    return candidates.reduce((a, b) => b.mastery > a.mastery ? b : a);
  }

  ModuleInsight? get weakest {
    final candidates = [for (final m in started) if (!m.isFinished) m];
    if (candidates.isEmpty) return null;
    return candidates.reduce((a, b) => b.mastery < a.mastery ? b : a);
  }

  List<Insight> findingsOf(InsightKind kind) =>
      [for (final finding in findings) if (finding.kind == kind) finding];

  /// Changes exactly when something a summary would mention changes.
  ///
  /// Used to decide whether a stored AI summary is still true. Deliberately
  /// coarse: it moves on progress, not on the clock, so opening the report
  /// twice in an afternoon does not pay for the same paragraph twice.
  String get fingerprint {
    final parts = <String>[
      profile.id,
      'stage$stage',
      'done$completedLevels',
      'stars$totalStars',
      'avg${averageScore ?? -1}',
      for (final module in modules)
        '${module.moduleId}:${module.levelsCompleted}:${module.starsEarned}'
            ':${module.levelsAttempted}',
    ];
    return parts.join('|');
  }
}
