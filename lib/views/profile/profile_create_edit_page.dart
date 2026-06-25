import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/routing/app_router.dart';
import '../../core/routing/route_names.dart';
import '../../models/child_profile.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/profile_viewmodel.dart';
import '../../widgets/app_primary_button.dart';

class ProfileCreateEditPage extends StatefulWidget {
  const ProfileCreateEditPage({
    this.args,
    super.key,
  });

  final ProfileEditArgs? args;

  @override
  State<ProfileCreateEditPage> createState() => _ProfileCreateEditPageState();
}

class _ProfileCreateEditPageState extends State<ProfileCreateEditPage> {
  final _nameController = TextEditingController();
  int _age = 3;
  String _avatarAsset = 'koala-blue';
  bool _leaderboardOptIn = false;
  String _displayPreference = 'alias';
  bool _didSeedFields = false;

  static const _avatars = [
    'koala-blue',
    'koala-green',
    'koala-coral',
    'koala-honey',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final parent = context.watch<AuthViewModel>().parent;
    final profileVm = context.watch<ProfileViewModel>();
    final editingProfile = widget.args?.profileId == null
        ? null
        : profileVm.profileById(widget.args!.profileId!);
    final isEditing = editingProfile != null;

    if (!_didSeedFields && editingProfile != null) {
      _seedFields(editingProfile);
    }

    if (parent == null) {
      return const Scaffold(body: Center(child: Text('Parent not signed in.')));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Profile' : 'Create Profile'),
        actions: [
          if (isEditing)
            IconButton(
              tooltip: 'Delete profile',
              onPressed: () => _confirmDelete(context, editingProfile),
              icon: const Icon(Icons.delete),
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _nameController,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Child name',
                prefixIcon: Icon(Icons.badge),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Age',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 1, label: Text('1')),
                ButtonSegment(value: 2, label: Text('2')),
                ButtonSegment(value: 3, label: Text('3')),
                ButtonSegment(value: 4, label: Text('4')),
              ],
              selected: {_age},
              onSelectionChanged: (values) {
                setState(() => _age = values.first);
              },
            ),
            const SizedBox(height: 16),
            Text(
              'Avatar',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final avatar in _avatars)
                  ChoiceChip(
                    label: Text(avatar.replaceFirst('koala-', '')),
                    selected: _avatarAsset == avatar,
                    onSelected: (_) => setState(() => _avatarAsset = avatar),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Opt in to age-group leaderboard'),
              subtitle: const Text('Display is anonymized in parent views.'),
              value: _leaderboardOptIn,
              onChanged: (value) => setState(() => _leaderboardOptIn = value),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _displayPreference,
              decoration: const InputDecoration(
                labelText: 'Leaderboard display',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'alias', child: Text('Alias')),
                DropdownMenuItem(value: 'firstName', child: Text('First name')),
              ],
              onChanged: _leaderboardOptIn
                  ? (value) {
                      if (value == null) return;
                      setState(() => _displayPreference = value);
                    }
                  : null,
            ),
            if (profileVm.errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                profileVm.errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 20),
            AppPrimaryButton(
              icon: Icons.save,
              label: isEditing ? 'Save changes' : 'Create profile',
              onPressed: profileVm.isLoading
                  ? null
                  : () => _save(
                        context,
                        parent.id,
                        editingProfile,
                      ),
            ),
          ],
        ),
      ),
    );
  }

  void _seedFields(ChildProfile profile) {
    _nameController.text = profile.name;
    _age = profile.age;
    _avatarAsset = profile.avatarAsset;
    _leaderboardOptIn = profile.leaderboardOptIn;
    _displayPreference = profile.displayPreference;
    _didSeedFields = true;
  }

  Future<void> _save(
    BuildContext context,
    String parentId,
    ChildProfile? editingProfile,
  ) async {
    final profileVm = context.read<ProfileViewModel>();
    final success = editingProfile == null
        ? await profileVm.createProfile(
            parentId: parentId,
            name: _nameController.text,
            age: _age,
            avatarAsset: _avatarAsset,
            leaderboardOptIn: _leaderboardOptIn,
            displayPreference: _displayPreference,
          )
        : await profileVm.updateProfile(
            profile: editingProfile,
            name: _nameController.text,
            age: _age,
            avatarAsset: _avatarAsset,
            leaderboardOptIn: _leaderboardOptIn,
            displayPreference: _displayPreference,
          );

    if (!context.mounted || !success) return;
    Navigator.of(context).pushNamedAndRemoveUntil(
      RouteNames.profiles,
      (route) => false,
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    ChildProfile profile,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete profile?'),
          content: Text('This removes ${profile.name} from this device.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
    if (!context.mounted || confirmed != true) return;

    final deleted = await context.read<ProfileViewModel>().deleteProfile(
          parentId: profile.parentId,
          childId: profile.id,
        );
    if (!context.mounted || !deleted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(
      RouteNames.profiles,
      (route) => false,
    );
  }
}
