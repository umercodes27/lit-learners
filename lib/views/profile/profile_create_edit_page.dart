import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/constants/avatar_presets.dart';
import '../../core/routing/app_router.dart';
import '../../core/routing/route_names.dart';
import '../../models/child_profile.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/profile_viewmodel.dart';
import '../../widgets/child_avatar.dart';
import '../../widgets/play/play.dart';

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
      body: PlayGround(
        color: PlayColors.bubblegum,
        safeArea: false,
        child: SafeArea(
          child: Column(
            children: [
              PlayHeader(
                title: isEditing ? 'Edit Profile' : 'Create Profile',
                onBack: Navigator.of(context).canPop()
                    ? () => Navigator.of(context).maybePop()
                    : null,
                trailing: isEditing
                    ? PlayIconButton(
                        icon: Icons.delete_outline_rounded,
                        semanticLabel: 'Delete profile',
                        onPressed: () =>
                            _confirmDelete(context, editingProfile),
                        color: PlayColors.card,
                        iconColor: PlayColors.strawberry,
                        size: 54,
                      )
                    : null,
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                  children: [
                    _ProfileFormHero(isEditing: isEditing),
                    const SizedBox(height: 18),
                    PlayField(
                      controller: _nameController,
                      label: 'Child name',
                      icon: Icons.badge_rounded,
                      color: PlayColors.grape,
                      textInputAction: TextInputAction.done,
                    ),
                    const SizedBox(height: 20),
                    const _SectionHeading(
                      icon: Icons.cake_rounded,
                      label: 'Age',
                      helper: 'Choose an age from $_minAge to $_maxAge.',
                    ),
                    const SizedBox(height: 12),
                    _AgeSelector(
                      age: _age,
                      onChanged: (age) => setState(() => _age = age),
                    ),
                    const SizedBox(height: 20),
                    const _SectionHeading(
                      icon: Icons.face_rounded,
                      label: 'Avatar',
                      helper: 'Pick a buddy, or use a photo.',
                    ),
                    const SizedBox(height: 12),
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
                    const SizedBox(height: 20),
                    _LeaderboardCard(
                      optIn: _leaderboardOptIn,
                      preference: _displayPreference,
                      onOptInChanged: (value) {
                        setState(() => _leaderboardOptIn = value);
                      },
                      onPreferenceChanged: (value) {
                        setState(() => _displayPreference = value);
                      },
                    ),
                  ],
                ),
              ),
              // Pinned below the list rather than sitting at the end of it.
              // This form is long enough that the save button fell outside
              // the ListView's built range, which left a parent scrolling to
              // find the only way to finish.
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (profileVm.errorMessage != null) ...[
                      PlayBanner(message: profileVm.errorMessage!),
                      const SizedBox(height: 12),
                    ],
                    PlayButton(
                      icon: _isUploadingAvatar
                          ? Icons.cloud_upload_rounded
                          : Icons.save_rounded,
                      label: _isUploadingAvatar
                          ? 'Uploading avatar...'
                          : isEditing
                              ? 'Save changes'
                              : 'Create profile',
                      color: PlayColors.sunshine,
                      big: true,
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
            ],
          ),
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
      backgroundColor: Colors.transparent,
      // Without this the sheet is capped at nine sixteenths of the screen, and
      // rows sized for a finger no longer fit inside that.
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Material(
              color: Colors.transparent,
              child: PlayPanel(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Add a profile photo',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Fredoka',
                        fontSize: 23,
                        fontWeight: FontWeight.w600,
                        color: PlayColors.ink,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _SourceOption(
                      icon: Icons.photo_camera_rounded,
                      color: PlayColors.grape,
                      title: 'Take a photo',
                      subtitle: 'Uses the camera on this device.',
                      onTap: () =>
                          Navigator.of(sheetContext).pop(ImageSource.camera),
                    ),
                    const SizedBox(height: 10),
                    _SourceOption(
                      icon: Icons.photo_library_rounded,
                      color: PlayColors.sky,
                      title: 'Choose from gallery',
                      subtitle: 'Pick a picture already on this device.',
                      onTap: () =>
                          Navigator.of(sheetContext).pop(ImageSource.gallery),
                    ),
                  ],
                ),
              ),
            ),
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
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: PlayDialog(
              icon: isCamera
                  ? Icons.photo_camera_rounded
                  : Icons.photo_library_rounded,
              accent: PlayColors.sky,
              title: isCamera ? 'Allow camera access?' : 'Allow photo access?',
              message: isCamera
                  ? 'Little Learners needs the camera to take this profile '
                      'photo. The picture stays on this device until you save '
                      'the profile, and it is only used as the child avatar.'
                  : 'Little Learners needs access to your photos so you can '
                      'pick a profile picture. Only the picture you choose is '
                      'used, and only as the child avatar.',
              cancelLabel: 'Not now',
              confirmLabel: 'Continue',
              confirmIcon: Icons.arrow_forward_rounded,
              onCancel: () => Navigator.of(dialogContext).pop(false),
              onConfirm: () => Navigator.of(dialogContext).pop(true),
            ),
          ),
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
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: PlayDialog(
              icon: Icons.image_not_supported_rounded,
              accent: PlayColors.tangerine,
              title: 'Save without the photo?',
              message:
                  'The photo could not be uploaded. The profile can be saved '
                  'with a colour avatar instead, and you can add a photo '
                  'later.',
              cancelLabel: 'Back',
              confirmLabel: 'Save anyway',
              confirmIcon: Icons.save_rounded,
              onCancel: () => Navigator.of(dialogContext).pop(false),
              onConfirm: () => Navigator.of(dialogContext).pop(true),
            ),
          ),
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
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: PlayDialog(
              icon: Icons.delete_outline_rounded,
              accent: PlayColors.strawberry,
              title: 'Delete profile?',
              message: 'This removes ${profile.name} from this device.',
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

    final deleted = await context.read<ProfileViewModel>().deleteProfile(
          parentId: profile.parentId,
          childId: profile.id,
        );
    if (!context.mounted || !deleted) return;
    _leaveForm(context);
  }
}

/// What this form is for, on a white slab rather than a purple gradient.
class _ProfileFormHero extends StatelessWidget {
  const _ProfileFormHero({required this.isEditing});

  final bool isEditing;

  @override
  Widget build(BuildContext context) {
    return PlayPanel(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: const BoxDecoration(
              color: PlayColors.sunshine,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isEditing ? Icons.edit_rounded : Icons.add_reaction_rounded,
              color: PlayColors.ink,
              size: 36,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              isEditing ? 'Make this profile sparkle' : 'Create a learner',
              style: const TextStyle(
                fontFamily: 'Fredoka',
                fontSize: 25,
                height: 1.15,
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

/// A titled section of the form, painted onto the ground.
///
/// The helper line now sits under the label instead of beside it: at play-kit
/// type sizes the two no longer fit on one row of a narrow phone, and the
/// helper is the half that was getting ellipsised away.
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
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.white, size: 26),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontFamily: 'Fredoka',
                  fontSize: 24,
                  height: 1.1,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            helper,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }
}

/// The four ages, as tiles big enough to hit rather than as Material chips.
class _AgeSelector extends StatelessWidget {
  const _AgeSelector({
    required this.age,
    required this.onChanged,
  });

  final int age;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var option = _minAge; option <= _maxAge; option++) ...[
          if (option > _minAge) const SizedBox(width: 10),
          Expanded(
            child: _AgeTile(
              age: option,
              selected: age == option,
              color: PlayColors.byIndex(option),
              onTap: () => onChanged(option),
            ),
          ),
        ],
      ],
    );
  }
}

class _AgeTile extends StatelessWidget {
  const _AgeTile({
    required this.age,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final int age;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Squishy(
      semanticLabel: 'Age $age',
      onTap: onTap,
      child: AnimatedContainer(
        duration: PlayMotion.pressDown,
        height: 76,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? color : PlayColors.card,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: Colors.white, width: 4),
          boxShadow: [
            BoxShadow(
              color: PlayColors.ink.withValues(alpha: selected ? 0.24 : 0.14),
              offset: const Offset(0, 5),
              blurRadius: 0,
            ),
          ],
        ),
        child: Text(
          '$age',
          style: TextStyle(
            fontFamily: 'Fredoka',
            fontSize: 34,
            height: 1,
            fontWeight: FontWeight.w700,
            color: selected
                ? PlayColors.onGround(color)
                : PlayColors.ink.withValues(alpha: 0.55),
          ),
        ),
      ),
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
    return PlayPanel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ChildAvatar(
                name: name,
                avatarValue: selectedAvatar,
                radius: 38,
                borderColor: Colors.white,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Profile photo',
                      style: TextStyle(
                        fontFamily: 'Fredoka',
                        fontSize: 20,
                        height: 1.15,
                        fontWeight: FontWeight.w600,
                        color: PlayColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Tap a buddy below, or use a photo of your child.',
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.3,
                        fontWeight: FontWeight.w600,
                        color: PlayColors.ink.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              for (final preset in AvatarPresets.all)
                _PresetOption(
                  preset: preset,
                  selected: selectedAvatar == preset.id,
                  onTap: () => onAvatarSelected(preset.id),
                ),
            ],
          ),
          const SizedBox(height: 16),
          PlayButton(
            icon: Icons.add_a_photo_rounded,
            label: 'Use a photo',
            color: PlayColors.sky,
            onPressed: onPickPhoto,
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
    // The chosen buddy is carried by the tile going solid, the same way every
    // other choice in the app reads. The old version marked it with a 2px
    // coral ring, which is invisible at arm's length.
    return Squishy(
      semanticLabel: '${preset.label} avatar',
      onTap: onTap,
      scale: 0.9,
      child: AnimatedContainer(
        duration: PlayMotion.pressDown,
        width: 88,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? PlayColors.grape : PlayColors.cream,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: [
            BoxShadow(
              color: PlayColors.ink.withValues(alpha: selected ? 0.22 : 0.12),
              offset: const Offset(0, 4),
              blurRadius: 0,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ChildAvatar(
              name: preset.label,
              avatarValue: preset.id,
              radius: 28,
              borderColor: Colors.white,
            ),
            const SizedBox(height: 6),
            Text(
              preset.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Fredoka',
                fontSize: 14,
                height: 1,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : PlayColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The leaderboard opt-in and, once it is on, how the child is named there.
///
/// This was a [SwitchListTile] and a [DropdownButtonFormField] inside a white
/// `DecoratedBox`. That nesting throws "ListTile background color or ink
/// splashes may be invisible" on every build, which is what all four of this
/// screen's widget tests were failing on. Neither Material control survives.
class _LeaderboardCard extends StatelessWidget {
  const _LeaderboardCard({
    required this.optIn,
    required this.preference,
    required this.onOptInChanged,
    required this.onPreferenceChanged,
  });

  final bool optIn;
  final String preference;
  final ValueChanged<bool> onOptInChanged;
  final ValueChanged<String> onPreferenceChanged;

  @override
  Widget build(BuildContext context) {
    return PlayPanel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Squishy(
            semanticLabel: 'Opt in to age-group leaderboard',
            onTap: () => onOptInChanged(!optIn),
            scale: 0.98,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Opt in to age-group leaderboard',
                        style: TextStyle(
                          fontFamily: 'Fredoka',
                          fontSize: 19,
                          height: 1.2,
                          fontWeight: FontWeight.w600,
                          color: PlayColors.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Display is anonymized in parent views.',
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.3,
                          fontWeight: FontWeight.w600,
                          color: PlayColors.ink.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _PlaySwitch(value: optIn),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Leaderboard display',
            style: TextStyle(
              fontFamily: 'Fredoka',
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: PlayColors.ink.withValues(alpha: optIn ? 1 : 0.4),
            ),
          ),
          const SizedBox(height: 10),
          // Two options shown side by side rather than hidden behind a
          // dropdown: a parent should be able to see what the choice is
          // without opening anything.
          Opacity(
            opacity: optIn ? 1 : 0.45,
            child: IgnorePointer(
              ignoring: !optIn,
              child: Row(
                children: [
                  Expanded(
                    child: PlayChoice(
                      label: 'Alias',
                      selected: preference == 'alias',
                      color: PlayColors.grape,
                      onTap: () => onPreferenceChanged('alias'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: PlayChoice(
                      label: 'First name',
                      selected: preference == 'firstName',
                      color: PlayColors.grape,
                      onTap: () => onPreferenceChanged('firstName'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A chunky toggle, sized like everything else a finger lands on.
class _PlaySwitch extends StatelessWidget {
  const _PlaySwitch({required this.value});

  final bool value;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: PlayMotion.settleCurve,
      width: 76,
      height: 44,
      padding: const EdgeInsets.all(4),
      alignment: value ? Alignment.centerRight : Alignment.centerLeft,
      decoration: BoxDecoration(
        color: value ? PlayColors.grass : PlayColors.ink.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white, width: 3),
      ),
      child: Container(
        width: 30,
        height: 30,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
        child: value
            ? const Icon(Icons.check_rounded, size: 20, color: PlayColors.grass)
            : null,
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

/// Camera or gallery, as a chunky row rather than a [ListTile].
class _SourceOption extends StatelessWidget {
  const _SourceOption({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Squishy(
      semanticLabel: title,
      onTap: onTap,
      scale: 0.97,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: PlayColors.cream,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: Colors.white, width: 3),
        ),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: Icon(
                icon,
                size: 28,
                color: PlayColors.onGround(color),
              ),
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
                      fontSize: 19,
                      height: 1.15,
                      fontWeight: FontWeight.w600,
                      color: PlayColors.ink,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.3,
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
    );
  }
}
