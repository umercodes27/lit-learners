import 'package:flutter_test/flutter_test.dart';
import 'package:little_learners/models/child_profile.dart';
import 'package:little_learners/services/local/child_profile_dao.dart';

void main() {
  group('InMemoryChildProfileDao', () {
    test('upserts, reads by parent, and deletes profiles', () async {
      final dao = InMemoryChildProfileDao();
      final profile = _profile(
        id: 'child-1',
        parentId: 'parent-1',
        name: 'Aya',
      );

      await dao.upsert(profile);

      expect(await dao.getById('child-1'), isNotNull);
      expect(await dao.getByParent('parent-1'), hasLength(1));
      expect(await dao.getByParent('parent-2'), isEmpty);

      await dao.delete(parentId: 'parent-1', childId: 'child-1');

      expect(await dao.getById('child-1'), isNull);
    });

    test('tracks unsynced profiles and marks them synced', () async {
      final dao = InMemoryChildProfileDao();
      await dao.upsert(
        _profile(
          id: 'child-1',
          parentId: 'parent-1',
          name: 'Aya',
          isSynced: false,
        ),
      );
      await dao.upsert(
        _profile(
          id: 'child-2',
          parentId: 'parent-1',
          name: 'Umar',
          isSynced: true,
        ),
      );

      expect(await dao.getUnsynced(), hasLength(1));

      await dao.markSynced('child-1');

      expect(await dao.getUnsynced(), isEmpty);
      expect((await dao.getById('child-1'))?.isSynced, isTrue);
    });

    test('removes stale synced profiles but keeps unsynced local profiles',
        () async {
      final dao = InMemoryChildProfileDao();
      await dao.upsert(
        _profile(
          id: 'remote-kept',
          parentId: 'parent-1',
          name: 'Kept',
          isSynced: true,
        ),
      );
      await dao.upsert(
        _profile(
          id: 'remote-deleted',
          parentId: 'parent-1',
          name: 'Deleted',
          isSynced: true,
        ),
      );
      await dao.upsert(
        _profile(
          id: 'local-unsynced',
          parentId: 'parent-1',
          name: 'Local',
          isSynced: false,
        ),
      );

      final removed = await dao.deleteSyncedProfilesNotIn(
        parentId: 'parent-1',
        childIds: {'remote-kept'},
      );

      expect(removed, 1);
      expect(await dao.getById('remote-kept'), isNotNull);
      expect(await dao.getById('remote-deleted'), isNull);
      expect(await dao.getById('local-unsynced'), isNotNull);
    });
  });
}

ChildProfile _profile({
  required String id,
  required String parentId,
  required String name,
  bool isSynced = false,
}) {
  final now = DateTime.utc(2026, 1, 1);
  return ChildProfile(
    id: id,
    parentId: parentId,
    name: name,
    age: 3,
    avatarAsset: 'koala-blue',
    leaderboardOptIn: false,
    displayPreference: 'alias',
    createdAt: now,
    updatedAt: now,
    isSynced: isSynced,
  );
}
