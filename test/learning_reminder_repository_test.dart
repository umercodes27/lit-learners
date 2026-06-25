import 'package:flutter_test/flutter_test.dart';
import 'package:little_learners/repositories/learning_reminder_repository.dart';

void main() {
  group('InMemoryLearningReminderRepository', () {
    test('creates and sorts reminders by time', () async {
      final repository = InMemoryLearningReminderRepository();

      await repository.createReminder(
        parentId: 'parent-1',
        title: 'Evening',
        hour: 18,
        minute: 0,
        weekdays: const [1, 2, 3],
        enabled: true,
      );
      await repository.createReminder(
        parentId: 'parent-1',
        title: 'Morning',
        hour: 8,
        minute: 30,
        weekdays: const [1, 2, 3],
        enabled: true,
      );

      final reminders = await repository.getReminders('parent-1');

      expect(reminders.map((reminder) => reminder.title), [
        'Morning',
        'Evening',
      ]);
    });

    test('returns due reminders and suppresses them after trigger', () async {
      final repository = InMemoryLearningReminderRepository();
      final reminder = await repository.createReminder(
        parentId: 'parent-1',
        title: 'Learning time',
        hour: 18,
        minute: 30,
        weekdays: const [1],
        enabled: true,
      );
      final dueAt = DateTime.utc(2026, 1, 5, 18, 30);

      expect(
        await repository.getDueReminders(parentId: 'parent-1', at: dueAt),
        hasLength(1),
      );

      await repository.markTriggered(
        parentId: 'parent-1',
        reminderId: reminder.id,
        triggeredAt: dueAt,
      );

      expect(
        await repository.getDueReminders(parentId: 'parent-1', at: dueAt),
        isEmpty,
      );
    });

    test('updates, toggles, and deletes a reminder', () async {
      final repository = InMemoryLearningReminderRepository();
      final reminder = await repository.createReminder(
        parentId: 'parent-1',
        title: 'Learning time',
        hour: 18,
        minute: 30,
        weekdays: const [1],
        enabled: true,
      );

      await repository.updateReminder(
        reminder.copyWith(
          title: 'Quiet practice',
          enabled: false,
          weekdays: const [2, 4],
        ),
      );
      final updated = (await repository.getReminders('parent-1')).single;

      expect(updated.title, 'Quiet practice');
      expect(updated.enabled, isFalse);
      expect(updated.weekdays, [2, 4]);

      await repository.deleteReminder(
        parentId: 'parent-1',
        reminderId: reminder.id,
      );

      expect(await repository.getReminders('parent-1'), isEmpty);
    });
  });
}
