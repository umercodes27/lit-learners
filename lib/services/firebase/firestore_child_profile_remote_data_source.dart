import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/child_profile.dart';
import '../remote/child_profile_remote_data_source.dart';

class FirestoreChildProfileRemoteDataSource
    implements ChildProfileRemoteDataSource {
  FirestoreChildProfileRemoteDataSource({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  static const childProfilesCollection = 'childProfiles';

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _profilesRef(String parentId) {
    return _firestore
        .collection('parents')
        .doc(parentId)
        .collection(childProfilesCollection);
  }

  @override
  Future<void> deleteProfile({
    required String parentId,
    required String childId,
  }) async {
    await _profilesRef(parentId).doc(childId).delete();
  }

  @override
  Future<List<ChildProfile>> getProfiles(String parentId) async {
    final snapshot = await _profilesRef(parentId).orderBy('createdAt').get();
    return snapshot.docs
        .map((doc) => _profileFromRemoteDoc(parentId: parentId, doc: doc))
        .toList();
  }

  @override
  Future<void> upsertProfile(ChildProfile profile) async {
    await _profilesRef(profile.parentId).doc(profile.id).set(
      {
        'childId': profile.id,
        'parentId': profile.parentId,
        'name': profile.name,
        'age': profile.age,
        'avatarAsset': profile.avatarAsset,
        'leaderboardOptIn': profile.leaderboardOptIn,
        'displayPreference': profile.displayPreference,
        'createdAt': Timestamp.fromDate(profile.createdAt),
        'updatedAt': Timestamp.fromDate(profile.updatedAt),
        'syncedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  ChildProfile _profileFromRemoteDoc({
    required String parentId,
    required QueryDocumentSnapshot<Map<String, dynamic>> doc,
  }) {
    final data = doc.data();
    final now = DateTime.now();
    final createdAt = _dateFromRemoteValue(data['createdAt']) ?? now;
    final updatedAt = _dateFromRemoteValue(data['updatedAt']) ?? createdAt;

    return ChildProfile(
      id: (data['childId'] as String?) ?? doc.id,
      parentId: (data['parentId'] as String?) ?? parentId,
      name: (data['name'] as String?) ?? 'Learner',
      age: (data['age'] as num?)?.toInt() ?? 1,
      avatarAsset: (data['avatarAsset'] as String?) ?? 'koala-blue',
      leaderboardOptIn: (data['leaderboardOptIn'] as bool?) ?? false,
      displayPreference: (data['displayPreference'] as String?) ?? 'alias',
      createdAt: createdAt,
      updatedAt: updatedAt,
      isSynced: true,
    );
  }

  DateTime? _dateFromRemoteValue(Object? value) {
    return switch (value) {
      Timestamp timestamp => timestamp.toDate(),
      DateTime dateTime => dateTime,
      String text => DateTime.tryParse(text),
      _ => null,
    };
  }
}
