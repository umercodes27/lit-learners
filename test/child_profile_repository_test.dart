import 'package:flutter_test/flutter_test.dart';
import 'package:little_learners/repositories/child_profile_repository.dart';
import 'package:little_learners/services/local/child_profile_dao.dart';
import 'package:little_learners/services/local/sync_outbox_dao.dart';

void main() {
  group('InMemoryChildProfileRepository', () {
    test('creates, updates, and deletes child profiles for a parent', () async {
      final repository = InMemoryChildProfileRepository();

      final profile = await repository.createProfile(
        parentId: 'parent-1',
        name: 'Aya',
        age: 3,
        avatarAsset: 'koala-blue',
        leaderboardOptIn: true,
        displayPreference: 'firstName',
      );
      final updated = await repository.updateProfile(
        profile.copyWith(name: 'Aya Noor', age: 4),
      );

      expect(updated.name, 'Aya Noor');
      expect(updated.age, 4);

      await repository.deleteProfile(
        parentId: 'parent-1',
        childId: profile.id,
      );

      expect(await repository.getProfiles('parent-1'), isEmpty);
    });

    test('enforces maximum of three child profiles per parent', () async {
      final repository = InMemoryChildProfileRepository();

      for (var index = 0; index < 3; index++) {
        await repository.createProfile(
          parentId: 'parent-1',
          name: 'Child $index',
          age: 3,
          avatarAsset: 'koala-blue',
          leaderboardOptIn: false,
          displayPreference: 'alias',
        );
      }

      await expectLater(
        repository.createProfile(
          parentId: 'parent-1',
          name: 'Fourth',
          age: 3,
          avatarAsset: 'koala-blue',
          leaderboardOptIn: false,
          displayPreference: 'alias',
        ),
        throwsA(isA<ProfileLimitException>()),
      );
    });

    test('created and updated profiles remain unsynced for sync service',
        () async {
      final dao = InMemoryChildProfileDao();
      final repository = CachedChildProfileRepository(
        profileDao: dao,
        syncOutboxDao: InMemorySyncOutboxDao(),
      );

      final profile = await repository.createProfile(
        parentId: 'parent-1',
        name: 'Aya',
        age: 3,
        avatarAsset: 'koala-blue',
        leaderboardOptIn: true,
        displayPreference: 'firstName',
      );
      await dao.markSynced(profile.id);

      final updated = await repository.updateProfile(
        profile.copyWith(name: 'Aya Noor'),
      );

      expect(profile.isSynced, isFalse);
      expect(updated.isSynced, isFalse);
      expect(await dao.getUnsynced(), hasLength(1));
    });

    test('delete queues a child profile delete outbox item', () async {
      final profileDao = InMemoryChildProfileDao();
      final outboxDao = InMemorySyncOutboxDao();
      final repository = CachedChildProfileRepository(
        profileDao: profileDao,
        syncOutboxDao: outboxDao,
      );

      final profile = await repository.createProfile(
        parentId: 'parent-1',
        name: 'Aya',
        age: 3,
        avatarAsset: 'koala-blue',
        leaderboardOptIn: true,
        displayPreference: 'firstName',
      );

      await repository.deleteProfile(
        parentId: profile.parentId,
        childId: profile.id,
      );

      expect(await profileDao.getById(profile.id), isNull);
      final pending = await outboxDao.getPending();
      expect(pending, hasLength(1));
      expect(pending.single.entityId, profile.id);
    });
  });
}
