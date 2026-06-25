import 'package:flutter_test/flutter_test.dart';
import 'package:little_learners/models/child_profile.dart';
import 'package:little_learners/services/local/child_profile_mapper.dart';

void main() {
  test('ChildProfileMapper round-trips local SQLite map values', () {
    final createdAt = DateTime.utc(2026, 1, 2, 3, 4, 5);
    final updatedAt = DateTime.utc(2026, 1, 3, 4, 5, 6);
    final profile = ChildProfile(
      id: 'child-1',
      parentId: 'parent-1',
      name: 'Aya',
      age: 3,
      avatarAsset: 'koala-blue',
      leaderboardOptIn: true,
      displayPreference: 'firstName',
      createdAt: createdAt,
      updatedAt: updatedAt,
      isSynced: false,
    );

    final map = ChildProfileMapper.toLocalMap(profile);
    final restored = ChildProfileMapper.fromLocalMap(map);

    expect(map['leaderboardOptIn'], 1);
    expect(map['isSynced'], 0);
    expect(restored.id, profile.id);
    expect(restored.parentId, profile.parentId);
    expect(restored.name, profile.name);
    expect(restored.age, profile.age);
    expect(restored.leaderboardOptIn, isTrue);
    expect(restored.displayPreference, profile.displayPreference);
    expect(restored.createdAt, createdAt);
    expect(restored.updatedAt, updatedAt);
    expect(restored.isSynced, isFalse);
  });
}
