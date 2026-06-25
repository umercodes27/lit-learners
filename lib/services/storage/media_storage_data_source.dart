class StoredMediaFile {
  const StoredMediaFile({
    required this.storagePath,
    required this.downloadUrl,
    required this.contentType,
    required this.sizeBytes,
  });

  final String storagePath;
  final String downloadUrl;
  final String contentType;
  final int sizeBytes;
}

abstract class MediaStorageDataSource {
  Future<StoredMediaFile> uploadBytes({
    required String storagePath,
    required List<int> bytes,
    required String contentType,
  });

  Future<void> delete(String storagePath);
}

class InMemoryMediaStorageDataSource implements MediaStorageDataSource {
  final Map<String, StoredMediaFile> _filesByPath = {};
  final Map<String, List<int>> _bytesByPath = {};

  List<StoredMediaFile> get files => List.unmodifiable(_filesByPath.values);

  List<int>? bytesForPath(String storagePath) => _bytesByPath[storagePath];

  @override
  Future<void> delete(String storagePath) async {
    _filesByPath.remove(storagePath);
    _bytesByPath.remove(storagePath);
  }

  @override
  Future<StoredMediaFile> uploadBytes({
    required String storagePath,
    required List<int> bytes,
    required String contentType,
  }) async {
    final file = StoredMediaFile(
      storagePath: storagePath,
      downloadUrl: 'memory://$storagePath',
      contentType: contentType,
      sizeBytes: bytes.length,
    );
    _filesByPath[storagePath] = file;
    _bytesByPath[storagePath] = List.unmodifiable(bytes);
    return file;
  }
}
