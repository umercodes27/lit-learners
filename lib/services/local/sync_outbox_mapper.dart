import '../../models/sync_outbox_item.dart';

class SyncOutboxMapper {
  const SyncOutboxMapper._();

  static SyncOutboxItem fromLocalMap(Map<String, Object?> map) {
    return SyncOutboxItem(
      id: map['id']! as String,
      entityType: map['entityType']! as String,
      entityId: map['entityId']! as String,
      operation: map['operation']! as String,
      payloadJson: map['payloadJson']! as String,
      createdAt: DateTime.parse(map['createdAt']! as String),
      attemptCount: map['attemptCount']! as int,
      lastError: map['lastError'] as String?,
    );
  }

  static Map<String, Object?> toLocalMap(SyncOutboxItem item) {
    return {
      'id': item.id,
      'entityType': item.entityType,
      'entityId': item.entityId,
      'operation': item.operation,
      'payloadJson': item.payloadJson,
      'createdAt': item.createdAt.toIso8601String(),
      'attemptCount': item.attemptCount,
      'lastError': item.lastError,
    };
  }
}
