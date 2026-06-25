import '../../models/child_profile.dart';

class ChildProfileMapper {
  const ChildProfileMapper._();

  static ChildProfile fromLocalMap(Map<String, Object?> map) {
    return ChildProfile(
      id: map['childId']! as String,
      parentId: map['parentId']! as String,
      name: map['name']! as String,
      age: map['age']! as int,
      avatarAsset: map['avatar']! as String,
      leaderboardOptIn: (map['leaderboardOptIn']! as int) == 1,
      displayPreference: map['displayPreference']! as String,
      createdAt: DateTime.parse(map['createdAt']! as String),
      updatedAt: DateTime.parse(map['updatedAt']! as String),
      isSynced: (map['isSynced']! as int) == 1,
    );
  }

  static Map<String, Object?> toLocalMap(ChildProfile profile) {
    return {
      'childId': profile.id,
      'parentId': profile.parentId,
      'name': profile.name,
      'age': profile.age,
      'avatar': profile.avatarAsset,
      'leaderboardOptIn': profile.leaderboardOptIn ? 1 : 0,
      'displayPreference': profile.displayPreference,
      'createdAt': profile.createdAt.toIso8601String(),
      'updatedAt': profile.updatedAt.toIso8601String(),
      'isSynced': profile.isSynced ? 1 : 0,
    };
  }
}
