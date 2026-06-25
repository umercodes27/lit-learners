import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/routing/app_router.dart';
import '../../core/routing/route_names.dart';
import '../../models/koala_guide_message.dart';
import '../../viewmodels/active_child_session.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/learning_viewmodel.dart';
import '../../viewmodels/profile_viewmodel.dart';
import '../../widgets/koala_guide.dart';

class ProfileSelectionPage extends StatefulWidget {
  const ProfileSelectionPage({super.key});

  @override
  State<ProfileSelectionPage> createState() => _ProfileSelectionPageState();
}

class _ProfileSelectionPageState extends State<ProfileSelectionPage> {
  String? _loadedParentId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final parent = context.watch<AuthViewModel>().parent;
    if (parent != null && _loadedParentId != parent.id) {
      _loadedParentId = parent.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<ProfileViewModel>().loadProfiles(parent.id);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<ActiveChildSession>();
    final auth = context.watch<AuthViewModel>();
    final profileVm = context.watch<ProfileViewModel>();
    final parent = auth.parent;

    if (parent == null) {
      return const Scaffold(body: Center(child: Text('Parent not signed in.')));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose Learner'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            onPressed: auth.isLoading
                ? null
                : () async {
                    await context.read<AuthViewModel>().signOut();
                    if (!context.mounted) return;
                    context.read<ActiveChildSession>().clear();
                    Navigator.of(context).pushReplacementNamed(
                      RouteNames.login,
                    );
                  },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const ContextualKoalaGuide(
              trigger: KoalaGuideTrigger.profileSelection,
              audience: KoalaGuideAudience.parent,
              fallbackMessage:
                  'Pick a child profile, or unlock parent controls to add, '
                  'edit, and review profiles.',
            ),
            const SizedBox(height: 16),
            if (profileVm.isLoading)
              const Center(child: CircularProgressIndicator())
            else if (profileVm.profiles.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Icon(Icons.child_care, size: 48),
                      const SizedBox(height: 10),
                      Text(
                        'No child profiles yet.',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Create the first profile to start learning.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            for (final profile in profileVm.profiles)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(12),
                    leading: CircleAvatar(
                      child: Text(profile.name.substring(0, 1)),
                    ),
                    title: Text(profile.name),
                    subtitle: Text(
                      'Age ${profile.age} - '
                      '${profile.leaderboardOptIn ? 'Leaderboard on' : 'Private'}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Edit profile',
                          onPressed: () => _openLockedEdit(
                            context,
                            profile.id,
                          ),
                          icon: const Icon(Icons.edit),
                        ),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                    onTap: () async {
                      session.selectProfile(profile);
                      await context
                          .read<LearningViewModel>()
                          .loadForProfile(profile);
                      if (!context.mounted) return;
                      Navigator.of(context)
                          .pushReplacementNamed(RouteNames.childHome);
                    },
                  ),
                ),
              ),
            if (profileVm.errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                profileVm.errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: profileVm.canCreateProfile
                  ? () => _openLockedCreate(context)
                  : () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Maximum 3 child profiles allowed.'),
                        ),
                      );
                    },
              icon: const Icon(Icons.add),
              label: const Text('Add profile'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _openLockedReports(context),
              icon: const Icon(Icons.insights),
              label: const Text('Parent reports'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _openLockedReminders(context),
              icon: const Icon(Icons.notifications_active),
              label: const Text('Learning reminders'),
            ),
            if (parent.canManageAdminContent) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => _openLockedAdminContent(context),
                icon: const Icon(Icons.admin_panel_settings),
                label: const Text('Admin content'),
              ),
            ],
          ],
        ),
      ),
    );
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

  void _openLockedReminders(BuildContext context) {
    Navigator.of(context).pushNamed(
      RouteNames.parentalLock,
      arguments: const ParentalLockArgs(
        successRoute: RouteNames.parentReminders,
      ),
    );
  }

  void _openLockedAdminContent(BuildContext context) {
    Navigator.of(context).pushNamed(
      RouteNames.parentalLock,
      arguments: const ParentalLockArgs(
        successRoute: RouteNames.adminContent,
      ),
    );
  }
}
