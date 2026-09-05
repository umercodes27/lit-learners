import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
import '../../viewmodels/notification_viewmodel.dart';
import '../../viewmodels/parent_report_viewmodel.dart';
import '../../services/audio/sound_controller.dart';
import '../../viewmodels/profile_viewmodel.dart';
import '../../widgets/child_avatar.dart';
import '../../widgets/play/play.dart';
import '../leaderboard/leaderboard_page.dart';
import '../reminders/parent_reminders_page.dart';

/// The parent's own area, reached on purpose from the child screens.
///
/// It used to be a purple gradient `AppBar`, a Material `NavigationBar` and a
/// column of white panels with hairline borders — the one screen that still
/// looked like the app this used to be. A parent arriving here from their
/// child's screens felt like they had left the app, which is the whole
/// complaint.
///
/// Same information, same order, same actions. It is now built from the play
/// kit, on a coloured ground, so the parent area reads as the grown-up room in
/// a child's house rather than as a different building.
class ParentDashboardPage extends StatefulWidget {
  const ParentDashboardPage({super.key});

  @override
  State<ParentDashboardPage> createState() => _ParentDashboardPageState();
}

class _ParentDashboardPageState extends State<ParentDashboardPage> {
  int _selectedTab = 0;
  String? _loadedParentId;

  static const _tabs = <_DashboardTab>[
    _DashboardTab(
      label: 'Home',
      icon: Icons.home_rounded,
      color: PlayColors.sunshine,
    ),
    _DashboardTab(
      label: 'Leaderboard',
      icon: Icons.emoji_events_rounded,
      color: PlayColors.tangerine,
    ),
    _DashboardTab(
      label: 'Profiles',
      icon: Icons.group_rounded,
      color: PlayColors.mint,
    ),
    _DashboardTab(
      label: 'Reminders',
      icon: Icons.notifications_active_rounded,
      color: PlayColors.sky,
    ),
  ];

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
      body: PlayGround(
        color: PlayColors.grape,
        safeArea: false,
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _DashboardHeader(
                name: _parentLabel(parent.email),
                unread: context.watch<NotificationViewModel>().unreadCount,
                canManageAdmin: parent.canManageAdminContent,
                onNotifications: () => Navigator.of(context).pushNamed(
                  RouteNames.parentNotifications,
                ),
                onAdmin: () => _openAdminLogin(context),
                onLogout: () => _showLogoutSheet(context),
              ),
              Expanded(
                child: IndexedStack(
                  index: _selectedTab,
                  children: [
                    _ActiveChildDashboardTab(
                      parentId: parent.id,
                      onCreateProfile: () => _openLockedCreate(context),
                      onEditProfile: (profile) =>
                          _openLockedEdit(context, profile.id),
                      onDeleteProfile: (profile) =>
                          _confirmDelete(context, profile),
                      onOpenReports: () => _openLockedReports(context),
                      onStartLearning: (profile) =>
                          _startLearning(context, profile),
                    ),
                    _LeaderboardDashboardTab(parentId: parent.id),
                    _ProfilesDashboardTab(
                      parentId: parent.id,
                      onCreateProfile: () => _openLockedCreate(context),
                      onEditProfile: (profile) =>
                          _openLockedEdit(context, profile.id),
                      onDeleteProfile: (profile) =>
                          _confirmDelete(context, profile),
                    ),
                    const LearningRemindersPanel(
                      showGuide: false,
                      padding: EdgeInsets.fromLTRB(16, 16, 16, 24),
                    ),
                  ],
                ),
              ),
              _PlayNavBar(
                tabs: _tabs,
                selectedIndex: _selectedTab,
                onSelected: (index) => setState(() => _selectedTab = index),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _refreshDashboard(String parentId) async {
    await Future.wait([
      context.read<ProfileViewModel>().loadProfiles(parentId),
      context.read<ParentReportViewModel>().loadReport(parentId),
      context.read<LeaderboardViewModel>().loadLeaderboard(parentId: parentId),
      // Also catches up on reminders that fired while the app was closed, so
      // the bell badge is right the moment the dashboard appears.
      context.read<NotificationViewModel>().load(parentId),
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

  /// UC-18 keeps the admin session separate from the parent session, so this
  /// shortcut opens the admin login rather than dropping an authenticated
  /// parent straight into the dashboard. Admin credentials are the gate.
  void _openAdminLogin(BuildContext context) {
    Navigator.of(context).pushNamed(RouteNames.adminLogin);
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
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: PlayDialog(
              icon: Icons.delete_outline_rounded,
              accent: PlayColors.strawberry,
              title: 'Delete child profile?',
              message:
              'This removes ${profile.name} from this device. Progress already '
              'synced to the backend can be restored when the API is '
              'connected.',
              cancelLabel: 'Cancel',
              confirmLabel: 'Delete',
              confirmIcon: Icons.delete_outline_rounded,
              onCancel: () => Navigator.of(dialogContext).pop(false),
              onConfirm: () => Navigator.of(dialogContext).pop(true),
            ),
          ),
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
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: PlayDialog(
              icon: Icons.logout_rounded,
              accent: PlayColors.tangerine,
              title: 'Log out of Parent Area?',
              message: 'Your session will end and progress remains saved.',
              cancelLabel: 'Stay',
              confirmLabel: 'Log out',
              confirmIcon: Icons.logout_rounded,
              onCancel: () => Navigator.of(sheetContext).pop(),
              onConfirm: () async {
                Navigator.of(sheetContext).pop();
                context.read<ActiveChildSession>().clear();
                await context.read<AuthViewModel>().signOut();
                if (!context.mounted) return;
                Navigator.of(context).pushNamedAndRemoveUntil(
                  RouteNames.login,
                  (route) => false,
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _DashboardTab {
  const _DashboardTab({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;
}

/// The greeting and the three things a parent reaches for, painted straight
/// onto the ground instead of into an app bar.
class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({
    required this.name,
    required this.unread,
    required this.canManageAdmin,
    required this.onNotifications,
    required this.onAdmin,
    required this.onLogout,
  });

  final String name;
  final int unread;
  final bool canManageAdmin;
  final VoidCallback onNotifications;
  final VoidCallback onAdmin;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hi, $name 👋',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Fredoka',
                    fontSize: 30,
                    height: 1.1,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Parent Dashboard',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withValues(alpha: 0.78),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _NotificationBell(unread: unread, onPressed: onNotifications),
          if (canManageAdmin) ...[
            const SizedBox(width: 8),
            PlayIconButton(
              icon: Icons.admin_panel_settings_outlined,
              semanticLabel: 'Admin dashboard',
              onPressed: onAdmin,
              color: PlayColors.sunshine,
              iconColor: PlayColors.ink,
              size: 54,
            ),
          ],
          const SizedBox(width: 8),
          PlayIconButton(
            icon: Icons.logout_rounded,
            semanticLabel: 'Log out',
            onPressed: onLogout,
            color: PlayColors.strawberry,
            iconColor: Colors.white,
            size: 54,
          ),
        ],
      ),
    );
  }
}

class _NotificationBell extends StatelessWidget {
  const _NotificationBell({required this.unread, required this.onPressed});

  final int unread;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: unread == 0 ? 'Notifications' : 'Notifications, $unread unread',
      child: ExcludeSemantics(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            PlayIconButton(
              icon: Icons.notifications_rounded,
              semanticLabel: 'Notifications',
              onPressed: onPressed,
              color: PlayColors.card,
              iconColor: PlayColors.grape,
              size: 54,
            ),
            if (unread > 0)
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  constraints: const BoxConstraints(minWidth: 24),
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: PlayColors.strawberry,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                  child: Text(
                    unread > 9 ? '9+' : '$unread',
                    style: const TextStyle(
                      fontFamily: 'Fredoka',
                      color: Colors.white,
                      fontSize: 12,
                      height: 1,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The bottom bar, as four chunky buttons rather than a Material
/// [NavigationBar].
///
/// The selected tab fills with its own colour and grows a label; the others
/// are quiet discs. That is the same "chosen things go solid" rule the quiz
/// answers and the language picker use.
class _PlayNavBar extends StatelessWidget {
  const _PlayNavBar({
    required this.tabs,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<_DashboardTab> tabs;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: PlayColors.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(34)),
      ),
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            for (var index = 0; index < tabs.length; index++)
              Expanded(
                child: _NavItem(
                  tab: tabs[index],
                  selected: index == selectedIndex,
                  onTap: () => onSelected(index),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.tab,
    required this.selected,
    required this.onTap,
  });

  final _DashboardTab tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Squishy(
      semanticLabel: tab.label,
      onTap: onTap,
      scale: 0.9,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: PlayMotion.settleCurve,
        height: 66,
        margin: const EdgeInsets.symmetric(horizontal: 3),
        decoration: BoxDecoration(
          color: selected ? tab.color : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              tab.icon,
              size: 30,
              color: selected
                  ? PlayColors.onGround(tab.color)
                  : PlayColors.ink.withValues(alpha: 0.42),
            ),
            const SizedBox(height: 2),
            Text(
              tab.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Fredoka',
                fontSize: 12,
                height: 1,
                fontWeight: FontWeight.w600,
                color: selected
                    ? PlayColors.onGround(tab.color)
                    : PlayColors.ink.withValues(alpha: 0.42),
              ),
            ),
          ],
        ),
      ),
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
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
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
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          const PlaySectionLabel('Active child'),
          PopIn(
            index: 0,
            child: _ActiveChildCard(
              profile: activeProfile,
              report: childReport,
              onEdit: () => onEditProfile(activeProfile),
              onDelete: () => onDeleteProfile(activeProfile),
              onStart: () => onStartLearning(activeProfile),
            ),
          ),
          const SizedBox(height: 20),
          const PlaySectionLabel('Switch child'),
          _ChildSwitchChips(
            profiles: profiles.profiles,
            activeProfile: activeProfile,
          ),
          const SizedBox(height: 20),
          PlaySectionLabel(
            'Stage progress',
            trailing: PlayIconButton(
              icon: Icons.insights_rounded,
              semanticLabel: 'Reports',
              onPressed: onOpenReports,
              color: PlayColors.sunshine,
              iconColor: PlayColors.ink,
              size: 50,
            ),
          ),
          if (reports.isLoading && childReport == null)
            const _LoadingCard()
          else
            _StageProgressList(report: childReport),
          const SizedBox(height: 20),
          const PlaySectionLabel('Rewards'),
          _RewardSummaryRow(report: childReport),
          const SizedBox(height: 20),
          const PlaySectionLabel('Sound'),
          const _SoundCard(),
          if (profiles.errorMessage != null) ...[
            const SizedBox(height: 14),
            PlayBanner(message: profiles.errorMessage!),
          ],
          if (reports.errorMessage != null) ...[
            const SizedBox(height: 14),
            PlayBanner(message: reports.errorMessage!),
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
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    return RefreshIndicator(
      onRefresh: () => context.read<ProfileViewModel>().loadProfiles(parentId),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          const PlaySectionLabel('Your children'),
          if (profiles.profiles.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _EmptyChildProfilesCard(onCreateProfile: onCreateProfile),
            )
          else
            for (var index = 0; index < profiles.profiles.length; index++)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: PopIn(
                  index: index,
                  child: _ProfileManagementCard(
                    profile: profiles.profiles[index],
                    accentColor: _profileAccent(index),
                    onEdit: () => onEditProfile(profiles.profiles[index]),
                    onDelete: () => onDeleteProfile(profiles.profiles[index]),
                  ),
                ),
              ),
          PlayButton(
            icon: Icons.add_rounded,
            label: 'Add a child profile',
            color: PlayColors.sunshine,
            onPressed: profiles.canCreateProfile ? onCreateProfile : null,
          ),
          if (!profiles.canCreateProfile) ...[
            const SizedBox(height: 10),
            const PlayNote(
              'You can manage up to 3 child profiles in this parent account.',
            ),
          ],
          if (profiles.errorMessage != null) ...[
            const SizedBox(height: 14),
            PlayBanner(message: profiles.errorMessage!),
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
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
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

/// The child a parent is looking at: their face, their numbers, and the one
/// button that hands the phone over.
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
    // The child's own colour, the same one their tile carries on the selection
    // screen, so a parent recognises whose card this is before reading it.
    final tint = PlayColors.byIndex(profile.id.hashCode);

    return PlayPanel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ChildAvatar(
                name: profile.name,
                avatarValue: profile.avatarAsset,
                backgroundColor: tint,
                borderColor: Colors.white,
                radius: 32,
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
                      style: const TextStyle(
                        fontFamily: 'Fredoka',
                        fontSize: 26,
                        height: 1.1,
                        fontWeight: FontWeight.w600,
                        color: PlayColors.ink,
                      ),
                    ),
                    Text(
                      'Age ${profile.age} · Stage $stage learner',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: PlayColors.ink.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ),
              ),
              PlayIconButton(
                icon: Icons.edit_rounded,
                semanticLabel: 'Edit profile',
                onPressed: onEdit,
                color: PlayColors.cream,
                iconColor: PlayColors.grape,
                size: 48,
              ),
              const SizedBox(width: 8),
              PlayIconButton(
                icon: Icons.delete_outline_rounded,
                semanticLabel: 'Delete profile',
                onPressed: onDelete,
                color: PlayColors.cream,
                iconColor: PlayColors.strawberry,
                size: 48,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  value: (report?.completedLevels ?? 0).toString(),
                  label: 'Levels done',
                  color: PlayColors.blueberry,
                  icon: Icons.check_circle_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatTile(
                  value: (report?.starsEarned ?? 0).toString(),
                  label: 'Stars',
                  color: PlayColors.sunshine,
                  icon: Icons.star_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatTile(
                  value: stage.toString(),
                  label: 'Stage',
                  color: PlayColors.mint,
                  icon: Icons.stairs_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          PlayButton(
            icon: Icons.play_arrow_rounded,
            label: 'Start learning',
            color: PlayColors.grass,
            big: true,
            onPressed: onStart,
          ),
        ],
      ),
    );
  }
}

/// One number and what it counts.
class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.value,
    required this.label,
    required this.color,
    required this.icon,
  });

  final String value;
  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white, width: 3),
      ),
      child: Column(
        children: [
          Icon(icon, size: 22, color: PlayColors.onGround(color)),
          const SizedBox(height: 4),
          FittedBox(
            child: Text(
              value,
              maxLines: 1,
              style: TextStyle(
                fontFamily: 'Fredoka',
                fontSize: 26,
                height: 1,
                fontWeight: FontWeight.w700,
                color: PlayColors.onGround(color),
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: PlayColors.onGround(color).withValues(alpha: 0.78),
            ),
          ),
        ],
      ),
    );
  }
}

/// The other children, as faces rather than as Material [ChoiceChip]s.
class _ChildSwitchChips extends StatelessWidget {
  const _ChildSwitchChips({
    required this.profiles,
    required this.activeProfile,
  });

  final List<ChildProfile> profiles;
  final ChildProfile activeProfile;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 104,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: profiles.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final profile = profiles[index];
          final selected = profile.id == activeProfile.id;
          final tint = PlayColors.byIndex(profile.id.hashCode);

          return Squishy(
            semanticLabel: 'Switch to ${profile.name}',
            onTap: () {
              context.read<ActiveChildSession>().selectProfile(profile);
            },
            scale: 0.92,
            child: AnimatedContainer(
              duration: PlayMotion.pressDown,
              width: 88,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: selected ? tint : PlayColors.card,
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: Colors.white, width: 4),
                boxShadow: [
                  BoxShadow(
                    color: PlayColors.ink.withValues(alpha: 0.18),
                    offset: const Offset(0, 5),
                    blurRadius: 0,
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ChildAvatar(
                    name: profile.name,
                    avatarValue: profile.avatarAsset,
                    backgroundColor: selected ? Colors.white : tint,
                    borderColor: Colors.white,
                    radius: 22,
                  ),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      profile.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Fredoka',
                        fontSize: 14,
                        height: 1,
                        fontWeight: FontWeight.w600,
                        color: selected
                            ? PlayColors.onGround(tint)
                            : PlayColors.ink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
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
      return const _InfoCard(
        icon: Icons.auto_stories_rounded,
        title: 'No stage activity yet',
        message: 'Start a level and this area will show module progress.',
      );
    }

    return Column(
      children: [
        for (var index = 0; index < summaries.length; index++)
          Padding(
            padding:
                EdgeInsets.only(bottom: index == summaries.length - 1 ? 0 : 10),
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
  const _StageProgressTile({required this.summary, required this.color});

  final _ModuleProgressSummary summary;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final percent = (summary.progress * 100).round();

    return PlayPanel(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(
              summary.icon,
              color: PlayColors.onGround(color),
              size: 28,
            ),
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
                  style: const TextStyle(
                    fontFamily: 'Fredoka',
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: PlayColors.ink,
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: summary.progress),
                    duration: PlayMotion.enter,
                    curve: PlayMotion.settleCurve,
                    builder: (context, value, _) {
                      return LinearProgressIndicator(
                        // 12px rather than 5: this is the one number a parent
                        // actually reads off this screen.
                        minHeight: 12,
                        value: value,
                        color: color,
                        backgroundColor: color.withValues(alpha: 0.16),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 52,
            child: Text(
              '$percent%',
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontFamily: 'Fredoka',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: PlayColors.ink,
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
            icon: Icons.star_rounded,
            value: (report?.starsEarned ?? 0).toString(),
            label: 'Stars',
            color: PlayColors.sunshine,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _RewardTile(
            icon: Icons.emoji_events_rounded,
            value: (report?.rewardsEarned ?? 0).toString(),
            label: 'Rewards',
            color: PlayColors.sky,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _RewardTile(
            icon: Icons.play_circle_fill_rounded,
            value: (report?.watchedVideoLessons ?? 0).toString(),
            label: 'Videos',
            color: PlayColors.bubblegum,
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
    final foreground = PlayColors.onGround(color);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white, width: 4),
        boxShadow: [
          BoxShadow(
            color: PlayColors.ink.withValues(alpha: 0.18),
            offset: const Offset(0, 5),
            blurRadius: 0,
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: foreground, size: 30),
          const SizedBox(height: 6),
          FittedBox(
            child: Text(
              value,
              maxLines: 1,
              style: TextStyle(
                fontFamily: 'Fredoka',
                fontSize: 30,
                height: 1,
                fontWeight: FontWeight.w700,
                color: foreground,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: foreground.withValues(alpha: 0.8),
            ),
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
    final textColor = PlayColors.onGround(accentColor);

    return PlayPanel(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Column(
          children: [
            Container(
              // Solid, not a gradient. Every card in the app is one colour.
              color: accentColor,
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  ChildAvatar(
                    name: profile.name,
                    avatarValue: profile.avatarAsset,
                    backgroundColor: Colors.white,
                    textColor: PlayColors.ink,
                    borderColor: Colors.white,
                    radius: 28,
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
                            fontFamily: 'Fredoka',
                            fontSize: 22,
                            height: 1.1,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                        ),
                        Text(
                          'Age ${profile.age} · Stage '
                          '${AgeStageHelper.stageForAge(profile.age)} learner',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: textColor.withValues(alpha: 0.76),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    profile.isSynced
                        ? Icons.cloud_done_rounded
                        : Icons.cloud_upload_rounded,
                    color: textColor.withValues(alpha: 0.8),
                    size: 26,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  Expanded(
                    child: PlayButton(
                      icon: Icons.edit_rounded,
                      label: 'Edit',
                      color: PlayColors.cream,
                      textColor: PlayColors.ink,
                      onPressed: onEdit,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: PlayButton(
                      icon: Icons.delete_outline_rounded,
                      label: 'Delete',
                      color: PlayColors.strawberry,
                      onPressed: onDelete,
                    ),
                  ),
                ],
              ),
            ),
          ],
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
        const SizedBox(height: 32),
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
    return PlayPanel(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            width: 86,
            height: 86,
            decoration: const BoxDecoration(
              color: PlayColors.bubblegum,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.child_care_rounded,
              color: Colors.white,
              size: 48,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Create your first child profile',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Fredoka',
              fontSize: 25,
              height: 1.15,
              fontWeight: FontWeight.w600,
              color: PlayColors.ink,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Profiles unlock age-based learning, progress sync, reminders, '
            'and leaderboard sharing.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              height: 1.35,
              fontWeight: FontWeight.w600,
              color: PlayColors.ink.withValues(alpha: 0.62),
            ),
          ),
          const SizedBox(height: 18),
          PlayButton(
            icon: Icons.add_rounded,
            label: 'Add a child profile',
            color: PlayColors.sunshine,
            big: true,
            onPressed: onCreateProfile,
          ),
        ],
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return const PlayPanel(
      child: Row(
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: PlayColors.grape,
            ),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Text(
              'Loading progress...',
              style: TextStyle(
                fontFamily: 'Fredoka',
                fontSize: 17,
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

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return PlayPanel(
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(
              color: PlayColors.sky,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Fredoka',
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: PlayColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.3,
                    fontWeight: FontWeight.w600,
                    color: PlayColors.ink.withValues(alpha: 0.62),
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

/// The parent's control over what the app is allowed to make noise about.
///
/// This lives behind the parental check on purpose. A mute switch on the
/// child's own screens is a switch a two-year-old will find, and a parent will
/// then spend an afternoon wondering why the app went quiet.
class _SoundCard extends StatelessWidget {
  const _SoundCard();

  @override
  Widget build(BuildContext context) {
    final sound = context.watch<SoundController>();

    return PlayPanel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Squishy(
            semanticLabel: sound.muted ? 'Turn sound on' : 'Turn sound off',
            onTap: () => sound.setMuted(!sound.muted),
            scale: 0.98,
            child: Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: sound.muted
                        ? PlayColors.ink.withValues(alpha: 0.12)
                        : PlayColors.grass,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    sound.muted
                        ? Icons.volume_off_rounded
                        : Icons.volume_up_rounded,
                    color: sound.muted
                        ? PlayColors.ink.withValues(alpha: 0.5)
                        : Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sound.muted ? 'Sound is off' : 'Sound is on',
                        style: const TextStyle(
                          fontFamily: 'Fredoka',
                          fontSize: 19,
                          height: 1.2,
                          fontWeight: FontWeight.w600,
                          color: PlayColors.ink,
                        ),
                      ),
                      Text(
                        'Music and effects across the whole app.',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: PlayColors.ink.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _VolumeRow(
            icon: Icons.music_note_rounded,
            label: 'Music',
            value: sound.musicVolume,
            enabled: !sound.muted,
            onChanged: sound.setMusicVolume,
          ),
          _VolumeRow(
            icon: Icons.graphic_eq_rounded,
            label: 'Effects',
            value: sound.sfxVolume,
            enabled: !sound.muted,
            onChanged: sound.setSfxVolume,
          ),
        ],
      ),
    );
  }
}

class _VolumeRow extends StatelessWidget {
  const _VolumeRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final double value;
  final bool enabled;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: Row(
        children: [
          Icon(icon, size: 24, color: PlayColors.grape),
          const SizedBox(width: 8),
          SizedBox(
            width: 62,
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: 'Fredoka',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: PlayColors.ink,
              ),
            ),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 10,
                activeTrackColor: PlayColors.grape,
                inactiveTrackColor: PlayColors.ink.withValues(alpha: 0.12),
                thumbColor: Colors.white,
                overlayColor: PlayColors.grape.withValues(alpha: 0.12),
                thumbShape: const RoundSliderThumbShape(
                  enabledThumbRadius: 13,
                  elevation: 2,
                ),
              ),
              child: Slider(
                value: value,
                onChanged: enabled ? onChanged : null,
              ),
            ),
          ),
          SizedBox(
            width: 44,
            child: Text(
              '${(value * 100).round()}%',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: PlayColors.ink.withValues(alpha: 0.6),
              ),
            ),
          ),
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
    LevelType.tracing => Icons.gesture_outlined,
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

String _parentLabel(String email) {
  final name = email.split('@').first.trim();
  if (name.isEmpty) return 'Parent';
  return name[0].toUpperCase() + name.substring(1);
}

Color _profileAccent(int index) {
  const colors = [
    PlayColors.grape,
    PlayColors.strawberry,
    PlayColors.sky,
  ];
  return colors[index % colors.length];
}

Color _progressColor(int index) {
  const colors = [
    PlayColors.grape,
    PlayColors.sky,
    PlayColors.tangerine,
  ];
  return colors[index % colors.length];
}
