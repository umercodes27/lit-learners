import 'package:flutter_test/flutter_test.dart';
import 'package:little_learners/models/child_profile.dart';
import 'package:little_learners/models/sync_outbox_item.dart';
import 'package:little_learners/services/local/child_profile_dao.dart';
import 'package:little_learners/services/local/sync_outbox_dao.dart';
import 'package:little_learners/services/remote/child_profile_remote_data_source.dart';
import 'package:little_learners/services/sync/sync_service.dart';

void main() {
  group('SyncService', () {
    test('pushes unsynced profiles and marks them synced', () async {
      final profileDao = InMemoryChildProfileDao();
      final outboxDao = InMemorySyncOutboxDao();
      final remote = InMemoryChildProfileRemoteDataSource();
      final service = SyncService(
        childProfileDao: profileDao,
        syncOutboxDao: outboxDao,
        childProfileRemoteDataSource: remote,
      );

      await profileDao.upsert(_profile(id: 'child-1', isSynced: false));

      final report = await service.syncNow();

      expect(report.pushedProfiles, 1);
      expect(report.failedItems, 0);
      expect(remote.profiles, hasLength(1));
      expect((await profileDao.getById('child-1'))?.isSynced, isTrue);
    });

    test('processes child profile delete outbox items', () async {
      final profileDao = InMemoryChildProfileDao();
      final outboxDao = InMemorySyncOutboxDao();
      final remote = InMemoryChildProfileRemoteDataSource();
      final service = SyncService(
        childProfileDao: profileDao,
        syncOutboxDao: outboxDao,
        childProfileRemoteDataSource: remote,
      );
      final profile = _profile(id: 'child-1', isSynced: true);

      await remote.upsertProfile(profile);
      await outboxDao.enqueue(
        SyncOutboxItem.childProfileDelete(
          parentId: profile.parentId,
          childId: profile.id,
        ),
      );

      final report = await service.syncNow();

      expect(report.completedOutboxItems, 1);
      expect(report.failedItems, 0);
      expect(remote.deletedChildIds, contains('child-1'));
      expect(await outboxDao.getPending(), isEmpty);
    });

    test('pulls remote parent profiles into the local cache', () async {
      final profileDao = InMemoryChildProfileDao();
      final outboxDao = InMemorySyncOutboxDao();
      final remote = InMemoryChildProfileRemoteDataSource();
      final service = SyncService(
        childProfileDao: profileDao,
        syncOutboxDao: outboxDao,
        childProfileRemoteDataSource: remote,
      );

      await remote.upsertProfile(_profile(id: 'remote-child', isSynced: true));

      final report = await service.syncNow(parentId: 'parent-1');
      final cachedProfile = await profileDao.getById('remote-child');

      expect(report.pulledProfiles, 1);
      expect(report.failedItems, 0);
      expect(cachedProfile?.name, 'Aya');
      expect(cachedProfile?.isSynced, isTrue);
    });

    test('removes synced local profiles that were deleted remotely', () async {
      final profileDao = InMemoryChildProfileDao();
      final service = SyncService(
        childProfileDao: profileDao,
        syncOutboxDao: InMemorySyncOutboxDao(),
        childProfileRemoteDataSource: InMemoryChildProfileRemoteDataSource(),
      );

      await profileDao.upsert(_profile(id: 'deleted-remote', isSynced: true));

      final report = await service.syncNow(parentId: 'parent-1');

      expect(report.removedProfiles, 1);
      expect(await profileDao.getById('deleted-remote'), isNull);
    });

    test('skips remote pull when local push fails', () async {
      final profileDao = InMemoryChildProfileDao();
      final remote = _FailingPushRemoteDataSource([
        _profile(
          id: 'child-1',
          isSynced: true,
          name: 'Remote Old',
          updatedAt: DateTime.utc(2026, 1, 1),
        ),
      ]);
      final service = SyncService(
        childProfileDao: profileDao,
        syncOutboxDao: InMemorySyncOutboxDao(),
        childProfileRemoteDataSource: remote,
      );

      await profileDao.upsert(
        _profile(
          id: 'child-1',
          isSynced: false,
          name: 'Local New',
          updatedAt: DateTime.utc(2026, 1, 2),
        ),
      );

      final report = await service.syncNow(parentId: 'parent-1');
      final cachedProfile = await profileDao.getById('child-1');

      expect(report.failedItems, 1);
      expect(report.pulledProfiles, 0);
      expect(cachedProfile?.name, 'Local New');
      expect(cachedProfile?.isSynced, isFalse);
    });
  });
}

ChildProfile _profile({
  required String id,
  required bool isSynced,
  String name = 'Aya',
  DateTime? updatedAt,
}) {
  final now = DateTime.utc(2026, 1, 1);
  return ChildProfile(
    id: id,
    parentId: 'parent-1',
    name: name,
    age: 3,
    avatarAsset: 'koala-blue',
    leaderboardOptIn: false,
    displayPreference: 'alias',
    createdAt: now,
    updatedAt: updatedAt ?? now,
    isSynced: isSynced,
  );
}

class _FailingPushRemoteDataSource implements ChildProfileRemoteDataSource {
  const _FailingPushRemoteDataSource(this._profiles);

  final List<ChildProfile> _profiles;

  @override
  Future<void> deleteProfile({
    required String parentId,
    required String childId,
  }) async {}

  @override
  Future<List<ChildProfile>> getProfiles(String parentId) async {
    return _profiles.where((profile) => profile.parentId == parentId).toList();
  }

  @override
  Future<void> upsertProfile(ChildProfile profile) async {
    throw Exception('Push failed');
  }
}
