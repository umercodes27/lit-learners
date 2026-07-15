import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/koala_guide_message.dart';
import '../../models/learning_reminder.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/learning_reminder_viewmodel.dart';
import '../../widgets/app_primary_button.dart';
import '../../widgets/koala_guide.dart';

class ParentRemindersPage extends StatefulWidget {
  const ParentRemindersPage({super.key});

  @override
  State<ParentRemindersPage> createState() => _ParentRemindersPageState();
}

class _ParentRemindersPageState extends State<ParentRemindersPage> {
  @override
  Widget build(BuildContext context) {
    final parent = context.watch<AuthViewModel>().parent;
    final reminders = context.watch<LearningReminderViewModel>();

    if (parent == null) {
      return const Scaffold(body: Center(child: Text('Parent not signed in.')));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Learning Reminders'),
        actions: [
          IconButton(
            tooltip: 'Refresh reminders',
            onPressed: reminders.isLoading
                ? null
                : () => context
                    .read<LearningReminderViewModel>()
                    .loadReminders(parent.id),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: const SafeArea(
        child: LearningRemindersPanel(),
      ),
    );
  }
}

class LearningRemindersPanel extends StatefulWidget {
  const LearningRemindersPanel({
    this.showGuide = true,
    this.padding = const EdgeInsets.all(16),
    super.key,
  });

  final bool showGuide;
  final EdgeInsets padding;

  @override
  State<LearningRemindersPanel> createState() => _LearningRemindersPanelState();
}

class _LearningRemindersPanelState extends State<LearningRemindersPanel> {
  final _titleController = TextEditingController(text: 'Learning time');
  final Set<int> _selectedWeekdays = {1, 2, 3, 4, 5};
  TimeOfDay _selectedTime = const TimeOfDay(hour: 18, minute: 0);
  String? _loadedParentId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final parent = context.watch<AuthViewModel>().parent;
    if (parent != null && _loadedParentId != parent.id) {
      _loadedParentId = parent.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<LearningReminderViewModel>().loadReminders(parent.id);
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final parent = context.watch<AuthViewModel>().parent;
    final reminders = context.watch<LearningReminderViewModel>();

    if (parent == null) {
      return const Center(child: Text('Parent not signed in.'));
    }

    return ListView(
      padding: widget.padding,
      children: [
        if (widget.showGuide) ...[
          const ContextualKoalaGuide(
            trigger: KoalaGuideTrigger.reminderSetup,
            audience: KoalaGuideAudience.parent,
            fallbackMessage: 'Set gentle learning reminders. These '
                'preferences sync to the backend and can later drive push '
                'notifications.',
          ),
          const SizedBox(height: 16),
        ],
        if (reminders.isLoading)
          const Center(child: CircularProgressIndicator())
        else if (reminders.reminders.isEmpty)
          const _EmptyReminderCard()
        else
          for (final reminder in reminders.reminders)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ReminderCard(reminder: reminder),
            ),
        if (reminders.errorMessage != null) ...[
          const SizedBox(height: 8),
          Text(
            reminders.errorMessage!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        if (reminders.infoMessage != null) ...[
          const SizedBox(height: 8),
          Text(reminders.infoMessage!),
        ],
        const SizedBox(height: 16),
        _CreateReminderCard(
          titleController: _titleController,
          selectedTime: _selectedTime,
          selectedWeekdays: _selectedWeekdays,
          onPickTime: () => _pickTime(context),
          onToggleDay: _toggleDay,
          onSubmit: () => _createReminder(context, parent.id),
        ),
      ],
    );
  }

  Future<void> _pickTime(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked == null) return;
    setState(() => _selectedTime = picked);
  }

  void _toggleDay(int weekday, bool selected) {
    setState(() {
      if (selected) {
        _selectedWeekdays.add(weekday);
      } else {
        _selectedWeekdays.remove(weekday);
      }
    });
  }

  Future<void> _createReminder(BuildContext context, String parentId) async {
    final created =
        await context.read<LearningReminderViewModel>().createReminder(
              parentId: parentId,
              title: _titleController.text,
              hour: _selectedTime.hour,
              minute: _selectedTime.minute,
              weekdays: _selectedWeekdays.toList()..sort(),
            );
    if (!created || !context.mounted) return;

    _titleController.text = 'Learning time';
  }
}

class _EmptyReminderCard extends StatelessWidget {
  const _EmptyReminderCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.notifications_none),
            SizedBox(width: 12),
            Expanded(child: Text('No learning reminders yet.')),
          ],
        ),
      ),
    );
  }
}

class _ReminderCard extends StatelessWidget {
  const _ReminderCard({required this.reminder});

  final LearningReminder reminder;

  @override
  Widget build(BuildContext context) {
    final viewModel = context.read<LearningReminderViewModel>();

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: Icon(
          reminder.enabled
              ? Icons.notifications_active
              : Icons.notifications_off,
        ),
        title: Text(reminder.title),
        subtitle: Text(
          '${_formatReminderTime(reminder.hour, reminder.minute)} - '
          '${_weekdaySummary(reminder.weekdays)}',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              value: reminder.enabled,
              onChanged: (enabled) {
                viewModel.toggleReminder(reminder, enabled);
              },
            ),
            IconButton(
              tooltip: 'Delete reminder',
              onPressed: () {
                viewModel.deleteReminder(
                  parentId: reminder.parentId,
                  reminderId: reminder.id,
                );
              },
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateReminderCard extends StatelessWidget {
  const _CreateReminderCard({
    required this.titleController,
    required this.selectedTime,
    required this.selectedWeekdays,
    required this.onPickTime,
    required this.onToggleDay,
    required this.onSubmit,
  });

  final TextEditingController titleController;
  final TimeOfDay selectedTime;
  final Set<int> selectedWeekdays;
  final VoidCallback onPickTime;
  final void Function(int weekday, bool selected) onToggleDay;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Add reminder',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                prefixIcon: Icon(Icons.edit_notifications),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onPickTime,
              icon: const Icon(Icons.schedule),
              label: Text(selectedTime.format(context)),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final option in _weekdayOptions)
                  FilterChip(
                    label: Text(option.label),
                    selected: selectedWeekdays.contains(option.weekday),
                    onSelected: (selected) {
                      onToggleDay(option.weekday, selected);
                    },
                  ),
              ],
            ),
            const SizedBox(height: 16),
            AppPrimaryButton(
              icon: Icons.add_alert,
              label: 'Save reminder',
              onPressed: onSubmit,
            ),
          ],
        ),
      ),
    );
  }
}

class _WeekdayOption {
  const _WeekdayOption(this.weekday, this.label);

  final int weekday;
  final String label;
}

const _weekdayOptions = [
  _WeekdayOption(1, 'Mon'),
  _WeekdayOption(2, 'Tue'),
  _WeekdayOption(3, 'Wed'),
  _WeekdayOption(4, 'Thu'),
  _WeekdayOption(5, 'Fri'),
  _WeekdayOption(6, 'Sat'),
  _WeekdayOption(7, 'Sun'),
];

String _formatReminderTime(int hour, int minute) {
  final period = hour >= 12 ? 'PM' : 'AM';
  final displayHour = hour % 12 == 0 ? 12 : hour % 12;
  return '$displayHour:${minute.toString().padLeft(2, '0')} $period';
}

String _weekdaySummary(List<int> weekdays) {
  if (weekdays.length == 7) return 'Every day';
  if (_setsEqual(weekdays, const [1, 2, 3, 4, 5])) return 'Weekdays';
  if (_setsEqual(weekdays, const [6, 7])) return 'Weekends';

  return weekdays.map((weekday) {
    return _weekdayOptions
        .firstWhere((option) => option.weekday == weekday)
        .label;
  }).join(', ');
}

bool _setsEqual(List<int> values, List<int> expected) {
  final valueSet = values.toSet();
  final expectedSet = expected.toSet();
  return valueSet.length == expectedSet.length &&
      valueSet.containsAll(expectedSet);
}
