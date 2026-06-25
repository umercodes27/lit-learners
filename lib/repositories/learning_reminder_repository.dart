import '../models/learning_reminder.dart';

abstract class LearningReminderRepository {
  Future<List<LearningReminder>> getReminders(String parentId);

  Future<LearningReminder> createReminder({
    required String parentId,
    required String title,
    required int hour,
    required int minute,
    required List<int> weekdays,
    required bool enabled,
  });

  Future<LearningReminder> updateReminder(LearningReminder reminder);

  Future<void> deleteReminder({
    required String parentId,
    required String reminderId,
  });

  Future<List<LearningReminder>> getDueReminders({
    required String parentId,
    required DateTime at,
  });

  Future<void> markTriggered({
    required String parentId,
    required String reminderId,
    required DateTime triggeredAt,
  });
}

class InMemoryLearningReminderRepository implements LearningReminderRepository {
  final Map<String, LearningReminder> _remindersById = {};
  int _nextReminderNumber = 1;

  @override
  Future<LearningReminder> createReminder({
    required String parentId,
    required String title,
    required int hour,
    required int minute,
    required List<int> weekdays,
    required bool enabled,
  }) async {
    final now = DateTime.now();
    final reminder = LearningReminder(
      id: 'reminder-${now.microsecondsSinceEpoch}-${_nextReminderNumber++}',
      parentId: parentId,
      title: _normalizedTitle(title),
      hour: hour,
      minute: minute,
      weekdays: _normalizedWeekdays(weekdays),
      enabled: enabled,
      createdAt: now,
      updatedAt: now,
    );
    _remindersById[reminder.id] = reminder;
    return reminder;
  }

  @override
  Future<void> deleteReminder({
    required String parentId,
    required String reminderId,
  }) async {
    final reminder = _remindersById[reminderId];
    if (reminder?.parentId == parentId) {
      _remindersById.remove(reminderId);
    }
  }

  @override
  Future<List<LearningReminder>> getDueReminders({
    required String parentId,
    required DateTime at,
  }) async {
    final reminders = await getReminders(parentId);
    return reminders.where((reminder) => reminder.isDueAt(at)).toList();
  }

  @override
  Future<List<LearningReminder>> getReminders(String parentId) async {
    return _remindersById.values
        .where((reminder) => reminder.parentId == parentId)
        .toList()
      ..sort(_sortReminders);
  }

  @override
  Future<void> markTriggered({
    required String parentId,
    required String reminderId,
    required DateTime triggeredAt,
  }) async {
    final reminder = _remindersById[reminderId];
    if (reminder == null || reminder.parentId != parentId) return;

    _remindersById[reminderId] = reminder.copyWith(
      lastTriggeredAt: triggeredAt,
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<LearningReminder> updateReminder(LearningReminder reminder) async {
    final updated = reminder.copyWith(
      title: _normalizedTitle(reminder.title),
      weekdays: _normalizedWeekdays(reminder.weekdays),
      updatedAt: DateTime.now(),
    );
    _remindersById[updated.id] = updated;
    return updated;
  }
}

int _sortReminders(LearningReminder a, LearningReminder b) {
  final hourCompare = a.hour.compareTo(b.hour);
  if (hourCompare != 0) return hourCompare;

  final minuteCompare = a.minute.compareTo(b.minute);
  if (minuteCompare != 0) return minuteCompare;

  return a.title.compareTo(b.title);
}

String _normalizedTitle(String title) {
  final trimmed = title.trim();
  if (trimmed.isEmpty) return 'Learning time';
  return trimmed;
}

List<int> _normalizedWeekdays(List<int> weekdays) {
  final normalized = weekdays.where((day) => day >= 1 && day <= 7).toSet()
    ..removeWhere((day) => day < 1 || day > 7);
  return normalized.toList()..sort();
}
