import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../models/admin_stats.dart';
import 'admin_theme.dart';

/// The colour an account carries everywhere on this screen.
///
/// The same scale as the children-per-family chart, so a bar and the people
/// it stands for are recognisably the same thing.
Color accountAccent(int childCount) => switch (childCount) {
      0 => AppColors.coral,
      1 => AppColors.plum,
      2 => AppColors.aqua,
      _ => AppColors.violet,
    };

/// Which bucket of that chart an account belongs to.
String accountBucket(int childCount) => switch (childCount) {
      0 => 'None',
      1 => '1',
      2 => '2',
      _ => '3+',
    };

/// Every account as one tappable disc.
///
/// A hundred families is a hundred cards to scroll and about four screens of
/// very little. As discs the same hundred is a few rows taken in at once, and
/// the colours make the shape of the data visible before a single name is
/// read — a block of coral is a take-up problem you can see from across the
/// room.
///
/// No detail is lost, only moved: tapping a disc opens that account above the
/// grid, which is where anyone was heading after all the scrolling anyway.
class AccountGrid extends StatelessWidget {
  const AccountGrid({
    super.key,
    required this.accounts,
    required this.selectedId,
    required this.onSelect,
  });

  final List<AdminParentAccountSummary> accounts;
  final String? selectedId;
  final ValueChanged<AdminParentAccountSummary> onSelect;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final account in accounts)
          _AccountDot(
            account: account,
            isSelected: account.parentId == selectedId,
            onTap: () => onSelect(account),
          ),
      ],
    );
  }
}

class _AccountDot extends StatelessWidget {
  const _AccountDot({
    required this.account,
    required this.isSelected,
    required this.onTap,
  });

  final AdminParentAccountSummary account;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = accountAccent(account.childProfileCount);
    final count = account.childProfileCount;

    return Tooltip(
      message: '${account.email}\n'
          '${count == 0 ? 'no children yet' : '$count ${count == 1 ? 'child' : 'children'}'}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: isSelected ? 1 : 0.16),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isSelected ? AppColors.ink : accent.withValues(alpha: 0.4),
              width: isSelected ? 2.5 : 1.5,
            ),
          ),
          child: Stack(
            children: [
              Center(
                child: Text(
                  initialsFor(account.email),
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    color: isSelected ? Colors.white : accent,
                  ),
                ),
              ),
              Positioned(
                right: 3,
                bottom: 3,
                child: Container(
                  width: 17,
                  height: 17,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.white : accent,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: isSelected ? accent : Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// From the address, since an account carries no name: "ayesha.khan" becomes
/// AK, "kamran" becomes K.
String initialsFor(String email) {
  final local = email.split('@').first;
  final parts = local.split(RegExp(r'[._\-+]')).where((p) => p.isNotEmpty);
  if (parts.isEmpty) return '?';
  return parts.take(2).map((part) => part[0].toUpperCase()).join();
}

/// What a disc turns into when it is tapped.
class AccountDetailCard extends StatelessWidget {
  const AccountDetailCard({
    super.key,
    required this.account,
    required this.onClose,
  });

  final AdminParentAccountSummary account;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final accent = accountAccent(account.childProfileCount);
    final joined = account.createdAt;
    final count = account.childProfileCount;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AdminSoftCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AdminIconChip(icon: Icons.person_rounded, color: accent),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    account.email,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w900),
                  ),
                ),
                IconButton(
                  onPressed: onClose,
                  icon: const Icon(Icons.close_rounded, size: 20),
                  tooltip: 'Close',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                AdminPill(
                  icon: Icons.child_care_rounded,
                  label: count == 0
                      ? 'no children yet'
                      : '$count ${count == 1 ? 'child' : 'children'}',
                  accent: accent,
                ),
                if (joined != null)
                  AdminPill(
                    icon: Icons.calendar_today_rounded,
                    label: 'Joined ${joined.year}-'
                        '${_two(joined.month)}-${_two(joined.day)}',
                    accent: AppColors.violet,
                  ),
                AdminPill(
                  icon: Icons.tag_rounded,
                  label: account.parentId,
                  accent: AppColors.lilac,
                ),
              ],
            ),
            if (count == 0) ...[
              const SizedBox(height: 10),
              Text(
                'Registered but never added a child, so nobody on this '
                'account has started learning.',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _two(int value) => value.toString().padLeft(2, '0');
}
