class LevelProgress {
  const LevelProgress({
    required this.childId,
    required this.moduleId,
    required this.levelId,
    required this.completed,
    required this.starsEarned,
    required this.rewardEarned,
    required this.updatedAt,
    required this.isSynced,
    this.score,
    this.rewardEarnedAt,
    this.watchedLessonIds = const [],
    this.lastWatchedAt,
    this.attempts = 0,
    this.wrongAnswers = 0,
  });

  final String childId;
  final String moduleId;
  final String levelId;
  final bool completed;
  final int starsEarned;
  final bool rewardEarned;
  final DateTime updatedAt;
  final bool isSynced;
  final int? score;
  final DateTime? rewardEarnedAt;
  final List<String> watchedLessonIds;
  final DateTime? lastWatchedAt;

  /// How many times this level has been finished, not how many were passed.
  ///
  /// A score alone cannot tell a child who got it right first go from one who
  /// needed five attempts, and at this age the second child is the one whose
  /// parent needs telling.
  final int attempts;

  /// Every wrong quiz answer this child has given on this level, added up
  /// across attempts rather than replaced by the last run.
  final int wrongAnswers;

  /// Wrong answers per attempt, which is what makes the number comparable
  /// between a level played once and a level played five times.
  double get wrongPerAttempt => attempts == 0 ? 0 : wrongAnswers / attempts;

  LevelProgress copyWith({
    bool? completed,
    int? starsEarned,
    bool? rewardEarned,
    DateTime? updatedAt,
    bool? isSynced,
    int? score,
    DateTime? rewardEarnedAt,
    List<String>? watchedLessonIds,
    DateTime? lastWatchedAt,
    int? attempts,
    int? wrongAnswers,
  }) {
    return LevelProgress(
      childId: childId,
      moduleId: moduleId,
      levelId: levelId,
      completed: completed ?? this.completed,
      starsEarned: starsEarned ?? this.starsEarned,
      rewardEarned: rewardEarned ?? this.rewardEarned,
      updatedAt: updatedAt ?? this.updatedAt,
      isSynced: isSynced ?? this.isSynced,
      score: score ?? this.score,
      rewardEarnedAt: rewardEarnedAt ?? this.rewardEarnedAt,
      watchedLessonIds: watchedLessonIds ?? this.watchedLessonIds,
      lastWatchedAt: lastWatchedAt ?? this.lastWatchedAt,
      attempts: attempts ?? this.attempts,
      wrongAnswers: wrongAnswers ?? this.wrongAnswers,
    );
  }
}
