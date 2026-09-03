import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/avatar_presets.dart';
import '../../core/routing/app_router.dart';
import '../../core/routing/route_names.dart';
import '../../models/child_profile.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/profile_viewmodel.dart';
import '../../widgets/app_primary_button.dart';
import '../../widgets/child_avatar.dart';

/// The ages the learning content is authored for. `AgeStageHelper` turns each
/// one into its own stage, so anything outside this range has no content of
/// its own to serve.
const _minAge = 1;
const _maxAge = 4;

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
  int _age = _minAge;
  String _avatarAsset = AvatarPresets.fallback.id;
  bool _leaderboardOptIn = false;
  String _displayPreference = 'alias';
  bool _didSeedFields = false;
  bool _isUploadingAvatar = false;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_refreshAvatarPreview);
  }

  @override
  void dispose() {
    _nameController.removeListener(_refreshAvatarPreview);
    _nameController.dispose();
    super.dispose();
  }

  void _refreshAvatarPreview() {
    if (mounted) setState(() {});
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
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            _ProfileFormHero(isEditing: isEditing),
            const SizedBox(height: 16),
            _FancyProfileField(
              child: TextField(
                controller: _nameController,
                textInputAction: TextInputAction.done,
                cursorColor: AppColors.plum,
                decoration: const InputDecoration(
                  labelText: 'Child name',
                  prefixIcon: Icon(Icons.badge_rounded),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(height: 8),
            const _SectionHeading(
              icon: Icons.cake_rounded,
              label: 'Age',
              helper: 'Choose an age from $_minAge to $_maxAge.',
            ),
            const SizedBox(height: 10),
            _AgeSelector(
              age: _age,
              onChanged: (age) => setState(() => _age = age),
            ),
            const SizedBox(height: 16),
            const _SectionHeading(
              icon: Icons.face_rounded,
              label: 'Avatar',
              helper: 'Pick a buddy, or use a photo.',
            ),
            const SizedBox(height: 8),
            _AvatarPicker(
              name: _nameController.text.trim().isEmpty
                  ? 'Learner'
                  : _nameController.text,
              selectedAvatar: _avatarAsset,
              onAvatarSelected: (avatar) {
                setState(() => _avatarAsset = avatar);
              },
              onPickPhoto: _pickAvatarPhoto,
            ),
            const SizedBox(height: 16),
            _FancyProfileField(
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Opt in to age-group leaderboard'),
                subtitle: const Text('Display is anonymized in parent views.'),
                activeThumbColor: AppColors.honey,
                activeTrackColor: AppColors.violet,
                value: _leaderboardOptIn,
                onChanged: (value) {
                  setState(() => _leaderboardOptIn = value);
                },
              ),
            ),
            const SizedBox(height: 8),
            _FancyProfileField(
              child: DropdownButtonFormField<String>(
                initialValue: _displayPreference,
                decoration: const InputDecoration(
                  labelText: 'Leaderboard display',
                  prefixIcon: Icon(Icons.visibility_rounded),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
                items: const [
                  DropdownMenuItem(value: 'alias', child: Text('Alias')),
                  DropdownMenuItem(
                    value: 'firstName',
                    child: Text('First name'),
                  ),
                ],
                onChanged: _leaderboardOptIn
                    ? (value) {
                        if (value == null) return;
                        setState(() => _displayPreference = value);
                      }
                    : null,
              ),
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
              icon: _isUploadingAvatar ? Icons.cloud_upload : Icons.save,
              label: _isUploadingAvatar
                  ? 'Uploading avatar...'
                  : isEditing
                      ? 'Save changes'
                      : 'Create profile',
              onPressed: profileVm.isLoading || _isUploadingAvatar
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
    // Clamped: a profile saved before the age range narrowed to 1-4 would
    // otherwise land on no chip at all and fail validation on save.
    _age = profile.age.clamp(_minAge, _maxAge);
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
    final avatarForSave = await _avatarForSave(parentId, editingProfile);
    if (!context.mounted) return;
    // A photo that would not upload must not block creating the profile: the
    // parent keeps their details and falls back to a colour avatar.
    if (avatarForSave == null) {
      final saveWithoutPhoto = await _confirmSaveWithoutPhoto(context);
      if (!context.mounted || !saveWithoutPhoto) return;
      setState(() => _avatarAsset = _fallbackAvatar(editingProfile));
    }
    final resolvedAvatar = avatarForSave ?? _avatarAsset;

    final success = editingProfile == null
        ? await profileVm.createProfile(
            parentId: parentId,
            name: _nameController.text,
            age: _age,
            avatarAsset: resolvedAvatar,
            leaderboardOptIn: _leaderboardOptIn,
            displayPreference: _displayPreference,
          )
        : await profileVm.updateProfile(
            profile: editingProfile,
            name: _nameController.text,
            age: _age,
            avatarAsset: resolvedAvatar,
            leaderboardOptIn: _leaderboardOptIn,
            displayPreference: _displayPreference,
          );

    if (!context.mounted || !success) return;
    _leaveForm(context);
  }

  /// Back to wherever this form was opened from, unwinding the parental lock
  /// on the way. The predicate keeps the child selection screen underneath
  /// when there is one, so the parent area stays one back gesture deep; on a
  /// brand new account nothing matches and the child selection screen becomes
  /// the new root.
  void _leaveForm(BuildContext context) {
    Navigator.of(context).pushNamedAndRemoveUntil(
      widget.args?.returnRoute ?? RouteNames.parentDashboard,
      (route) => route.settings.name == RouteNames.childSelection,
    );
  }

  /// Camera or gallery, then an explanation of why the app is about to ask,
  /// and only then the picker that raises the system permission prompt. A
  /// parent who says no here never sees an OS dialog they did not expect.
  Future<void> _pickAvatarPhoto() async {
    final source = await _chooseImageSource();
    if (source == null || !mounted) return;

    final proceed = await _confirmPhotoAccess(source);
    if (proceed != true || !mounted) return;

    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 720,
        imageQuality: 82,
      );
      if (picked == null || !mounted) return;
      setState(() => _avatarAsset = Uri.file(picked.path).toString());
    } on PlatformException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_pickerErrorMessage(error, source)),
          duration: const Duration(seconds: 6),
        ),
      );
    }
  }

  Future<ImageSource?> _chooseImageSource() {
    return showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Text(
                  'Add a profile photo',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
              ListTile(
                leading: const Icon(
                  Icons.photo_camera_rounded,
                  color: AppColors.plum,
                ),
                title: const Text('Take a photo'),
                subtitle: const Text('Uses the camera on this device.'),
                onTap: () =>
                    Navigator.of(sheetContext).pop(ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(
                  Icons.photo_library_rounded,
                  color: AppColors.plum,
                ),
                title: const Text('Choose from gallery'),
                subtitle: const Text('Pick a picture already on this device.'),
                onTap: () =>
                    Navigator.of(sheetContext).pop(ImageSource.gallery),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Future<bool?> _confirmPhotoAccess(ImageSource source) {
    final isCamera = source == ImageSource.camera;
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          icon: Icon(
            isCamera
                ? Icons.photo_camera_rounded
                : Icons.photo_library_rounded,
            color: AppColors.plum,
          ),
          title: Text(
            isCamera ? 'Allow camera access?' : 'Allow photo access?',
          ),
          content: Text(
            isCamera
                ? 'Little Learners needs the camera to take this profile '
                    'photo. The picture stays on this device until you save '
                    'the profile, and it is only used as the child avatar.'
                : 'Little Learners needs access to your photos so you can '
                    'pick a profile picture. Only the picture you choose is '
                    'used, and only as the child avatar.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Not now'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Continue'),
            ),
          ],
        );
      },
    );
  }

  /// A refused system prompt is not an error the parent can retry away: the
  /// only way back is the device settings, so say that instead of the code.
  String _pickerErrorMessage(PlatformException error, ImageSource source) {
    if (error.code == 'camera_access_denied') {
      return 'Camera access is turned off for Little Learners. Turn it on in '
          'your device settings, or pick a buddy avatar instead.';
    }
    if (error.code == 'photo_access_denied') {
      return 'Photo access is turned off for Little Learners. Turn it on in '
          'your device settings, or pick a buddy avatar instead.';
    }
    return source == ImageSource.camera
        ? 'The camera could not be opened. You can pick a buddy avatar '
            'instead.'
        : 'That picture could not be opened. You can pick a buddy avatar '
            'instead.';
  }

  Future<String?> _avatarForSave(
    String parentId,
    ChildProfile? editingProfile,
  ) async {
    if (!_avatarAsset.startsWith('file://')) return _avatarAsset;
    if (Firebase.apps.isEmpty) return _avatarAsset;

    setState(() => _isUploadingAvatar = true);
    try {
      final filePath = Uri.parse(_avatarAsset).toFilePath();
      final extension = _extensionFor(filePath);
      final profilePart = editingProfile?.id ?? 'new';
      final objectName =
          '$profilePart-${DateTime.now().microsecondsSinceEpoch}.$extension';
      final ref = FirebaseStorage.instance.ref(
        'profileAvatars/$parentId/$objectName',
      );
      await ref.putFile(
        File(filePath),
        SettableMetadata(contentType: _contentTypeFor(extension)),
      );
      return ref.getDownloadURL();
    } on FirebaseException catch (error) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_uploadErrorMessage(error)),
          duration: const Duration(seconds: 6),
        ),
      );
      return null;
    } finally {
      if (mounted) setState(() => _isUploadingAvatar = false);
    }
  }

  /// Firebase Storage error codes say little to a parent, and the two common
  /// ones here both mean the project is not set up rather than that they did
  /// something wrong.
  String _uploadErrorMessage(FirebaseException error) {
    return switch (error.code) {
      'object-not-found' || 'bucket-not-found' =>
        'Photo upload is unavailable: this app\'s photo storage is not set up '
            'yet. You can still pick a colour avatar.',
      'unauthorized' =>
        'Photo upload was not permitted. You can still pick a colour avatar.',
      'retry-limit-exceeded' || 'network-request-failed' =>
        'Photo upload timed out. Check your connection and try again.',
      _ => 'Photo upload failed: ${error.message ?? error.code}',
    };
  }

  Future<bool> _confirmSaveWithoutPhoto(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Save without the photo?'),
          content: const Text(
            'The photo could not be uploaded. The profile can be saved with a '
            'colour avatar instead, and you can add a photo later.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Back'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Save anyway'),
            ),
          ],
        );
      },
    );
    return confirmed ?? false;
  }

  /// Whatever the profile had before the failed photo pick, or the first
  /// colour avatar for a brand new profile.
  String _fallbackAvatar(ChildProfile? editingProfile) {
    final previous = editingProfile?.avatarAsset;
    if (previous != null && !previous.startsWith('file://')) return previous;
    return AvatarPresets.fallback.id;
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
    _leaveForm(context);
  }
}

class _ProfileFormHero extends StatelessWidget {
  const _ProfileFormHero({required this.isEditing});

  final bool isEditing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.grape, AppColors.violet],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.honey,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              isEditing ? Icons.edit_rounded : Icons.add_reaction_rounded,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isEditing ? 'Make this profile sparkle' : 'Create a learner',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FancyProfileField extends StatelessWidget {
  const _FancyProfileField({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    // The panel colour lives on a Material, not on the outer box: a tile child
    // (the leaderboard switch) paints its ink splash on the nearest Material
    // ancestor, and a plain coloured Container would cover it. The Container
    // is kept for the drop shadow, which Material's own elevation draws
    // differently.
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.grape.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: AppColors.panel,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: AppColors.lilac.withValues(alpha: 0.58)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          child: child,
        ),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.icon,
    required this.label,
    required this.helper,
  });

  final IconData icon;
  final String label;
  final String helper;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.coral, size: 20),
        const SizedBox(width: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            helper,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.ink.withValues(alpha: 0.58),
                ),
          ),
        ),
      ],
    );
  }
}

class _AgeSelector extends StatelessWidget {
  const _AgeSelector({
    required this.age,
    required this.onChanged,
  });

  final int age;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var option = _minAge; option <= _maxAge; option++)
          ChoiceChip(
            label: Text('$option'),
            selected: age == option,
            selectedColor: AppColors.honey,
            backgroundColor: AppColors.lavender,
            labelStyle: TextStyle(
              color: age == option ? AppColors.coral : AppColors.ink,
              fontWeight: FontWeight.w900,
            ),
            onSelected: (_) => onChanged(option),
          ),
      ],
    );
  }
}

class _AvatarPicker extends StatelessWidget {
  const _AvatarPicker({
    required this.name,
    required this.selectedAvatar,
    required this.onAvatarSelected,
    required this.onPickPhoto,
  });

  final String name;
  final String selectedAvatar;
  final ValueChanged<String> onAvatarSelected;
  final VoidCallback onPickPhoto;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.lavender,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.lilac.withValues(alpha: 0.62)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ChildAvatar(
                name: name,
                avatarValue: selectedAvatar,
                radius: 32,
                borderColor: Colors.white,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Profile photo',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Tap a buddy below, or use a photo of your child.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.ink.withValues(alpha: 0.6),
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final preset in AvatarPresets.all)
                _PresetOption(
                  preset: preset,
                  selected: selectedAvatar == preset.id,
                  onTap: () => onAvatarSelected(preset.id),
                ),
            ],
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: onPickPhoto,
            icon: const Icon(Icons.add_a_photo_rounded),
            label: const Text('Use a photo'),
          ),
        ],
      ),
    );
  }
}

class _PresetOption extends StatelessWidget {
  const _PresetOption({
    required this.preset,
    required this.selected,
    required this.onTap,
  });

  final AvatarPreset preset;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '${preset.label} avatar',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ChildAvatar(
                name: preset.label,
                avatarValue: preset.id,
                radius: 26,
                borderColor: selected ? AppColors.coral : Colors.white,
              ),
              const SizedBox(height: 6),
              Text(
                preset.label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: selected
                      ? AppColors.coral
                      : AppColors.ink.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _extensionFor(String filePath) {
  final extension = filePath.split('.').last.toLowerCase();
  return switch (extension) {
    'png' || 'webp' || 'heic' => extension,
    _ => 'jpg',
  };
}

String _contentTypeFor(String extension) {
  return switch (extension) {
    'png' => 'image/png',
    'webp' => 'image/webp',
    'heic' => 'image/heic',
    _ => 'image/jpeg',
  };
}
