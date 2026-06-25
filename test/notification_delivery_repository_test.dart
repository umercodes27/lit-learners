import 'package:flutter_test/flutter_test.dart';
import 'package:little_learners/models/notification_delivery.dart';
import 'package:little_learners/repositories/learning_reminder_repository.dart';
import 'package:little_learners/repositories/notification_delivery_repository.dart';
import 'package:little_learners/services/remote/notification_delivery_remote_data_source.dart';

void main() {
  group('ReminderNotificationDeliveryRepository', () {
    test('delivers due reminders and suppresses same-day duplicates', () async {
      final reminderRepository = InMemoryLearningReminderRepository();
      final remote = InMemoryNotificationDeliveryRemoteDataSource();
      final repository = ReminderNotificationDeliveryRepository(
        reminderRepository: reminderRepository,
        remoteDataSource: remote,
      );
      final dueAt = DateTime.utc(2026, 6, 1, 18);
      await reminderRepository.createReminder(
        parentId: 'parent-1',
        title: 'Practice math',
        hour: 18,
        minute: 0,
        weekdays: [dueAt.weekday],
        enabled: true,
      );

      final firstDeliveries = await repository.deliverDueReminders(
        parentId: 'parent-1',
        at: dueAt,
      );
      final secondDeliveries = await repository.deliverDueReminders(
        parentId: 'parent-1',
        at: dueAt,
      );

      expect(firstDeliveries, hasLength(1));
      expect(firstDeliveries.single.title, 'Practice math');
      expect(
          firstDeliveries.single.status, NotificationDeliveryStatus.delivered);
      expect(secondDeliveries, isEmpty);
      expect(await repository.getDeliveries('parent-1'), hasLength(1));
    });

    test('marks deliveries read and deletes them', () async {
      final reminderRepository = InMemoryLearningReminderRepository();
      final remote = InMemoryNotificationDeliveryRemoteDataSource();
      final repository = ReminderNotificationDeliveryRepository(
        reminderRepository: reminderRepository,
        remoteDataSource: remote,
      );
      final dueAt = DateTime.utc(2026, 6, 1, 18);
      await reminderRepository.createReminder(
        parentId: 'parent-1',
        title: 'Story time',
        hour: 18,
        minute: 0,
        weekdays: [dueAt.weekday],
        enabled: true,
      );
      final delivery = (await repository.deliverDueReminders(
        parentId: 'parent-1',
        at: dueAt,
      ))
          .single;

      await repository.markRead(
        parentId: 'parent-1',
        deliveryId: delivery.id,
        readAt: dueAt.add(const Duration(minutes: 5)),
      );
      var deliveries = await repository.getDeliveries('parent-1');

      expect(deliveries.single.status, NotificationDeliveryStatus.read);

      await repository.deleteDelivery(
        parentId: 'parent-1',
        deliveryId: delivery.id,
      );
      deliveries = await repository.getDeliveries('parent-1');

      expect(deliveries, isEmpty);
    });
  });
}
