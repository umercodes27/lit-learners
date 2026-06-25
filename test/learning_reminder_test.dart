import 'package:flutter_test/flutter_test.dart';
import 'package:little_learners/models/learning_reminder.dart';

void main() {
  group('LearningReminder', () {
    test('is due at the scheduled weekday and time', () {
      final reminder = _reminder(
        hour: 18,
        minute: 30,
        weekdays: const [1, 3, 5],
      );

      expect(
        reminder.isDueAt(DateTime.utc(2026, 1, 5, 18, 30)),
        isTrue,
      );
      expect(
        reminder.isDueAt(DateTime.utc(2026, 1, 5, 18, 31)),
        isFalse,
      );
      expect(
        reminder.isDueAt(DateTime.utc(2026, 1, 6, 18, 30)),
        isFalse,
      );
    });

    test('is not due twice on the same day after being triggered', () {
      final reminder = _reminder(
        lastTriggeredAt: DateTime.utc(2026, 1, 5, 18, 30),
      );

      expect(
        reminder.isDueAt(DateTime.utc(2026, 1, 5, 18, 30)),
        isFalse,
      );
      expect(
        reminder.isDueAt(DateTime.utc(2026, 1, 6, 18, 30)),
        isTrue,
      );
    });

    test('calculates next occurrence after a given time', () {
      final reminder = _reminder(
        hour: 18,
        minute: 0,
        weekdays: const [1, 3],
      );

      final next = reminder.nextOccurrenceAfter(
        DateTime.utc(2026, 1, 5, 18, 1),
      );

      expect(next, DateTime.utc(2026, 1, 7, 18));
    });
  });
}

LearningReminder _reminder({
  int hour = 18,
  int minute = 30,
  List<int> weekdays = const [1, 2, 3, 4, 5],
  DateTime? lastTriggeredAt,
}) {
  final now = DateTime.utc(2026, 1, 1);
  return LearningReminder(
    id: 'reminder-1',
    parentId: 'parent-1',
    title: 'Learning time',
    hour: hour,
    minute: minute,
    weekdays: weekdays,
    enabled: true,
    createdAt: now,
    updatedAt: now,
    lastTriggeredAt: lastTriggeredAt,
  );
}
