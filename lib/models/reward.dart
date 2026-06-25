enum RewardType {
  star,
  badge,
}

class Reward {
  const Reward({
    required this.id,
    required this.childId,
    required this.moduleId,
    required this.levelId,
    required this.type,
    required this.earnedAt,
  });

  final String id;
  final String childId;
  final String moduleId;
  final String levelId;
  final RewardType type;
  final DateTime earnedAt;
}
