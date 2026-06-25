import 'package:flutter_test/flutter_test.dart';
import 'package:little_learners/repositories/learning_reminder_repository.dart';
import 'package:little_learners/viewmodels/learning_reminder_viewmodel.dart';

void main() {
  group('LearningReminderViewModel', () {
    test('rejects invalid reminder input', () async {
      final viewModel = LearningReminderViewModel(
        InMemoryLearningReminderRepository(),
      );

      final missingTitle = await viewModel.createReminder(
        parentId: 'parent-1',
        title: '',
        hour: 18,
        minute: 0,
        weekdays: const [1],
      );
      final missingDays = await viewModel.createReminder(
        parentId: 'parent-1',
        title: 'Practice',
        hour: 18,
        minute: 0,
        weekdays: const [],
      );

      expect(missingTitle, isFalse);
      expect(missingDays, isFalse);
      expect(viewModel.reminders, isEmpty);
    });

    test('creates, toggles, and deletes reminders', () async {
      final viewModel = LearningReminderViewModel(
        InMemoryLearningReminderRepository(),
      );

      final created = await viewModel.createReminder(
        parentId: 'parent-1',
        title: 'Practice',
        hour: 18,
        minute: 0,
        weekdays: const [1, 2, 3],
      );
      final reminder = viewModel.reminders.single;
      final toggled = await viewModel.toggleReminder(reminder, false);
      final deleted = await viewModel.deleteReminder(
        parentId: 'parent-1',
        reminderId: reminder.id,
      );

      expect(created, isTrue);
      expect(toggled, isTrue);
      expect(deleted, isTrue);
      expect(viewModel.reminders, isEmpty);
    });

    test('loads due reminders', () async {
      final repository = InMemoryLearningReminderRepository();
      final viewModel = LearningReminderViewModel(repository);
      await repository.createReminder(
        parentId: 'parent-1',
        title: 'Practice',
        hour: 18,
        minute: 30,
        weekdays: const [1],
        enabled: true,
      );

      await viewModel.loadDueReminders(
        parentId: 'parent-1',
        at: DateTime.utc(2026, 1, 5, 18, 30),
      );

      expect(viewModel.dueReminders, hasLength(1));
    });
  });
}
