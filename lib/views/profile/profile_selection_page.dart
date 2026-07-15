import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/routing/app_router.dart';
import '../../core/routing/route_names.dart';
import '../../core/utils/age_stage_helper.dart';
import '../../models/child_profile.dart';
import '../../models/learning_level.dart';
import '../../models/parent_report.dart';
import '../../viewmodels/active_child_session.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/leaderboard_viewmodel.dart';
import '../../viewmodels/learning_viewmodel.dart';
import '../../viewmodels/parent_report_viewmodel.dart';
import '../../viewmodels/profile_viewmodel.dart';
import '../leaderboard/leaderboard_page.dart';
import '../reminders/parent_reminders_page.dart';

class ProfileSelectionPage extends StatefulWidget {
  const ProfileSelectionPage({super.key});

  @override
  State<ProfileSelectionPage> createState() => _ProfileSelectionPageState();
}

class _ProfileSelectionPageState extends State<ProfileSelectionPage> {
  int _selectedTab = 0;
  String? _loadedParentId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final parent = context.watch<AuthViewModel>().parent;
    if (parent != null && _loadedParentId != parent.id) {
      _loadedParentId = parent.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _refreshDashboard(parent.id);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final parent = context.watch<AuthViewModel>().parent;

    if (parent == null) {
      return const Scaffold(body: Center(child: Text('Parent not signed in.')));
    }

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 64,
        backgroundColor: AppColors.ink,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Parent Dashboard',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 2),
            Text(
              'Welcome back, ${_parentLabel(parent.email)}',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          if (parent.canManageAdminContent)
            IconButton(
              tooltip: 'Admin dashboard',
              onPressed: () => _openLockedAdminDashboard(context),
              icon: const Icon(Icons.admin_panel_settings_outlined),
            ),
          IconButton(
            tooltip: 'Log out',
            onPressed: () => _showLogoutSheet(context),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedTab,
        children: [
          _ActiveChildDashboardTab(
            parentId: parent.id,
            onCreateProfile: () => _openLockedCreate(context),
            onEditProfile: (profile) => _openLockedEdit(context, profile.id),
            onDeleteProfile: (profile) => _confirmDelete(context, profile),
            onOpenReports: () => _openLockedReports(context),
            onStartLearning: (profile) => _startLearning(context, profile),
          ),
          _LeaderboardDashboardTab(parentId: parent.id),
          _ProfilesDashboardTab(
            parentId: parent.id,
            onCreateProfile: () => _openLockedCreate(context),
            onEditProfile: (profile) => _openLockedEdit(context, profile.id),
            onDeleteProfile: (profile) => _confirmDelete(context, profile),
          ),
          const LearningRemindersPanel(
            showGuide: false,
            padding: EdgeInsets.fromLTRB(16, 16, 16, 24),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedTab,
        onDestinationSelected: (index) => setState(() => _selectedTab = index),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.emoji_events_outlined),
            selectedIcon: Icon(Icons.emoji_events),
            label: 'Leaderboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.group_outlined),
            selectedIcon: Icon(Icons.group),
            label: 'Profiles',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_none),
            selectedIcon: Icon(Icons.notifications_active),
            label: 'Reminders',
          ),
        ],
      ),
    );
  }

  Future<void> _refreshDashboard(String parentId) async {
    await Future.wait([
      context.read<ProfileViewModel>().loadProfiles(parentId),
      context.read<ParentReportViewModel>().loadReport(parentId),
      context.read<LeaderboardViewModel>().loadLeaderboard(parentId: parentId),
    ]);
  }

  void _openLockedCreate(BuildContext context) {
    Navigator.of(context).pushNamed(
      RouteNames.parentalLock,
      arguments: const ParentalLockArgs(
        successRoute: RouteNames.profileEdit,
        successArguments: ProfileEditArgs(),
      ),
    );
  }

  void _openLockedEdit(BuildContext context, String profileId) {
    Navigator.of(context).pushNamed(
      RouteNames.parentalLock,
      arguments: ParentalLockArgs(
        successRoute: RouteNames.profileEdit,
        successArguments: ProfileEditArgs(profileId: profileId),
      ),
    );
  }

  void _openLockedReports(BuildContext context) {
    Navigator.of(context).pushNamed(
      RouteNames.parentalLock,
      arguments: const ParentalLockArgs(
        successRoute: RouteNames.parentReports,
      ),
    );
  }

  void _openLockedAdminDashboard(BuildContext context) {
    Navigator.of(context).pushNamed(
      RouteNames.parentalLock,
      arguments: const ParentalLockArgs(
        successRoute: RouteNames.adminDashboard,
      ),
    );
  }

  Future<void> _startLearning(
    BuildContext context,
    ChildProfile profile,
  ) async {
    context.read<ActiveChildSession>().selectProfile(profile);
    await context.read<LearningViewModel>().loadForProfile(profile);
    if (!context.mounted) return;

    Navigator.of(context).pushReplacementNamed(RouteNames.childHome);
  }

  Future<void> _confirmDelete(
    BuildContext context,
    ChildProfile profile,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete child profile?'),
          content: Text(
            'This removes ${profile.name} from this device. Progress already '
            'synced to the backend can be restored when the API is connected.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Delete'),
            ),
          ],
        );
      },
    );
    if (!context.mounted || confirmed != true) return;

    final activeChild = context.read<ActiveChildSession>().activeChild;
    final deleted = await context.read<ProfileViewModel>().deleteProfile(
          parentId: profile.parentId,
          childId: profile.id,
        );
    if (!context.mounted || !deleted) return;

    if (activeChild?.id == profile.id) {
      context.read<ActiveChildSession>().clear();
    }
    await Future.wait([
      context.read<ParentReportViewModel>().loadReport(profile.parentId),
      context
          .read<LeaderboardViewModel>()
          .loadLeaderboard(parentId: profile.parentId),
    ]);
  }

  Future<void> _showLogoutSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.coral.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.logout, color: AppColors.coral),
                ),
                const SizedBox(height: 14),
                Text(
                  'Log out of Parent Area?',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Your session will end and progress remains saved.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(sheetContext).pop(),
                        child: const Text('Stay'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.coral,
                        ),
                        onPressed: () async {
                          Navigator.of(sheetContext).pop();
                          context.read<ActiveChildSession>().clear();
                          await context.read<AuthViewModel>().signOut();
                          if (!context.mounted) return;
                          Navigator.of(context).pushNamedAndRemoveUntil(
                            RouteNames.login,
                            (route) => false,
                          );
                        },
                        icon: const Icon(Icons.logout),
                        label: const Text('Log out'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ActiveChildDashboardTab extends StatelessWidget {
  const _ActiveChildDashboardTab({
    required this.parentId,
    required this.onCreateProfile,
    required this.onEditProfile,
    required this.onDeleteProfile,
    required this.onOpenReports,
    required this.onStartLearning,
  });

  final String parentId;
  final VoidCallback onCreateProfile;
  final ValueChanged<ChildProfile> onEditProfile;
  final ValueChanged<ChildProfile> onDeleteProfile;
  final VoidCallback onOpenReports;
  final ValueChanged<ChildProfile> onStartLearning;

  @override
  Widget build(BuildContext context) {
    final profiles = context.watch<ProfileViewModel>();
    final reports = context.watch<ParentReportViewModel>();
    final session = context.watch<ActiveChildSession>();

    if (profiles.isLoading && profiles.profiles.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (profiles.profiles.isEmpty) {
      return _EmptyProfilesState(onCreateProfile: onCreateProfile);
    }

    final activeProfile = _resolveActiveProfile(
      profiles.profiles,
      session.activeChild,
    );
    final childReport = _childReportFor(reports.report, activeProfile.id);

    return RefreshIndicator(
      onRefresh: () async {
        await Future.wait([
          context.read<ProfileViewModel>().loadProfiles(parentId),
          context.read<ParentReportViewModel>().loadReport(parentId),
        ]);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          const _SectionLabel('Active child'),
          _ActiveChildCard(
            profile: activeProfile,
            report: childReport,
            onEdit: () => onEditProfile(activeProfile),
            onDelete: () => onDeleteProfile(activeProfile),
            onStart: () => onStartLearning(activeProfile),
          ),
          const SizedBox(height: 16),
          const _SectionLabel('Switch child'),
          _ChildSwitchChips(
            profiles: profiles.profiles,
            activeProfile: activeProfile,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Expanded(child: _SectionLabel('Stage progress')),
              TextButton.icon(
                onPressed: onOpenReports,
                icon: const Icon(Icons.insights, size: 18),
                label: const Text('Reports'),
              ),
            ],
          ),
          if (reports.isLoading && childReport == null)
            const _SoftLoadingCard()
          else
            _StageProgressList(report: childReport),
          const SizedBox(height: 16),
          const _SectionLabel('Rewards'),
          _RewardSummaryRow(report: childReport),
          if (profiles.errorMessage != null) ...[
            const SizedBox(height: 12),
            _InlineError(message: profiles.errorMessage!),
          ],
          if (reports.errorMessage != null) ...[
            const SizedBox(height: 12),
            _InlineError(message: reports.errorMessage!),
          ],
        ],
      ),
    );
  }
}

class _ProfilesDashboardTab extends StatelessWidget {
  const _ProfilesDashboardTab({
    required this.parentId,
    required this.onCreateProfile,
    required this.onEditProfile,
    required this.onDeleteProfile,
  });

  final String parentId;
  final VoidCallback onCreateProfile;
  final ValueChanged<ChildProfile> onEditProfile;
  final ValueChanged<ChildProfile> onDeleteProfile;

  @override
  Widget build(BuildContext context) {
    final profiles = context.watch<ProfileViewModel>();

    if (profiles.isLoading && profiles.profiles.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: () => context.read<ProfileViewModel>().loadProfiles(parentId),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          const _SectionLabel('Your children'),
          if (profiles.profiles.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _EmptyChildProfilesCard(onCreateProfile: onCreateProfile),
            )
          else
            for (var index = 0; index < profiles.profiles.length; index++)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ProfileManagementCard(
                  profile: profiles.profiles[index],
                  accentColor: _profileAccent(index),
                  onEdit: () => onEditProfile(profiles.profiles[index]),
                  onDelete: () => onDeleteProfile(profiles.profiles[index]),
                ),
              ),
          SizedBox(
            height: 52,
            child: OutlinedButton.icon(
              onPressed: profiles.canCreateProfile ? onCreateProfile : null,
              icon: const Icon(Icons.add),
              label: const Text('Add a child profile'),
            ),
          ),
          if (!profiles.canCreateProfile) ...[
            const SizedBox(height: 8),
            const Text(
              'You can manage up to 3 child profiles in this parent account.',
              textAlign: TextAlign.center,
            ),
          ],
          if (profiles.errorMessage != null) ...[
            const SizedBox(height: 12),
            _InlineError(message: profiles.errorMessage!),
          ],
        ],
      ),
    );
  }
}

class _LeaderboardDashboardTab extends StatelessWidget {
  const _LeaderboardDashboardTab({required this.parentId});

  final String parentId;

  @override
  Widget build(BuildContext context) {
    final leaderboard = context.watch<LeaderboardViewModel>();

    if (leaderboard.isLoading && leaderboard.entries.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: () {
        return context.read<LeaderboardViewModel>().loadLeaderboard(
              parentId: parentId,
              stage: leaderboard.selectedStage,
            );
      },
      child: LeaderboardPanel(
        entries: leaderboard.entries,
        selectedStage: leaderboard.selectedStage,
        errorMessage: leaderboard.errorMessage,
        onStageChanged: (stage) {
          context.read<LeaderboardViewModel>().loadLeaderboard(
                parentId: parentId,
                stage: stage,
              );
        },
      ),
    );
  }
}

class _ActiveChildCard extends StatelessWidget {
  const _ActiveChildCard({
    required this.profile,
    required this.report,
    required this.onEdit,
    required this.onDelete,
    required this.onStart,
  });

  final ChildProfile profile;
  final ChildReport? report;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final stage = AgeStageHelper.stageForAge(profile.age);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                _AvatarBubble(
                  name: profile.name,
                  color: AppColors.honey,
                  radius: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.name,
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
                        'Age ${profile.age} - Stage $stage learner',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                _CompactIconButton(
                  tooltip: 'Edit profile',
                  icon: Icons.edit,
                  onPressed: onEdit,
                ),
                const SizedBox(width: 8),
                _CompactIconButton(
                  tooltip: 'Delete profile',
                  icon: Icons.delete_outline,
                  onPressed: onDelete,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _DarkStatTile(
                    value: (report?.completedLevels ?? 0).toString(),
                    label: 'Levels done',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _DarkStatTile(
                    value: (report?.starsEarned ?? 0).toString(),
                    label: 'Stars earned',
                    icon: Icons.star,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _DarkStatTile(
                    value: stage.toString(),
                    label: 'Stage',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.ink,
              ),
              onPressed: onStart,
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Start learning'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChildSwitchChips extends StatelessWidget {
  const _ChildSwitchChips({
    required this.profiles,
    required this.activeProfile,
  });

  final List<ChildProfile> profiles;
  final ChildProfile activeProfile;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final profile in profiles)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                selected: profile.id == activeProfile.id,
                label: Text(profile.name),
                labelStyle: TextStyle(
                  color: profile.id == activeProfile.id
                      ? Colors.white
                      : AppColors.ink,
                  fontWeight: FontWeight.w800,
                ),
                selectedColor: AppColors.ink,
                onSelected: (_) {
                  context.read<ActiveChildSession>().selectProfile(profile);
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _StageProgressList extends StatelessWidget {
  const _StageProgressList({required this.report});

  final ChildReport? report;

  @override
  Widget build(BuildContext context) {
    final summaries = _moduleProgressSummaries(report);

    if (summaries.isEmpty) {
      return const _SoftInfoCard(
        icon: Icons.auto_stories_outlined,
        title: 'No stage activity yet',
        message: 'Start a level and this area will show module progress.',
      );
    }

    return Column(
      children: [
        for (var index = 0; index < summaries.length; index++)
          Padding(
            padding:
                EdgeInsets.only(bottom: index == summaries.length - 1 ? 0 : 8),
            child: _StageProgressTile(
              summary: summaries[index],
              color: _progressColor(index),
            ),
          ),
      ],
    );
  }
}

class _StageProgressTile extends StatelessWidget {
  const _StageProgressTile({
    required this.summary,
    required this.color,
  });

  final _ModuleProgressSummary summary;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final percent = (summary.progress * 100).round();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.panel,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(summary.icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  summary.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    minHeight: 5,
                    value: summary.progress,
                    color: color,
                    backgroundColor: AppColors.line,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 42,
            child: Text(
              '$percent%',
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RewardSummaryRow extends StatelessWidget {
  const _RewardSummaryRow({required this.report});

  final ChildReport? report;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _RewardTile(
            icon: Icons.star,
            value: (report?.starsEarned ?? 0).toString(),
            label: 'Stars',
            color: AppColors.honey,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _RewardTile(
            icon: Icons.emoji_events,
            value: (report?.rewardsEarned ?? 0).toString(),
            label: 'Rewards',
            color: AppColors.sky,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _RewardTile(
            icon: Icons.local_fire_department,
            value: (report?.watchedVideoLessons ?? 0).toString(),
            label: 'Videos',
            color: AppColors.coral,
          ),
        ),
      ],
    );
  }
}

class _RewardTile extends StatelessWidget {
  const _RewardTile({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _ProfileManagementCard extends StatelessWidget {
  const _ProfileManagementCard({
    required this.profile,
    required this.accentColor,
    required this.onEdit,
    required this.onDelete,
  });

  final ChildProfile profile;
  final Color accentColor;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final textColor =
        accentColor.computeLuminance() < 0.45 ? Colors.white : AppColors.ink;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.panel,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            color: accentColor,
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                _AvatarBubble(
                  name: profile.name,
                  color: Colors.white.withValues(alpha: 0.9),
                  textColor: AppColors.ink,
                  radius: 23,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Age ${profile.age} - Stage '
                        '${AgeStageHelper.stageForAge(profile.age)} learner',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            TextStyle(color: textColor.withValues(alpha: 0.72)),
                      ),
                    ],
                  ),
                ),
                Icon(
                  profile.isSynced
                      ? Icons.cloud_done_outlined
                      : Icons.cloud_upload_outlined,
                  color: textColor.withValues(alpha: 0.72),
                ),
              ],
            ),
          ),
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Edit'),
                ),
              ),
              Container(width: 1, height: 38, color: AppColors.line),
              Expanded(
                child: TextButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Delete'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DarkStatTile extends StatelessWidget {
  const _DarkStatTile({
    required this.value,
    required this.label,
    this.icon,
  });

  final String value;
  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: AppColors.honey),
                const SizedBox(width: 4),
              ],
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _CompactIconButton extends StatelessWidget {
  const _CompactIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
      ),
    );
  }
}

class _AvatarBubble extends StatelessWidget {
  const _AvatarBubble({
    required this.name,
    required this.color,
    this.textColor = AppColors.ink,
    this.radius = 20,
  });

  final String name;
  final Color color;
  final Color textColor;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: color,
      child: Text(
        _initials(name),
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: AppColors.ink.withValues(alpha: 0.72),
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}

class _EmptyProfilesState extends StatelessWidget {
  const _EmptyProfilesState({required this.onCreateProfile});

  final VoidCallback onCreateProfile;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 48),
        _EmptyChildProfilesCard(onCreateProfile: onCreateProfile),
      ],
    );
  }
}

class _EmptyChildProfilesCard extends StatelessWidget {
  const _EmptyChildProfilesCard({required this.onCreateProfile});

  final VoidCallback onCreateProfile;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.panel,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: AppColors.mint,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.child_care, color: AppColors.ink),
          ),
          const SizedBox(height: 14),
          Text(
            'Create your first child profile',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Profiles unlock age-based learning, progress sync, reminders, '
            'and leaderboard sharing.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onCreateProfile,
            icon: const Icon(Icons.add),
            label: const Text('Add a child profile'),
          ),
        ],
      ),
    );
  }
}

class _SoftLoadingCard extends StatelessWidget {
  const _SoftLoadingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.panel,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 12),
          Expanded(child: Text('Loading progress...')),
        ],
      ),
    );
  }
}

class _SoftInfoCard extends StatelessWidget {
  const _SoftInfoCard({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.panel,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.sky),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 2),
                Text(message),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.coral.withValues(alpha: 0.1),
        border: Border.all(color: AppColors.coral.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.coral),
          const SizedBox(width: 10),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}

class _ModuleProgressSummary {
  const _ModuleProgressSummary({
    required this.title,
    required this.progress,
    required this.icon,
  });

  final String title;
  final double progress;
  final IconData icon;
}

List<_ModuleProgressSummary> _moduleProgressSummaries(ChildReport? report) {
  if (report == null || report.progressReports.isEmpty) return const [];

  final groups = <String, List<LevelProgressReport>>{};
  for (final progressReport in report.progressReports) {
    groups
        .putIfAbsent(progressReport.moduleTitle, () => [])
        .add(progressReport);
  }

  final summaries = <_ModuleProgressSummary>[];
  for (final entry in groups.entries) {
    final total = entry.value.length;
    final completed = entry.value
        .where((progressReport) => progressReport.progress.completed)
        .length;
    summaries.add(
      _ModuleProgressSummary(
        title: entry.key,
        progress: total == 0 ? 0 : completed / total,
        icon: _moduleIcon(entry.value.first),
      ),
    );
  }

  summaries.sort((a, b) => b.progress.compareTo(a.progress));
  return summaries.take(3).toList();
}

IconData _moduleIcon(LevelProgressReport report) {
  return switch (report.levelType) {
    LevelType.video => Icons.play_circle_outline,
    LevelType.counting => Icons.onetwothree_outlined,
    LevelType.story => Icons.menu_book_outlined,
    LevelType.drawing => Icons.draw_outlined,
    LevelType.matching => Icons.extension_outlined,
    LevelType.flashcards => Icons.style_outlined,
  };
}

ChildProfile _resolveActiveProfile(
  List<ChildProfile> profiles,
  ChildProfile? activeChild,
) {
  if (activeChild != null) {
    for (final profile in profiles) {
      if (profile.id == activeChild.id) return profile;
    }
  }
  return profiles.first;
}

ChildReport? _childReportFor(ParentReport? report, String profileId) {
  if (report == null) return null;
  for (final childReport in report.childReports) {
    if (childReport.profile.id == profileId) return childReport;
  }
  return null;
}

String _initials(String value) {
  final parts = value.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty || parts.first.isEmpty) return 'LL';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
}

String _parentLabel(String email) {
  final name = email.split('@').first.trim();
  if (name.isEmpty) return 'Parent';
  return name[0].toUpperCase() + name.substring(1);
}

Color _profileAccent(int index) {
  const colors = [
    AppColors.ink,
    AppColors.leaf,
    Color(0xFF9B5B09),
  ];
  return colors[index % colors.length];
}

Color _progressColor(int index) {
  const colors = [
    AppColors.leaf,
    AppColors.sky,
    AppColors.honey,
  ];
  return colors[index % colors.length];
}
