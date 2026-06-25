import '../models/media_asset.dart';
import '../services/storage/media_storage_data_source.dart';
import 'admin_authorization_repository.dart';

abstract class MediaAssetRepository {
  Future<List<MediaAsset>> getAssets({MediaAssetType? type});

  Future<MediaAsset> createAsset({
    required String parentId,
    required MediaAssetType type,
    required String fileName,
    required String contentType,
    required List<int> bytes,
  });

  Future<void> deleteAsset(String assetId);
}

class MediaAssetException implements Exception {
  const MediaAssetException(this.message);

  final String message;

  @override
  String toString() => message;
}

class InMemoryMediaAssetRepository implements MediaAssetRepository {
  InMemoryMediaAssetRepository({
    required MediaStorageDataSource storageDataSource,
  }) : _storageDataSource = storageDataSource;

  final MediaStorageDataSource _storageDataSource;
  final Map<String, MediaAsset> _assetsById = {};
  int _nextAssetNumber = 1;

  @override
  Future<MediaAsset> createAsset({
    required String parentId,
    required MediaAssetType type,
    required String fileName,
    required String contentType,
    required List<int> bytes,
  }) async {
    _validateUpload(fileName: fileName, bytes: bytes);
    final now = DateTime.now();
    final assetId = 'asset-${now.microsecondsSinceEpoch}-${_nextAssetNumber++}';
    final normalizedFileName = _safeFileName(fileName);
    final storedFile = await _storageDataSource.uploadBytes(
      storagePath: _storagePath(
        type: type,
        assetId: assetId,
        fileName: normalizedFileName,
      ),
      bytes: bytes,
      contentType: _normalizedContentType(contentType, type),
    );
    final asset = MediaAsset(
      id: assetId,
      type: type,
      fileName: normalizedFileName,
      storagePath: storedFile.storagePath,
      downloadUrl: storedFile.downloadUrl,
      contentType: storedFile.contentType,
      sizeBytes: storedFile.sizeBytes,
      createdByParentId: parentId,
      createdAt: now,
      updatedAt: now,
    );
    _assetsById[asset.id] = asset;
    return asset;
  }

  @override
  Future<void> deleteAsset(String assetId) async {
    final asset = _assetsById.remove(assetId);
    if (asset == null) return;
    await _storageDataSource.delete(asset.storagePath);
  }

  @override
  Future<List<MediaAsset>> getAssets({MediaAssetType? type}) async {
    return _assetsById.values
        .where((asset) => type == null || asset.type == type)
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }
}

class AuthorizedMediaAssetRepository implements MediaAssetRepository {
  const AuthorizedMediaAssetRepository({
    required MediaAssetRepository delegate,
    required AdminAuthorizationRepository authorizationRepository,
  })  : _delegate = delegate,
        _authorizationRepository = authorizationRepository;

  final MediaAssetRepository _delegate;
  final AdminAuthorizationRepository _authorizationRepository;

  @override
  Future<MediaAsset> createAsset({
    required String parentId,
    required MediaAssetType type,
    required String fileName,
    required String contentType,
    required List<int> bytes,
  }) async {
    await _authorizationRepository.requireContentAdmin();
    return _delegate.createAsset(
      parentId: parentId,
      type: type,
      fileName: fileName,
      contentType: contentType,
      bytes: bytes,
    );
  }

  @override
  Future<void> deleteAsset(String assetId) async {
    await _authorizationRepository.requireContentAdmin();
    return _delegate.deleteAsset(assetId);
  }

  @override
  Future<List<MediaAsset>> getAssets({MediaAssetType? type}) async {
    await _authorizationRepository.requireContentAdmin();
    return _delegate.getAssets(type: type);
  }
}

void _validateUpload({
  required String fileName,
  required List<int> bytes,
}) {
  if (fileName.trim().isEmpty) {
    throw const MediaAssetException('File name is required.');
  }
  if (bytes.isEmpty) {
    throw const MediaAssetException('Media file cannot be empty.');
  }
}

String _storagePath({
  required MediaAssetType type,
  required String assetId,
  required String fileName,
}) {
  return 'mediaAssets/${type.name}/$assetId/$fileName';
}

String _safeFileName(String fileName) {
  final normalized =
      fileName.trim().replaceAll(RegExp(r'[^a-zA-Z0-9._-]+'), '-');
  return normalized.isEmpty ? 'asset.bin' : normalized;
}

String _normalizedContentType(String contentType, MediaAssetType type) {
  final trimmed = contentType.trim();
  if (trimmed.isNotEmpty) return trimmed;

  return switch (type) {
    MediaAssetType.image => 'image/png',
    MediaAssetType.video => 'video/mp4',
    MediaAssetType.audio => 'audio/mpeg',
    MediaAssetType.document => 'application/octet-stream',
  };
}
