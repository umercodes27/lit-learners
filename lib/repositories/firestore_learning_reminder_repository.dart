import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/learning_reminder.dart';
import 'learning_reminder_repository.dart';

class FirestoreLearningReminderRepository
    implements LearningReminderRepository {
  FirestoreLearningReminderRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  static const remindersCollection = 'learningReminders';

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _remindersRef(String parentId) {
    return _firestore
        .collection('parents')
        .doc(parentId)
        .collection(remindersCollection);
  }

  @override
  Future<LearningReminder> createReminder({
    required String parentId,
    required String title,
    required int hour,
    required int minute,
    required List<int> weekdays,
    required bool enabled,
  }) async {
    final ref = _remindersRef(parentId).doc();
    final now = DateTime.now();
    final reminder = LearningReminder(
      id: ref.id,
      parentId: parentId,
      title: _normalizedTitle(title),
      hour: hour,
      minute: minute,
      weekdays: _normalizedWeekdays(weekdays),
      enabled: enabled,
      createdAt: now,
      updatedAt: now,
    );
    await ref.set(_toRemoteMap(reminder));
    return reminder;
  }

  @override
  Future<void> deleteReminder({
    required String parentId,
    required String reminderId,
  }) async {
    await _remindersRef(parentId).doc(reminderId).delete();
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
    final snapshot = await _remindersRef(parentId).get();
    return snapshot.docs.map(_fromRemoteDoc).toList()..sort(_sortReminders);
  }

  @override
  Future<void> markTriggered({
    required String parentId,
    required String reminderId,
    required DateTime triggeredAt,
  }) async {
    await _remindersRef(parentId).doc(reminderId).set(
      {
        'lastTriggeredAt': Timestamp.fromDate(triggeredAt),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      },
      SetOptions(merge: true),
    );
  }

  @override
  Future<LearningReminder> updateReminder(LearningReminder reminder) async {
    final updated = reminder.copyWith(
      title: _normalizedTitle(reminder.title),
      weekdays: _normalizedWeekdays(reminder.weekdays),
      updatedAt: DateTime.now(),
    );
    await _remindersRef(updated.parentId)
        .doc(updated.id)
        .set(_toRemoteMap(updated), SetOptions(merge: true));
    return updated;
  }

  LearningReminder _fromRemoteDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final now = DateTime.now();
    return LearningReminder(
      id: (data['reminderId'] as String?) ?? doc.id,
      parentId: data['parentId'] as String,
      title: (data['title'] as String?) ?? 'Learning time',
      hour: (data['hour'] as num?)?.toInt() ?? 18,
      minute: (data['minute'] as num?)?.toInt() ?? 0,
      weekdays: _intListFromRemoteValue(data['weekdays']),
      enabled: (data['enabled'] as bool?) ?? true,
      createdAt: _dateFromRemoteValue(data['createdAt']) ?? now,
      updatedAt: _dateFromRemoteValue(data['updatedAt']) ?? now,
      lastTriggeredAt: _dateFromRemoteValue(data['lastTriggeredAt']),
    );
  }

  Map<String, Object?> _toRemoteMap(LearningReminder reminder) {
    return {
      'reminderId': reminder.id,
      'parentId': reminder.parentId,
      'title': reminder.title,
      'hour': reminder.hour,
      'minute': reminder.minute,
      'weekdays': reminder.weekdays,
      'enabled': reminder.enabled,
      'createdAt': Timestamp.fromDate(reminder.createdAt),
      'updatedAt': Timestamp.fromDate(reminder.updatedAt),
      'lastTriggeredAt': _timestampOrNull(reminder.lastTriggeredAt),
    };
  }

  Timestamp? _timestampOrNull(DateTime? value) {
    if (value == null) return null;
    return Timestamp.fromDate(value);
  }

  DateTime? _dateFromRemoteValue(Object? value) {
    return switch (value) {
      Timestamp timestamp => timestamp.toDate(),
      DateTime dateTime => dateTime,
      String text => DateTime.tryParse(text),
      _ => null,
    };
  }

  List<int> _intListFromRemoteValue(Object? value) {
    if (value is! Iterable) return const [1, 2, 3, 4, 5];
    return value.map((item) => (item as num).toInt()).toSet().toList()..sort();
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
  final normalized = weekdays.where((day) => day >= 1 && day <= 7).toSet();
  return normalized.toList()..sort();
}
