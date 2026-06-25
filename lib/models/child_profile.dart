class ChildProfile {
  const ChildProfile({
    required this.id,
    required this.parentId,
    required this.name,
    required this.age,
    required this.avatarAsset,
    required this.leaderboardOptIn,
    required this.displayPreference,
    required this.createdAt,
    required this.updatedAt,
    required this.isSynced,
  });

  final String id;
  final String parentId;
  final String name;
  final int age;
  final String avatarAsset;
  final bool leaderboardOptIn;
  final String displayPreference;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isSynced;

  ChildProfile copyWith({
    String? name,
    int? age,
    String? avatarAsset,
    bool? leaderboardOptIn,
    String? displayPreference,
    DateTime? updatedAt,
    bool? isSynced,
  }) {
    return ChildProfile(
      id: id,
      parentId: parentId,
      name: name ?? this.name,
      age: age ?? this.age,
      avatarAsset: avatarAsset ?? this.avatarAsset,
      leaderboardOptIn: leaderboardOptIn ?? this.leaderboardOptIn,
      displayPreference: displayPreference ?? this.displayPreference,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isSynced: isSynced ?? this.isSynced,
    );
  }
}
