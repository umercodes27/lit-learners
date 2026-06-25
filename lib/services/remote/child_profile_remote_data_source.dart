import '../../models/child_profile.dart';

abstract class ChildProfileRemoteDataSource {
  Future<List<ChildProfile>> getProfiles(String parentId);
  Future<void> upsertProfile(ChildProfile profile);
  Future<void> deleteProfile({
    required String parentId,
    required String childId,
  });
}

class InMemoryChildProfileRemoteDataSource
    implements ChildProfileRemoteDataSource {
  final Map<String, ChildProfile> _profilesById = {};
  final List<String> deletedChildIds = [];

  List<ChildProfile> get profiles => List.unmodifiable(_profilesById.values);

  @override
  Future<List<ChildProfile>> getProfiles(String parentId) async {
    return _profilesById.values
        .where((profile) => profile.parentId == parentId)
        .map((profile) => profile.copyWith(isSynced: true))
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  @override
  Future<void> deleteProfile({
    required String parentId,
    required String childId,
  }) async {
    final profile = _profilesById[childId];
    if (profile == null || profile.parentId == parentId) {
      _profilesById.remove(childId);
      deletedChildIds.add(childId);
    }
  }

  @override
  Future<void> upsertProfile(ChildProfile profile) async {
    _profilesById[profile.id] = profile.copyWith(isSynced: true);
  }
}
