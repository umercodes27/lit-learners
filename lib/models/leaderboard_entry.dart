class LeaderboardEntry {
  const LeaderboardEntry({
    required this.childId,
    required this.parentId,
    required this.displayName,
    required this.ageStage,
    required this.totalScore,
    required this.completedLevels,
    required this.totalStars,
    required this.rewardCount,
    required this.updatedAt,
    this.lastActivityAt,
  });

  final String childId;
  final String parentId;
  final String displayName;
  final int ageStage;
  final int totalScore;
  final int completedLevels;
  final int totalStars;
  final int rewardCount;
  final DateTime updatedAt;
  final DateTime? lastActivityAt;

  LeaderboardEntry copyWith({
    String? displayName,
    int? ageStage,
    int? totalScore,
    int? completedLevels,
    int? totalStars,
    int? rewardCount,
    DateTime? updatedAt,
    DateTime? lastActivityAt,
  }) {
    return LeaderboardEntry(
      childId: childId,
      parentId: parentId,
      displayName: displayName ?? this.displayName,
      ageStage: ageStage ?? this.ageStage,
      totalScore: totalScore ?? this.totalScore,
      completedLevels: completedLevels ?? this.completedLevels,
      totalStars: totalStars ?? this.totalStars,
      rewardCount: rewardCount ?? this.rewardCount,
      updatedAt: updatedAt ?? this.updatedAt,
      lastActivityAt: lastActivityAt ?? this.lastActivityAt,
    );
  }
}
