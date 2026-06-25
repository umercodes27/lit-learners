import 'dart:convert';

class SyncOutboxItem {
  const SyncOutboxItem({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.operation,
    required this.payloadJson,
    required this.createdAt,
    required this.attemptCount,
    this.lastError,
  });

  factory SyncOutboxItem.childProfileDelete({
    required String parentId,
    required String childId,
  }) {
    final now = DateTime.now();
    return SyncOutboxItem(
      id: 'outbox-${now.microsecondsSinceEpoch}-$childId',
      entityType: childProfileEntity,
      entityId: childId,
      operation: deleteOperation,
      payloadJson: jsonEncode({
        'parentId': parentId,
        'childId': childId,
      }),
      createdAt: now,
      attemptCount: 0,
    );
  }

  static const childProfileEntity = 'child_profile';
  static const deleteOperation = 'delete';

  final String id;
  final String entityType;
  final String entityId;
  final String operation;
  final String payloadJson;
  final DateTime createdAt;
  final int attemptCount;
  final String? lastError;

  SyncOutboxItem copyWith({
    int? attemptCount,
    String? lastError,
  }) {
    return SyncOutboxItem(
      id: id,
      entityType: entityType,
      entityId: entityId,
      operation: operation,
      payloadJson: payloadJson,
      createdAt: createdAt,
      attemptCount: attemptCount ?? this.attemptCount,
      lastError: lastError ?? this.lastError,
    );
  }
}
