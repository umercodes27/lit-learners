import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/progress.dart';
import '../remote/progress_remote_data_source.dart';

class FirestoreProgressRemoteDataSource implements ProgressRemoteDataSource {
  FirestoreProgressRemoteDataSource({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  static const progressCollection = 'levelProgress';

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _progressRef(String childId) {
    return _firestore
        .collection('childProgress')
        .doc(childId)
        .collection(progressCollection);
  }

  @override
  Future<List<LevelProgress>> getProgressForChild(String childId) async {
    final snapshot = await _progressRef(childId).orderBy('updatedAt').get();
    return snapshot.docs
        .map((doc) => _progressFromRemoteDoc(childId: childId, doc: doc))
        .toList();
  }

  @override
  Future<void> upsertProgress(LevelProgress progress) async {
    await _progressRef(progress.childId).doc(progress.levelId).set(
      {
        'childId': progress.childId,
        'moduleId': progress.moduleId,
        'levelId': progress.levelId,
        'completed': progress.completed,
        'score': progress.score,
        'starsEarned': progress.starsEarned,
        'rewardEarned': progress.rewardEarned,
        'rewardEarnedAt': _timestampOrNull(progress.rewardEarnedAt),
        'watchedLessonIds': progress.watchedLessonIds,
        'lastWatchedAt': _timestampOrNull(progress.lastWatchedAt),
        'updatedAt': Timestamp.fromDate(progress.updatedAt),
        'syncedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  LevelProgress _progressFromRemoteDoc({
    required String childId,
    required QueryDocumentSnapshot<Map<String, dynamic>> doc,
  }) {
    final data = doc.data();
    final updatedAt = _dateFromRemoteValue(data['updatedAt']) ?? DateTime.now();

    return LevelProgress(
      childId: (data['childId'] as String?) ?? childId,
      moduleId: (data['moduleId'] as String?) ?? '',
      levelId: (data['levelId'] as String?) ?? doc.id,
      completed: (data['completed'] as bool?) ?? false,
      score: (data['score'] as num?)?.toInt(),
      starsEarned: (data['starsEarned'] as num?)?.toInt() ?? 0,
      rewardEarned: (data['rewardEarned'] as bool?) ?? false,
      rewardEarnedAt: _dateFromRemoteValue(data['rewardEarnedAt']),
      watchedLessonIds: _stringListFromRemoteValue(data['watchedLessonIds']),
      lastWatchedAt: _dateFromRemoteValue(data['lastWatchedAt']),
      updatedAt: updatedAt,
      isSynced: true,
    );
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

  List<String> _stringListFromRemoteValue(Object? value) {
    if (value is Iterable) return value.cast<String>().toList();
    return const [];
  }
}
