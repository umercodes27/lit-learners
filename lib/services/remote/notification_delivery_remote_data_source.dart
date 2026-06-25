import '../../models/notification_delivery.dart';

abstract class NotificationDeliveryRemoteDataSource {
  Future<NotificationDelivery> createDelivery(NotificationDelivery delivery);

  Future<List<NotificationDelivery>> getDeliveries(String parentId);

  Future<void> deleteDelivery({
    required String parentId,
    required String deliveryId,
  });

  Future<void> markRead({
    required String parentId,
    required String deliveryId,
    required DateTime readAt,
  });
}

class InMemoryNotificationDeliveryRemoteDataSource
    implements NotificationDeliveryRemoteDataSource {
  final Map<String, NotificationDelivery> _deliveriesById = {};

  List<NotificationDelivery> get deliveries =>
      List.unmodifiable(_deliveriesById.values);

  @override
  Future<NotificationDelivery> createDelivery(
    NotificationDelivery delivery,
  ) async {
    _deliveriesById[delivery.id] = delivery;
    return delivery;
  }

  @override
  Future<void> deleteDelivery({
    required String parentId,
    required String deliveryId,
  }) async {
    final delivery = _deliveriesById[deliveryId];
    if (delivery?.parentId == parentId) {
      _deliveriesById.remove(deliveryId);
    }
  }

  @override
  Future<List<NotificationDelivery>> getDeliveries(String parentId) async {
    return _deliveriesById.values
        .where((delivery) => delivery.parentId == parentId)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Future<void> markRead({
    required String parentId,
    required String deliveryId,
    required DateTime readAt,
  }) async {
    final delivery = _deliveriesById[deliveryId];
    if (delivery == null || delivery.parentId != parentId) return;

    _deliveriesById[deliveryId] = delivery.copyWith(
      status: NotificationDeliveryStatus.read,
      readAt: readAt,
    );
  }
}
