import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/leaderboard_entry.dart';
import '../remote/leaderboard_remote_data_source.dart';

class FirestoreLeaderboardRemoteDataSource
    implements LeaderboardRemoteDataSource {
  FirestoreLeaderboardRemoteDataSource({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  static const leaderboardsCollection = 'leaderboards';
  static const entriesCollection = 'entries';

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _entriesRef(int ageStage) {
    return _firestore
        .collection(leaderboardsCollection)
        .doc('stage-$ageStage')
        .collection(entriesCollection);
  }

  @override
  Future<void> deleteEntry({
    required int ageStage,
    required String childId,
  }) async {
    await _entriesRef(ageStage).doc(childId).delete();
  }

  @override
  Future<void> deleteEntryForChild(String childId) async {
    final batch = _firestore.batch();
    for (var stage = 1; stage <= 4; stage++) {
      batch.delete(_entriesRef(stage).doc(childId));
    }
    await batch.commit();
  }

  @override
  Future<List<LeaderboardEntry>> getTopEntries({
    required int ageStage,
    int limit = 20,
  }) async {
    final snapshot = await _entriesRef(ageStage)
        .orderBy('totalScore', descending: true)
        .orderBy('totalStars', descending: true)
        .orderBy('lastActivityAt', descending: true)
        .limit(limit)
        .get();
    return snapshot.docs.map(_fromRemoteDoc).toList();
  }

  @override
  Future<void> upsertEntry(LeaderboardEntry entry) async {
    await deleteEntryForChild(entry.childId);
    await _entriesRef(entry.ageStage)
        .doc(entry.childId)
        .set(_toRemoteMap(entry), SetOptions(merge: true));
  }

  LeaderboardEntry _fromRemoteDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final now = DateTime.now();
    return LeaderboardEntry(
      childId: (data['childId'] as String?) ?? doc.id,
      parentId: (data['parentId'] as String?) ?? '',
      displayName: (data['displayName'] as String?) ?? 'Learner',
      ageStage: (data['ageStage'] as num?)?.toInt() ?? 1,
      totalScore: (data['totalScore'] as num?)?.toInt() ?? 0,
      completedLevels: (data['completedLevels'] as num?)?.toInt() ?? 0,
      totalStars: (data['totalStars'] as num?)?.toInt() ?? 0,
      rewardCount: (data['rewardCount'] as num?)?.toInt() ?? 0,
      lastActivityAt: _dateFromRemoteValue(data['lastActivityAt']),
      updatedAt: _dateFromRemoteValue(data['updatedAt']) ?? now,
    );
  }

  Map<String, Object?> _toRemoteMap(LeaderboardEntry entry) {
    return {
      'childId': entry.childId,
      'parentId': entry.parentId,
      'displayName': entry.displayName,
      'ageStage': entry.ageStage,
      'totalScore': entry.totalScore,
      'completedLevels': entry.completedLevels,
      'totalStars': entry.totalStars,
      'rewardCount': entry.rewardCount,
      'lastActivityAt': _timestampOrNull(entry.lastActivityAt),
      'updatedAt': Timestamp.fromDate(entry.updatedAt),
    };
  }

  Timestamp? _timestampOrNull(DateTime? value) {
    if (value == null) return null;
    return Timestamp.fromDate(value);
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
