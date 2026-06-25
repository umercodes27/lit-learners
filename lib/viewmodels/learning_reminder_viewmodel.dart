import 'package:flutter/foundation.dart';

import '../models/learning_reminder.dart';
import '../repositories/learning_reminder_repository.dart';

class LearningReminderViewModel extends ChangeNotifier {
  LearningReminderViewModel(this._reminderRepository);

  final LearningReminderRepository _reminderRepository;

  List<LearningReminder> _reminders = [];
  List<LearningReminder> _dueReminders = [];
  bool _isLoading = false;
  String? _errorMessage;
  String? _infoMessage;

  List<LearningReminder> get reminders => List.unmodifiable(_reminders);
  List<LearningReminder> get dueReminders => List.unmodifiable(_dueReminders);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get infoMessage => _infoMessage;

  Future<void> loadReminders(String parentId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _reminders = await _reminderRepository.getReminders(parentId);
    } catch (error) {
      _errorMessage = 'Reminders could not load. Please try again.';
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> createReminder({
    required String parentId,
    required String title,
    required int hour,
    required int minute,
    required List<int> weekdays,
    bool enabled = true,
  }) async {
    final validationError = _validateReminder(
      title: title,
      hour: hour,
      minute: minute,
      weekdays: weekdays,
    );
    if (validationError != null) {
      _setError(validationError);
      return false;
    }

    try {
      await _reminderRepository.createReminder(
        parentId: parentId,
        title: title,
        hour: hour,
        minute: minute,
        weekdays: weekdays,
        enabled: enabled,
      );
      _infoMessage = 'Reminder saved.';
      await loadReminders(parentId);
      return true;
    } catch (error) {
      _setError('Reminder could not be saved.');
      return false;
    }
  }

  Future<bool> updateReminder(LearningReminder reminder) async {
    final validationError = _validateReminder(
      title: reminder.title,
      hour: reminder.hour,
      minute: reminder.minute,
      weekdays: reminder.weekdays,
    );
    if (validationError != null) {
      _setError(validationError);
      return false;
    }

    try {
      await _reminderRepository.updateReminder(reminder);
      _infoMessage = 'Reminder updated.';
      await loadReminders(reminder.parentId);
      return true;
    } catch (error) {
      _setError('Reminder could not be updated.');
      return false;
    }
  }

  Future<bool> toggleReminder(LearningReminder reminder, bool enabled) {
    return updateReminder(reminder.copyWith(enabled: enabled));
  }

  Future<bool> deleteReminder({
    required String parentId,
    required String reminderId,
  }) async {
    try {
      await _reminderRepository.deleteReminder(
        parentId: parentId,
        reminderId: reminderId,
      );
      _infoMessage = 'Reminder removed.';
      await loadReminders(parentId);
      return true;
    } catch (error) {
      _setError('Reminder could not be removed.');
      return false;
    }
  }

  Future<void> loadDueReminders({
    required String parentId,
    required DateTime at,
  }) async {
    _dueReminders = await _reminderRepository.getDueReminders(
      parentId: parentId,
      at: at,
    );
    notifyListeners();
  }

  Future<void> markTriggered({
    required String parentId,
    required String reminderId,
    required DateTime triggeredAt,
  }) async {
    await _reminderRepository.markTriggered(
      parentId: parentId,
      reminderId: reminderId,
      triggeredAt: triggeredAt,
    );
    await loadReminders(parentId);
  }

  String? _validateReminder({
    required String title,
    required int hour,
    required int minute,
    required List<int> weekdays,
  }) {
    if (title.trim().isEmpty) return 'Reminder title is required.';
    if (hour < 0 || hour > 23) return 'Choose a valid hour.';
    if (minute < 0 || minute > 59) return 'Choose a valid minute.';
    if (weekdays.isEmpty) return 'Choose at least one day.';
    if (weekdays.any((day) => day < 1 || day > 7)) {
      return 'Choose valid reminder days.';
    }
    return null;
  }

  void _setError(String message) {
    _errorMessage = message;
    _infoMessage = null;
    _isLoading = false;
    notifyListeners();
  }
}
