import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

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

class FirebaseMediaStorageDataSource implements MediaStorageDataSource {
  FirebaseMediaStorageDataSource({FirebaseStorage? storage})
      : _storage = storage ?? FirebaseStorage.instance;

  final FirebaseStorage _storage;

  @override
  Future<void> delete(String storagePath) async {
    try {
      await _storage.ref(storagePath).delete();
    } on FirebaseException catch (error) {
      if (error.code != 'object-not-found') rethrow;
    }
  }

  @override
  Future<StoredMediaFile> uploadBytes({
    required String storagePath,
    required List<int> bytes,
    required String contentType,
  }) async {
    final snapshot = await _storage.ref(storagePath).putData(
          Uint8List.fromList(bytes),
          SettableMetadata(contentType: contentType),
        );
    final downloadUrl = await snapshot.ref.getDownloadURL();

    return StoredMediaFile(
      storagePath: snapshot.ref.fullPath,
      downloadUrl: downloadUrl,
      contentType: snapshot.metadata?.contentType ?? contentType,
      sizeBytes: snapshot.totalBytes,
    );
  }
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
