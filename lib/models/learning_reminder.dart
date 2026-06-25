class LearningReminder {
  const LearningReminder({
    required this.id,
    required this.parentId,
    required this.title,
    required this.hour,
    required this.minute,
    required this.weekdays,
    required this.enabled,
    required this.createdAt,
    required this.updatedAt,
    this.lastTriggeredAt,
  });

  final String id;
  final String parentId;
  final String title;
  final int hour;
  final int minute;
  final List<int> weekdays;
  final bool enabled;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastTriggeredAt;

  bool isDueAt(DateTime at) {
    if (!enabled) return false;
    if (!weekdays.contains(at.weekday)) return false;
    if (hour != at.hour || minute != at.minute) return false;

    final triggeredAt = lastTriggeredAt;
    if (triggeredAt == null) return true;
    return !_isSameDay(triggeredAt, at);
  }

  DateTime nextOccurrenceAfter(DateTime after) {
    for (var dayOffset = 0; dayOffset <= 7; dayOffset++) {
      final candidate = _dateTimeFor(
        after.year,
        after.month,
        after.day + dayOffset,
        hour,
        minute,
        isUtc: after.isUtc,
      );
      if (candidate.isAfter(after) && weekdays.contains(candidate.weekday)) {
        return candidate;
      }
    }

    return _dateTimeFor(
      after.year,
      after.month,
      after.day + 1,
      hour,
      minute,
      isUtc: after.isUtc,
    );
  }

  LearningReminder copyWith({
    String? title,
    int? hour,
    int? minute,
    List<int>? weekdays,
    bool? enabled,
    DateTime? updatedAt,
    DateTime? lastTriggeredAt,
  }) {
    return LearningReminder(
      id: id,
      parentId: parentId,
      title: title ?? this.title,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      weekdays: weekdays ?? this.weekdays,
      enabled: enabled ?? this.enabled,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastTriggeredAt: lastTriggeredAt ?? this.lastTriggeredAt,
    );
  }

  bool _isSameDay(DateTime first, DateTime second) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }

  DateTime _dateTimeFor(
    int year,
    int month,
    int day,
    int hour,
    int minute, {
    required bool isUtc,
  }) {
    if (isUtc) {
      return DateTime.utc(year, month, day, hour, minute);
    }
    return DateTime(year, month, day, hour, minute);
  }
}
