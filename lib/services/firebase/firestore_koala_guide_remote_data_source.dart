import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/koala_guide_message.dart';
import '../remote/koala_guide_remote_data_source.dart';

class FirestoreKoalaGuideRemoteDataSource
    implements KoalaGuideRemoteDataSource {
  FirestoreKoalaGuideRemoteDataSource({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  static const messagesCollection = 'koalaGuideMessages';

  final FirebaseFirestore _firestore;

  @override
  Future<List<KoalaGuideMessage>> getPublishedMessages() async {
    final snapshot = await _firestore.collection(messagesCollection).get();
    return snapshot.docs
        .where((doc) => _isPublished(doc.data()))
        .map(_messageFromDoc)
        .toList()
      ..sort((a, b) {
        final priorityCompare = b.priority.compareTo(a.priority);
        if (priorityCompare != 0) return priorityCompare;
        return a.id.compareTo(b.id);
      });
  }

  bool _isPublished(Map<String, dynamic> data) {
    return data['isPublished'] == true;
  }

  KoalaGuideMessage _messageFromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    return KoalaGuideMessage(
      id: (data['messageId'] as String?) ?? doc.id,
      message: (data['message'] as String?) ?? '',
      parentTip: data['parentTip'] as String?,
      audioCueKey: data['audioCueKey'] as String?,
      moduleId: data['moduleId'] as String?,
      levelId: data['levelId'] as String?,
      minStage: (data['minStage'] as num?)?.toInt(),
      maxStage: (data['maxStage'] as num?)?.toInt(),
      trigger: _enumByName(
        KoalaGuideTrigger.values,
        data['trigger'] as String?,
        KoalaGuideTrigger.activityStart,
      ),
      audience: _enumByName(
        KoalaGuideAudience.values,
        data['audience'] as String?,
        KoalaGuideAudience.child,
      ),
      mood: _enumByName(
        KoalaGuideMood.values,
        data['mood'] as String?,
        KoalaGuideMood.neutral,
      ),
      priority: (data['priority'] as num?)?.toInt() ?? 0,
    );
  }

  T _enumByName<T extends Enum>(
    List<T> values,
    String? name,
    T fallback,
  ) {
    for (final value in values) {
      if (value.name == name) return value;
    }
    return fallback;
  }
}
