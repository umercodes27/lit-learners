import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/routing/route_names.dart';
import '../../viewmodels/admin_auth_viewmodel.dart';
import '../../viewmodels/admin_stats_viewmodel.dart';
import 'widgets/admin_scaffold.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  var _didRequestLoad = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isAdmin = context.watch<AdminAuthViewModel>().isAuthenticated;
    if (isAdmin && !_didRequestLoad) {
      _didRequestLoad = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<AdminStatsViewModel>().load();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final adminAuth = context.watch<AdminAuthViewModel>();
    final stats = context.watch<AdminStatsViewModel>();

    return AdminScaffold(
      title: 'Admin Dashboard',
      subtitle: adminAuth.admin?.role.label ?? 'Admin portal',
      showLogout: true,
      actions: [
        AdminHeaderAction(
          tooltip: 'Refresh',
          icon: Icons.refresh,
          onPressed: stats.isLoading
              ? null
              : () => context.read<AdminStatsViewModel>().load(),
        ),
      ],
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          // Requirement 1: the three counts land in the hero card, so they are
          // the first thing a successful login shows.
          _AdminIdentityCard(
            name: adminAuth.admin?.displayLabel ?? 'Admin',
            role: adminAuth.admin?.role.label ?? 'Admin portal',
            stats: stats,
          ),
          const SizedBox(height: 18),
          if (stats.errorMessage != null) ...[
            AdminInlineError(message: stats.errorMessage!),
            const SizedBox(height: 12),
          ],
          const AdminSectionHeading(
            title: 'Admin Menu',
            subtitle: 'Everything this account is allowed to manage.',
          ),
          const SizedBox(height: 10),
          // Each entry is hidden rather than disabled when the role cannot
          // use it, so the menu shows only what this admin can actually do.
          if (adminAuth.admin?.canManageContent ?? false) ...[
            _AdminMenuTile(
              title: 'Manage Content',
              subtitle: 'Modules, levels, quizzes and media',
              icon: Icons.auto_stories_rounded,
              accent: AppColors.sky,
              onTap: () =>
                  Navigator.of(context).pushNamed(RouteNames.adminContent),
            ),
            const SizedBox(height: 10),
            _AdminMenuTile(
              title: 'AI Authoring',
              subtitle: 'Draft a stage of levels, then check every one',
              icon: Icons.auto_awesome_rounded,
              accent: AppColors.violet,
              onTap: () =>
                  Navigator.of(context).pushNamed(RouteNames.adminAiAuthoring),
            ),
            const SizedBox(height: 10),
          ],
          if (adminAuth.admin?.canViewParentAccounts ?? false) ...[
            _AdminMenuTile(
              title: 'View Parent Accounts',
              subtitle: 'Registered parents (monitoring only)',
              icon: Icons.family_restroom_rounded,
              accent: AppColors.plum,
              onTap: () => Navigator.of(context)
                  .pushNamed(RouteNames.adminParentAccounts),
            ),
            const SizedBox(height: 10),
          ],
          _AdminMenuTile(
            title: 'View Progress Statistics',
            subtitle: 'Module usage and level completion',
            icon: Icons.insights_rounded,
            accent: AppColors.leaf,
            onTap: () => Navigator.of(context)
                .pushNamed(RouteNames.adminProgressStatistics),
          ),
          const SizedBox(height: 10),
          _AdminMenuTile(
            title: 'Admin Logout',
            subtitle: 'End this admin session',
            icon: Icons.logout_rounded,
            accent: AppColors.coral,
            onTap: () => confirmAdminLogout(context),
          ),
        ],
      ),
    );
  }
}

/// Requirement 1: who is signed in, and the three system counts.
///
/// Deliberately the same gradient hero the parent dashboard opens with, so an
/// admin lands on a screen that is recognisably part of the app.
class _AdminIdentityCard extends StatelessWidget {
  const _AdminIdentityCard({
    required this.name,
    required this.role,
    required this.stats,
  });

  final String name;
  final String role;
  final AdminStatsViewModel stats;

  @override
  Widget build(BuildContext context) {
    final data = stats.stats;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: AdminPalette.headerGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.grape.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.honey,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.7),
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.admin_panel_settings_rounded,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        role,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (stats.isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 18),
                child: Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: AdminHeaderStat(
                      icon: Icons.child_care_rounded,
                      value: '${data.totalChildProfiles}',
                      label: 'Child profiles',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: AdminHeaderStat(
                      icon: Icons.people_alt_rounded,
                      value: '${data.totalParentAccounts}',
                      label: 'Parent accounts',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: AdminHeaderStat(
                      icon: Icons.quiz_rounded,
                      value: '${data.totalQuizzes}',
                      label: 'Quizzes',
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _AdminMenuTile extends StatelessWidget {
  const _AdminMenuTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AdminSoftCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          AdminIconChip(icon: icon, color: accent, size: 46),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.ink.withValues(alpha: 0.66),
                        height: 1.25,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Icon(
            Icons.chevron_right_rounded,
            color: AppColors.ink.withValues(alpha: 0.4),
          ),
        ],
      ),
    );
  }
}
