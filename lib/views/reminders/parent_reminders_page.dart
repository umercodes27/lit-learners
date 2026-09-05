import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/routing/route_names.dart';
import '../../models/koala_guide_message.dart';
import '../../models/learning_reminder.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/learning_reminder_viewmodel.dart';
import '../../viewmodels/notification_viewmodel.dart';
import '../../widgets/koala_guide.dart';
import '../../widgets/play/play.dart';

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
      body: PlayGround(
        color: PlayColors.sky,
        safeArea: false,
        child: SafeArea(
          child: Column(
            children: [
              PlayHeader(
                title: 'Learning Reminders',
                onBack: Navigator.of(context).canPop()
                    ? () => Navigator.of(context).maybePop()
                    : null,
                trailing: PlayIconButton(
                  icon: Icons.refresh_rounded,
                  semanticLabel: 'Refresh reminders',
                  onPressed: reminders.isLoading
                      ? null
                      : () => context
                          .read<LearningReminderViewModel>()
                          .loadReminders(parent.id),
                  color: PlayColors.card,
                  iconColor: PlayColors.sky,
                  size: 54,
                ),
              ),
              const Expanded(child: LearningRemindersPanel()),
            ],
          ),
        ),
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
        context.read<NotificationViewModel>().refreshPermission();
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
        _RemindersHeader(count: reminders.reminders.length),
        const SizedBox(height: 14),
        const _DeliveryStatusCard(),
        const SizedBox(height: 14),
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
          const Center(child: CircularProgressIndicator(color: Colors.white))
        else if (reminders.reminders.isEmpty)
          const _EmptyReminderCard()
        else
          for (final reminder in reminders.reminders)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ReminderCard(reminder: reminder),
            ),
        if (reminders.errorMessage != null) ...[
          const SizedBox(height: 12),
          PlayBanner(message: reminders.errorMessage!),
        ],
        if (reminders.infoMessage != null) ...[
          const SizedBox(height: 12),
          PlayBanner(message: reminders.infoMessage!, isError: false),
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

/// Answers the question a parent actually has about this screen: will the
/// phone really buzz? A saved schedule with notifications switched off at the
/// OS level looks identical to a working one otherwise.
class _DeliveryStatusCard extends StatelessWidget {
  const _DeliveryStatusCard();

  @override
  Widget build(BuildContext context) {
    final notifications = context.watch<NotificationViewModel>();
    final granted = notifications.permissionGranted;
    final accent = granted ? PlayColors.grass : PlayColors.tangerine;

    return PlayPanel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                child: Icon(
                  granted
                      ? Icons.notifications_active_rounded
                      : Icons.notifications_off_rounded,
                  color: PlayColors.onGround(accent),
                  size: 30,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  granted
                      ? 'This phone will show your reminders'
                      : 'Notifications are switched off on this phone',
                  style: const TextStyle(
                    fontFamily: 'Fredoka',
                    fontSize: 19,
                    height: 1.2,
                    fontWeight: FontWeight.w600,
                    color: PlayColors.ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            granted
                ? 'Reminders are scheduled on the device, so they arrive even '
                    'when the app is closed.'
                : 'Schedules below are saved, but nothing will pop up until '
                    'you allow notifications.',
            style: TextStyle(
              fontSize: 14,
              height: 1.35,
              fontWeight: FontWeight.w600,
              color: PlayColors.ink.withValues(alpha: 0.62),
            ),
          ),
          const SizedBox(height: 14),
          if (!granted)
            PlayButton(
              icon: Icons.notifications_active_rounded,
              label: 'Allow notifications',
              color: PlayColors.grass,
              onPressed: () async {
                final model = context.read<NotificationViewModel>();
                final allowed = await model.requestPermission();
                if (allowed) await model.sendTestNotification();
              },
            )
          else
            PlayButton(
              icon: Icons.send_rounded,
              label: 'Send a test',
              color: PlayColors.cream,
              textColor: PlayColors.ink,
              onPressed: () =>
                  context.read<NotificationViewModel>().sendTestNotification(),
            ),
          const SizedBox(height: 10),
          PlayButton(
            icon: Icons.inbox_rounded,
            label: 'History',
            color: PlayColors.cream,
            textColor: PlayColors.ink,
            onPressed: () => Navigator.of(context).pushNamed(
              RouteNames.parentNotifications,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyReminderCard extends StatelessWidget {
  const _EmptyReminderCard();

  @override
  Widget build(BuildContext context) {
    return PlayPanel(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: PlayColors.grape,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.notifications_none_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'No learning reminders yet.',
              style: TextStyle(
                fontFamily: 'Fredoka',
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: PlayColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RemindersHeader extends StatelessWidget {
  const _RemindersHeader({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return PlayPanel(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: const BoxDecoration(
              color: PlayColors.sunshine,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.notifications_active_rounded,
              color: PlayColors.ink,
              size: 34,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Learning reminders',
                  style: TextStyle(
                    fontFamily: 'Fredoka',
                    fontSize: 23,
                    height: 1.15,
                    fontWeight: FontWeight.w600,
                    color: PlayColors.ink,
                  ),
                ),
                Text(
                  count == 1 ? '1 active schedule' : '$count saved schedules',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: PlayColors.ink.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReminderTimeButton extends StatelessWidget {
  const _ReminderTimeButton({
    required this.selectedTime,
    required this.onPressed,
  });

  final TimeOfDay selectedTime;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return PlayButton(
      icon: Icons.schedule_rounded,
      label: selectedTime.format(context),
      color: PlayColors.sunshine,
      onPressed: onPressed,
    );
  }
}

/// One day of the week. Chunky enough to hit, and it goes solid when picked
/// like every other choice in the app.
class _ReminderWeekdayChip extends StatelessWidget {
  const _ReminderWeekdayChip({
    required this.option,
    required this.selected,
    required this.onSelected,
  });

  final _WeekdayOption option;
  final bool selected;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) {
    return Squishy(
      semanticLabel: option.label,
      onTap: () => onSelected(!selected),
      scale: 0.9,
      child: AnimatedContainer(
        duration: PlayMotion.pressDown,
        width: 58,
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? PlayColors.grape : PlayColors.cream,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: [
            BoxShadow(
              color: PlayColors.ink.withValues(alpha: selected ? 0.2 : 0.1),
              offset: const Offset(0, 4),
              blurRadius: 0,
            ),
          ],
        ),
        child: Text(
          option.label,
          style: TextStyle(
            fontFamily: 'Fredoka',
            fontSize: 15,
            height: 1,
            fontWeight: FontWeight.w600,
            color: selected
                ? Colors.white
                : PlayColors.ink.withValues(alpha: 0.6),
          ),
        ),
      ),
    );
  }
}

class _ReminderStatusPill extends StatelessWidget {
  const _ReminderStatusPill({required this.enabled});

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: enabled ? PlayColors.grass : PlayColors.ink.withValues(
          alpha: 0.12,
        ),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        enabled ? 'On' : 'Off',
        style: TextStyle(
          fontFamily: 'Fredoka',
          fontSize: 12,
          height: 1.1,
          fontWeight: FontWeight.w700,
          color: enabled ? Colors.white : PlayColors.ink.withValues(alpha: 0.6),
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
    final accent = reminder.enabled ? PlayColors.sunshine : PlayColors.cream;

    return PlayPanel(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
            child: Icon(
              reminder.enabled
                  ? Icons.notifications_active_rounded
                  : Icons.notifications_off_rounded,
              color: PlayColors.ink.withValues(
                alpha: reminder.enabled ? 1 : 0.45,
              ),
              size: 28,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        reminder.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Fredoka',
                          fontSize: 18,
                          height: 1.15,
                          fontWeight: FontWeight.w600,
                          color: PlayColors.ink,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _ReminderStatusPill(enabled: reminder.enabled),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${_formatReminderTime(reminder.hour, reminder.minute)} · '
                  '${_weekdaySummary(reminder.weekdays)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: PlayColors.ink.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Squishy(
            semanticLabel: reminder.enabled
                ? 'Turn off ${reminder.title}'
                : 'Turn on ${reminder.title}',
            onTap: () => viewModel.toggleReminder(reminder, !reminder.enabled),
            scale: 0.9,
            child: _ReminderSwitch(value: reminder.enabled),
          ),
          const SizedBox(width: 4),
          PlayIconButton(
            icon: Icons.delete_outline_rounded,
            semanticLabel: 'Delete reminder',
            onPressed: () => viewModel.deleteReminder(
              parentId: reminder.parentId,
              reminderId: reminder.id,
            ),
            color: PlayColors.cream,
            iconColor: PlayColors.strawberry,
            size: 44,
          ),
        ],
      ),
    );
  }
}

/// The same chunky toggle the profile form uses, kept small enough to sit in
/// a row next to the delete button.
class _ReminderSwitch extends StatelessWidget {
  const _ReminderSwitch({required this.value});

  final bool value;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: PlayMotion.settleCurve,
      width: 58,
      height: 34,
      padding: const EdgeInsets.all(3),
      alignment: value ? Alignment.centerRight : Alignment.centerLeft,
      decoration: BoxDecoration(
        color:
            value ? PlayColors.grass : PlayColors.ink.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white, width: 3),
      ),
      child: Container(
        width: 22,
        height: 22,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
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
    return PlayPanel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: const BoxDecoration(
                  color: PlayColors.strawberry,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.add_alert_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Add reminder',
                  style: TextStyle(
                    fontFamily: 'Fredoka',
                    fontSize: 21,
                    height: 1.15,
                    fontWeight: FontWeight.w600,
                    color: PlayColors.ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          PlayField(
            controller: titleController,
            label: 'Title',
            icon: Icons.edit_notifications_rounded,
            color: PlayColors.grape,
            labelColor: PlayColors.ink,
          ),
          const SizedBox(height: 16),
          _ReminderTimeButton(
            selectedTime: selectedTime,
            onPressed: onPickTime,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final option in _weekdayOptions)
                _ReminderWeekdayChip(
                  option: option,
                  selected: selectedWeekdays.contains(option.weekday),
                  onSelected: (selected) {
                    onToggleDay(option.weekday, selected);
                  },
                ),
            ],
          ),
          const SizedBox(height: 18),
          PlayButton(
            icon: Icons.add_alert_rounded,
            label: 'Save reminder',
            color: PlayColors.sunshine,
            big: true,
            onPressed: onSubmit,
          ),
        ],
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
