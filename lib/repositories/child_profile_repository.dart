import '../models/child_profile.dart';
import '../models/sync_outbox_item.dart';
import '../services/local/child_profile_dao.dart';
import '../services/local/sync_outbox_dao.dart';

abstract class ChildProfileRepository {
  Future<List<ChildProfile>> getProfiles(String parentId);
  Future<ChildProfile> createProfile({
    required String parentId,
    required String name,
    required int age,
    required String avatarAsset,
    required bool leaderboardOptIn,
    required String displayPreference,
  });
  Future<ChildProfile> updateProfile(ChildProfile profile);
  Future<void> deleteProfile({
    required String parentId,
    required String childId,
  });
}

class ProfileLimitException implements Exception {
  const ProfileLimitException();

  @override
  String toString() => 'A parent can create up to 3 child profiles.';
}

class ProfileNotFoundException implements Exception {
  const ProfileNotFoundException();

  @override
  String toString() => 'Child profile not found.';
}

class CachedChildProfileRepository implements ChildProfileRepository {
  CachedChildProfileRepository({
    required ChildProfileDao profileDao,
    required SyncOutboxDao syncOutboxDao,
  })  : _profileDao = profileDao,
        _syncOutboxDao = syncOutboxDao;

  static const maxProfilesPerParent = 3;

  final ChildProfileDao _profileDao;
  final SyncOutboxDao _syncOutboxDao;
  int _nextChildNumber = 1;

  @override
  Future<ChildProfile> createProfile({
    required String parentId,
    required String name,
    required int age,
    required String avatarAsset,
    required bool leaderboardOptIn,
    required String displayPreference,
  }) async {
    final profiles = await _profileDao.getByParent(parentId);
    if (profiles.length >= maxProfilesPerParent) {
      throw const ProfileLimitException();
    }

    final now = DateTime.now();
    final profile = ChildProfile(
      id: 'child-${now.microsecondsSinceEpoch}-${_nextChildNumber++}',
      parentId: parentId,
      name: name.trim(),
      age: age,
      avatarAsset: avatarAsset,
      leaderboardOptIn: leaderboardOptIn,
      displayPreference: displayPreference,
      createdAt: now,
      updatedAt: now,
      isSynced: false,
    );
    await _profileDao.upsert(profile);
    return profile;
  }

  @override
  Future<void> deleteProfile({
    required String parentId,
    required String childId,
  }) async {
    final profile = await _profileDao.getById(childId);
    if (profile == null || profile.parentId != parentId) {
      throw const ProfileNotFoundException();
    }
    await _syncOutboxDao.enqueue(
      SyncOutboxItem.childProfileDelete(
        parentId: parentId,
        childId: childId,
      ),
    );
    await _profileDao.delete(parentId: parentId, childId: childId);
  }

  @override
  Future<List<ChildProfile>> getProfiles(String parentId) async {
    return _profileDao.getByParent(parentId);
  }

  @override
  Future<ChildProfile> updateProfile(ChildProfile profile) async {
    final existing = await _profileDao.getById(profile.id);
    if (existing == null || existing.parentId != profile.parentId) {
      throw const ProfileNotFoundException();
    }

    final updated = profile.copyWith(
      updatedAt: DateTime.now(),
      isSynced: false,
    );
    await _profileDao.upsert(updated);
    return updated;
  }
}

class InMemoryChildProfileRepository extends CachedChildProfileRepository {
  InMemoryChildProfileRepository()
      : super(
          profileDao: InMemoryChildProfileDao(),
          syncOutboxDao: InMemorySyncOutboxDao(),
        );
}
