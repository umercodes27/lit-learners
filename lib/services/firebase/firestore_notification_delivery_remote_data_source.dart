import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/notification_delivery.dart';
import '../remote/notification_delivery_remote_data_source.dart';

class FirestoreNotificationDeliveryRemoteDataSource
    implements NotificationDeliveryRemoteDataSource {
  FirestoreNotificationDeliveryRemoteDataSource({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  static const deliveriesCollection = 'notificationDeliveries';

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _deliveriesRef(String parentId) {
    return _firestore
        .collection('parents')
        .doc(parentId)
        .collection(deliveriesCollection);
  }

  @override
  Future<NotificationDelivery> createDelivery(
    NotificationDelivery delivery,
  ) async {
    await _deliveriesRef(delivery.parentId)
        .doc(delivery.id)
        .set(_toRemoteMap(delivery));
    return delivery;
  }

  @override
  Future<void> deleteDelivery({
    required String parentId,
    required String deliveryId,
  }) async {
    await _deliveriesRef(parentId).doc(deliveryId).delete();
  }

  @override
  Future<List<NotificationDelivery>> getDeliveries(String parentId) async {
    final snapshot = await _deliveriesRef(parentId)
        .orderBy('createdAt', descending: true)
        .get();
    return snapshot.docs.map(_fromRemoteDoc).toList();
  }

  @override
  Future<void> markRead({
    required String parentId,
    required String deliveryId,
    required DateTime readAt,
  }) async {
    await _deliveriesRef(parentId).doc(deliveryId).set(
      {
        'status': NotificationDeliveryStatus.read.name,
        'readAt': Timestamp.fromDate(readAt),
      },
      SetOptions(merge: true),
    );
  }

  NotificationDelivery _fromRemoteDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final now = DateTime.now();
    return NotificationDelivery(
      id: (data['deliveryId'] as String?) ?? doc.id,
      parentId: (data['parentId'] as String?) ?? '',
      type: _enumByName(
        NotificationDeliveryType.values,
        data['type'] as String?,
        NotificationDeliveryType.learningReminder,
      ),
      sourceId: (data['sourceId'] as String?) ?? '',
      title: (data['title'] as String?) ?? '',
      body: (data['body'] as String?) ?? '',
      scheduledFor: _dateFromRemoteValue(data['scheduledFor']) ?? now,
      status: _enumByName(
        NotificationDeliveryStatus.values,
        data['status'] as String?,
        NotificationDeliveryStatus.delivered,
      ),
      createdAt: _dateFromRemoteValue(data['createdAt']) ?? now,
      deliveredAt: _dateFromRemoteValue(data['deliveredAt']),
      readAt: _dateFromRemoteValue(data['readAt']),
    );
  }

  Map<String, Object?> _toRemoteMap(NotificationDelivery delivery) {
    return {
      'deliveryId': delivery.id,
      'parentId': delivery.parentId,
      'type': delivery.type.name,
      'sourceId': delivery.sourceId,
      'title': delivery.title,
      'body': delivery.body,
      'scheduledFor': Timestamp.fromDate(delivery.scheduledFor),
      'status': delivery.status.name,
      'createdAt': Timestamp.fromDate(delivery.createdAt),
      'deliveredAt': _timestampOrNull(delivery.deliveredAt),
      'readAt': _timestampOrNull(delivery.readAt),
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
