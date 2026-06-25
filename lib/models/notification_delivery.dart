enum NotificationDeliveryType { learningReminder, progressNudge }

enum NotificationDeliveryStatus { delivered, read }

class NotificationDelivery {
  const NotificationDelivery({
    required this.id,
    required this.parentId,
    required this.type,
    required this.sourceId,
    required this.title,
    required this.body,
    required this.scheduledFor,
    required this.status,
    required this.createdAt,
    this.deliveredAt,
    this.readAt,
  });

  final String id;
  final String parentId;
  final NotificationDeliveryType type;
  final String sourceId;
  final String title;
  final String body;
  final DateTime scheduledFor;
  final NotificationDeliveryStatus status;
  final DateTime createdAt;
  final DateTime? deliveredAt;
  final DateTime? readAt;

  NotificationDelivery copyWith({
    NotificationDeliveryStatus? status,
    DateTime? deliveredAt,
    DateTime? readAt,
  }) {
    return NotificationDelivery(
      id: id,
      parentId: parentId,
      type: type,
      sourceId: sourceId,
      title: title,
      body: body,
      scheduledFor: scheduledFor,
      status: status ?? this.status,
      createdAt: createdAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      readAt: readAt ?? this.readAt,
    );
  }
}
