import 'package:flutter/foundation.dart';

import '../models/media_asset.dart';
import '../repositories/admin_authorization_repository.dart';
import '../repositories/media_asset_repository.dart';
import '../services/storage/cloudinary_media_storage_data_source.dart';

/// Backs the media library screen (UC-19 step 4).
class AdminMediaViewModel extends ChangeNotifier {
  AdminMediaViewModel(this._mediaAssetRepository);

  final MediaAssetRepository _mediaAssetRepository;

  List<MediaAsset> _assets = const [];
  bool _isLoading = false;
  bool _isUploading = false;
  String? _errorMessage;
  String? _infoMessage;

  List<MediaAsset> get assets => _assets;

  /// The asset the most recent successful [upload] created, so a screen that
  /// uploaded a picture in order to use it can pick it straight up.
  MediaAsset? _lastUploaded;
  MediaAsset? get lastUploaded => _lastUploaded;
  bool get isLoading => _isLoading;
  bool get isUploading => _isUploading;
  String? get errorMessage => _errorMessage;
  String? get infoMessage => _infoMessage;

  Future<void> load() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _assets = await _mediaAssetRepository.getAssets();
    } on Exception catch (error) {
      _errorMessage = _messageFor(error);
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Returns false on failure so the caller can offer a retry, per UC-19's
  /// "if media upload fails, display an error and allow retry" flow.
  Future<bool> upload({
    required String adminId,
    required String moduleId,
    required MediaAssetType type,
    required String fileName,
    required String contentType,
    required List<int> bytes,
  }) async {
    // UC-19 business rule: media files must belong to a specific module.
    if (moduleId.trim().isEmpty) {
      _errorMessage = 'Choose the module this media file belongs to.';
      _infoMessage = null;
      notifyListeners();
      return false;
    }

    _isUploading = true;
    _errorMessage = null;
    _infoMessage = null;
    notifyListeners();

    try {
      _lastUploaded = await _mediaAssetRepository.createAsset(
        parentId: adminId,
        moduleId: moduleId.trim(),
        type: type,
        fileName: fileName,
        contentType: contentType,
        bytes: bytes,
      );
      _assets = await _mediaAssetRepository.getAssets();
      _infoMessage = 'Uploaded $fileName';
      return true;
    } on Exception catch (error) {
      _errorMessage = _messageFor(error);
      return false;
    } finally {
      _isUploading = false;
      notifyListeners();
    }
  }

  Future<bool> delete(String assetId) async {
    _errorMessage = null;
    _infoMessage = null;
    notifyListeners();

    try {
      await _mediaAssetRepository.deleteAsset(assetId);
      _assets = await _mediaAssetRepository.getAssets();
      _infoMessage = 'Media deleted.';
      notifyListeners();
      return true;
    } on Exception catch (error) {
      _errorMessage = _messageFor(error);
      notifyListeners();
      return false;
    }
  }

  void clearMessages() {
    _errorMessage = null;
    _infoMessage = null;
    notifyListeners();
  }

  String _messageFor(Exception error) {
    return switch (error) {
      AdminPermissionException(:final message) => message,
      MediaAssetException(:final message) => message,
      MediaStorageException(:final message) => message,
      _ => 'Something went wrong: $error',
    };
  }
}
