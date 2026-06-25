import '../models/notification_delivery.dart';
import '../services/remote/notification_delivery_remote_data_source.dart';
import 'learning_reminder_repository.dart';

abstract class NotificationDeliveryRepository {
  Future<List<NotificationDelivery>> deliverDueReminders({
    required String parentId,
    required DateTime at,
  });

  Future<List<NotificationDelivery>> getDeliveries(String parentId);

  Future<void> markRead({
    required String parentId,
    required String deliveryId,
    required DateTime readAt,
  });

  Future<void> deleteDelivery({
    required String parentId,
    required String deliveryId,
  });
}

class ReminderNotificationDeliveryRepository
    implements NotificationDeliveryRepository {
  ReminderNotificationDeliveryRepository({
    required LearningReminderRepository reminderRepository,
    required NotificationDeliveryRemoteDataSource remoteDataSource,
  })  : _reminderRepository = reminderRepository,
        _remoteDataSource = remoteDataSource;

  final LearningReminderRepository _reminderRepository;
  final NotificationDeliveryRemoteDataSource _remoteDataSource;
  int _nextDeliveryNumber = 1;

  @override
  Future<void> deleteDelivery({
    required String parentId,
    required String deliveryId,
  }) {
    return _remoteDataSource.deleteDelivery(
      parentId: parentId,
      deliveryId: deliveryId,
    );
  }

  @override
  Future<List<NotificationDelivery>> deliverDueReminders({
    required String parentId,
    required DateTime at,
  }) async {
    final dueReminders = await _reminderRepository.getDueReminders(
      parentId: parentId,
      at: at,
    );
    final deliveries = <NotificationDelivery>[];

    for (final reminder in dueReminders) {
      final delivery = NotificationDelivery(
        id: _deliveryId(reminder.id, at),
        parentId: parentId,
        type: NotificationDeliveryType.learningReminder,
        sourceId: reminder.id,
        title: reminder.title,
        body: 'It is time for a gentle Little Learners session.',
        scheduledFor: at,
        status: NotificationDeliveryStatus.delivered,
        createdAt: DateTime.now(),
        deliveredAt: at,
      );
      deliveries.add(await _remoteDataSource.createDelivery(delivery));
      await _reminderRepository.markTriggered(
        parentId: parentId,
        reminderId: reminder.id,
        triggeredAt: at,
      );
    }

    return deliveries;
  }

  @override
  Future<List<NotificationDelivery>> getDeliveries(String parentId) {
    return _remoteDataSource.getDeliveries(parentId);
  }

  @override
  Future<void> markRead({
    required String parentId,
    required String deliveryId,
    required DateTime readAt,
  }) {
    return _remoteDataSource.markRead(
      parentId: parentId,
      deliveryId: deliveryId,
      readAt: readAt,
    );
  }

  String _deliveryId(String reminderId, DateTime at) {
    return '$reminderId-${at.toIso8601String()}-${_nextDeliveryNumber++}'
        .replaceAll(RegExp(r'[^a-zA-Z0-9._-]+'), '-');
  }
}
