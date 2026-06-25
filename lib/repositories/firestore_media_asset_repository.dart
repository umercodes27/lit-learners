import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/media_asset.dart';
import '../services/storage/media_storage_data_source.dart';
import 'media_asset_repository.dart';

class FirestoreMediaAssetRepository implements MediaAssetRepository {
  FirestoreMediaAssetRepository({
    FirebaseFirestore? firestore,
    required MediaStorageDataSource storageDataSource,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _storageDataSource = storageDataSource;

  static const mediaAssetsCollection = 'mediaAssets';

  final FirebaseFirestore _firestore;
  final MediaStorageDataSource _storageDataSource;

  CollectionReference<Map<String, dynamic>> get _assetsRef {
    return _firestore.collection(mediaAssetsCollection);
  }

  @override
  Future<MediaAsset> createAsset({
    required String parentId,
    required MediaAssetType type,
    required String fileName,
    required String contentType,
    required List<int> bytes,
  }) async {
    _validateUpload(fileName: fileName, bytes: bytes);
    final ref = _assetsRef.doc();
    final now = DateTime.now();
    final normalizedFileName = _safeFileName(fileName);
    final storedFile = await _storageDataSource.uploadBytes(
      storagePath: _storagePath(
        type: type,
        assetId: ref.id,
        fileName: normalizedFileName,
      ),
      bytes: bytes,
      contentType: _normalizedContentType(contentType, type),
    );
    final asset = MediaAsset(
      id: ref.id,
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
    await ref.set(_toRemoteMap(asset));
    return asset;
  }

  @override
  Future<void> deleteAsset(String assetId) async {
    final doc = await _assetsRef.doc(assetId).get();
    if (!doc.exists) return;

    final asset = _fromRemoteDoc(doc);
    await _storageDataSource.delete(asset.storagePath);
    await doc.reference.delete();
  }

  @override
  Future<List<MediaAsset>> getAssets({MediaAssetType? type}) async {
    final snapshot = type == null
        ? await _assetsRef.orderBy('updatedAt', descending: true).get()
        : await _assetsRef
            .where('type', isEqualTo: type.name)
            .orderBy('updatedAt', descending: true)
            .get();
    return snapshot.docs.map(_fromRemoteDoc).toList();
  }

  MediaAsset _fromRemoteDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    final now = DateTime.now();
    return MediaAsset(
      id: (data['assetId'] as String?) ?? doc.id,
      type: _enumByName(
        MediaAssetType.values,
        data['type'] as String?,
        MediaAssetType.document,
      ),
      fileName: (data['fileName'] as String?) ?? 'asset.bin',
      storagePath: (data['storagePath'] as String?) ?? '',
      downloadUrl: (data['downloadUrl'] as String?) ?? '',
      contentType:
          (data['contentType'] as String?) ?? 'application/octet-stream',
      sizeBytes: (data['sizeBytes'] as num?)?.toInt() ?? 0,
      createdByParentId: (data['createdByParentId'] as String?) ?? '',
      createdAt: _dateFromRemoteValue(data['createdAt']) ?? now,
      updatedAt: _dateFromRemoteValue(data['updatedAt']) ?? now,
    );
  }

  Map<String, Object?> _toRemoteMap(MediaAsset asset) {
    return {
      'assetId': asset.id,
      'type': asset.type.name,
      'fileName': asset.fileName,
      'storagePath': asset.storagePath,
      'downloadUrl': asset.downloadUrl,
      'contentType': asset.contentType,
      'sizeBytes': asset.sizeBytes,
      'createdByParentId': asset.createdByParentId,
      'createdAt': Timestamp.fromDate(asset.createdAt),
      'updatedAt': Timestamp.fromDate(asset.updatedAt),
    };
  }

  DateTime? _dateFromRemoteValue(Object? value) {
    return switch (value) {
      Timestamp timestamp => timestamp.toDate(),
      DateTime dateTime => dateTime,
      String text => DateTime.tryParse(text),
      _ => null,
    };
  }

  T _enumByName<T extends Enum>(
    List<T> values,
    String? name,
    T fallback,
  ) {
    for (final value in values) {
      if (value.name == name) return value;
    }
    return fallback;
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
