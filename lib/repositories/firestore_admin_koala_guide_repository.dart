import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/admin_content.dart';
import '../models/koala_guide_message.dart';
import '../services/firebase/firestore_koala_guide_remote_data_source.dart';
import 'admin_koala_guide_repository.dart';

class FirestoreAdminKoalaGuideRepository implements AdminKoalaGuideRepository {
  FirestoreAdminKoalaGuideRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _messagesRef {
    return _firestore.collection(
      FirestoreKoalaGuideRemoteDataSource.messagesCollection,
    );
  }

  @override
  Future<void> deleteMessage(String messageId) async {
    await _messagesRef.doc(messageId).delete();
  }

  @override
  Future<List<AdminKoalaGuideMessage>> getMessages() async {
    final snapshot = await _messagesRef.get();
    return snapshot.docs.map(_adminMessageFromDoc).toList()
      ..sort((a, b) {
        final priorityCompare = b.message.priority.compareTo(
          a.message.priority,
        );
        if (priorityCompare != 0) return priorityCompare;
        return a.message.id.compareTo(b.message.id);
      });
  }

  @override
  Future<AdminKoalaGuideMessage> upsertMessage(
    AdminKoalaGuideMessage message,
  ) async {
    final now = DateTime.now();
    final updated = message.copyWith(updatedAt: now);
    await _messagesRef.doc(message.message.id).set(
          _adminMessageToRemoteMap(updated),
          SetOptions(merge: true),
        );
    return updated;
  }

  AdminKoalaGuideMessage _adminMessageFromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final now = DateTime.now();
    final isPublished = (data['isPublished'] as bool?) ?? false;
    return AdminKoalaGuideMessage(
      message: KoalaGuideMessage(
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
      ),
      isPublished: isPublished,
      createdAt: _dateFromRemoteValue(data['createdAt']) ?? now,
      updatedAt: _dateFromRemoteValue(data['updatedAt']) ?? now,
      publishStatus: _publishStatusFromRemote(
        data['publishStatus'],
        isPublished,
      ),
      version: (data['version'] as num?)?.toInt() ?? 1,
      submittedAt: _dateFromRemoteValue(data['submittedAt']),
      publishedAt: _dateFromRemoteValue(data['publishedAt']),
    );
  }

  Map<String, Object?> _adminMessageToRemoteMap(
    AdminKoalaGuideMessage message,
  ) {
    return {
      'messageId': message.message.id,
      'message': message.message.message,
      'parentTip': message.message.parentTip,
      'audioCueKey': message.message.audioCueKey,
      'moduleId': message.message.moduleId,
      'levelId': message.message.levelId,
      'minStage': message.message.minStage,
      'maxStage': message.message.maxStage,
      'trigger': message.message.trigger.name,
      'audience': message.message.audience.name,
      'mood': message.message.mood.name,
      'priority': message.message.priority,
      'isPublished': message.isPublished,
      'publishStatus': message.publishStatus.name,
      'version': message.version,
      'createdAt': Timestamp.fromDate(message.createdAt),
      'updatedAt': Timestamp.fromDate(message.updatedAt),
      'submittedAt': _timestampOrNull(message.submittedAt),
      'publishedAt': _timestampOrNull(message.publishedAt),
    };
  }

  DateTime? _dateFromRemoteValue(Object? value) {
    return switch (value) {
      Timestamp timestamp => timestamp.toDate(),
      DateTime dateTime => dateTime,
      String text => DateTime.tryParse(text),
      _ => null,
    };
  }

  Timestamp? _timestampOrNull(DateTime? value) {
    if (value == null) return null;
    return Timestamp.fromDate(value);
  }

  AdminPublishStatus _publishStatusFromRemote(
    Object? value,
    bool isPublished,
  ) {
    if (value is String) {
      return _enumByName(
        AdminPublishStatus.values,
        value,
        isPublished ? AdminPublishStatus.published : AdminPublishStatus.draft,
      );
    }

    return isPublished
        ? AdminPublishStatus.published
        : AdminPublishStatus.draft;
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
