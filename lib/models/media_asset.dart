enum MediaAssetType { image, video, audio, document }

class MediaAsset {
  const MediaAsset({
    required this.id,
    required this.type,
    required this.fileName,
    required this.storagePath,
    required this.downloadUrl,
    required this.contentType,
    required this.sizeBytes,
    required this.createdByParentId,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final MediaAssetType type;
  final String fileName;
  final String storagePath;
  final String downloadUrl;
  final String contentType;
  final int sizeBytes;
  final String createdByParentId;
  final DateTime createdAt;
  final DateTime updatedAt;

  MediaAsset copyWith({
    MediaAssetType? type,
    String? fileName,
    String? storagePath,
    String? downloadUrl,
    String? contentType,
    int? sizeBytes,
    String? createdByParentId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MediaAsset(
      id: id,
      type: type ?? this.type,
      fileName: fileName ?? this.fileName,
      storagePath: storagePath ?? this.storagePath,
      downloadUrl: downloadUrl ?? this.downloadUrl,
      contentType: contentType ?? this.contentType,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      createdByParentId: createdByParentId ?? this.createdByParentId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
