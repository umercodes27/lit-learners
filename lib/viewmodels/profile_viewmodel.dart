import 'package:flutter/foundation.dart';

import '../core/utils/validators.dart';
import '../models/child_profile.dart';
import '../repositories/child_profile_repository.dart';
import '../services/sync/sync_service.dart';

class ProfileViewModel extends ChangeNotifier {
  ProfileViewModel(
    this._profileRepository, {
    SyncService? syncService,
  }) : _syncService = syncService;

  final ChildProfileRepository _profileRepository;
  final SyncService? _syncService;

  List<ChildProfile> _profiles = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<ChildProfile> get profiles => List.unmodifiable(_profiles);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get canCreateProfile => _profiles.length < 3;

  Future<void> loadProfiles(String parentId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    await _syncService?.syncNow(parentId: parentId);
    _profiles = await _profileRepository.getProfiles(parentId);
    _isLoading = false;
    notifyListeners();
  }

  ChildProfile? profileById(String profileId) {
    for (final profile in _profiles) {
      if (profile.id == profileId) return profile;
    }
    return null;
  }

  Future<bool> createProfile({
    required String parentId,
    required String name,
    required int age,
    required String avatarAsset,
    required bool leaderboardOptIn,
    required String displayPreference,
  }) async {
    final validationError = _validateProfile(name: name, age: age);
    if (validationError != null) {
      _setError(validationError);
      return false;
    }

    try {
      await _profileRepository.createProfile(
        parentId: parentId,
        name: name,
        age: age,
        avatarAsset: avatarAsset,
        leaderboardOptIn: leaderboardOptIn,
        displayPreference: displayPreference,
      );
      await loadProfiles(parentId);
      return true;
    } on ProfileLimitException {
      _setError('A parent can create up to 3 child profiles.');
      return false;
    }
  }

  Future<bool> updateProfile({
    required ChildProfile profile,
    required String name,
    required int age,
    required String avatarAsset,
    required bool leaderboardOptIn,
    required String displayPreference,
  }) async {
    final validationError = _validateProfile(name: name, age: age);
    if (validationError != null) {
      _setError(validationError);
      return false;
    }

    await _profileRepository.updateProfile(
      profile.copyWith(
        name: name.trim(),
        age: age,
        avatarAsset: avatarAsset,
        leaderboardOptIn: leaderboardOptIn,
        displayPreference: displayPreference,
      ),
    );
    await loadProfiles(profile.parentId);
    return true;
  }

  Future<bool> deleteProfile({
    required String parentId,
    required String childId,
  }) async {
    try {
      await _profileRepository.deleteProfile(
        parentId: parentId,
        childId: childId,
      );
      await loadProfiles(parentId);
      return true;
    } on ProfileNotFoundException {
      _setError('Child profile not found.');
      return false;
    }
  }

  String? _validateProfile({
    required String name,
    required int age,
  }) {
    final nameError = Validators.requiredText(name, 'Child name');
    if (nameError != null) return nameError;
    if (age < 1 || age > 4) return 'Age must be between 1 and 4.';
    return null;
  }

  void _setError(String message) {
    _errorMessage = message;
    _isLoading = false;
    notifyListeners();
  }
}
