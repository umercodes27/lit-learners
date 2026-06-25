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
    );
  }
}
