import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'media_storage_data_source.dart';

/// Stores admin media on Cloudinary instead of Firebase Storage.
///
/// Firebase Storage needs a billing account on the project before it will
/// accept an upload, which this project does not have. Cloudinary's free tier
/// takes images, audio and video with no card on file.
///
/// Uploads go through an *unsigned* upload preset. That is Cloudinary's
/// intended way to upload from an app: the preset decides what is allowed,
/// and the account's API secret never leaves Cloudinary. The media record
/// itself — who uploaded what, for which module — still lives in Firestore
/// exactly as before; only the bytes move.
class CloudinaryMediaStorageDataSource implements MediaStorageDataSource {
  CloudinaryMediaStorageDataSource({
    required this.cloudName,
    required this.uploadPreset,
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  final String cloudName;
  final String uploadPreset;
  final http.Client _http;

  Uri get _uploadUri =>
      Uri.https('api.cloudinary.com', '/v1_1/$cloudName/auto/upload');

  @override
  Future<StoredMediaFile> uploadBytes({
    required String storagePath,
    required List<int> bytes,
    required String contentType,
  }) async {
    final (folder, name) = _split(storagePath);

    final request = http.MultipartRequest('POST', _uploadUri)
      ..fields['upload_preset'] = uploadPreset
      ..fields['folder'] = folder
      ..files.add(
        http.MultipartFile.fromBytes('file', bytes, filename: name),
      );

    final http.Response response;
    try {
      response = await http.Response.fromStream(await _http.send(request));
    } on http.ClientException catch (error) {
      throw MediaStorageException(
        'Could not reach Cloudinary. Check the connection and try again. '
        '($error)',
      );
    }

    final body = _decode(response.body);
    if (response.statusCode != 200) {
      final message =
          (body['error'] is Map ? body['error']['message'] : null) as String?;
      throw MediaStorageException(
        response.statusCode == 400 || response.statusCode == 401
            ? 'Cloudinary refused the upload: ${message ?? 'bad request'}. '
                'Check the cloud name, and that the upload preset exists and '
                'is set to Unsigned.'
            : 'Cloudinary upload failed (${response.statusCode}): '
                '${message ?? 'no details'}.',
      );
    }

    final url = body['secure_url'] as String?;
    final publicId = body['public_id'] as String?;
    if (url == null || publicId == null) {
      throw const MediaStorageException(
        'Cloudinary accepted the file but did not say where it is.',
      );
    }

    return StoredMediaFile(
      storagePath: publicId,
      downloadUrl: url,
      contentType: contentType,
      sizeBytes: (body['bytes'] as num?)?.toInt() ?? bytes.length,
    );
  }

  /// Does not delete the file from Cloudinary.
  ///
  /// Deleting needs a signed request, and signing needs the API secret, which
  /// must never be inside an app anyone can install. The media record is
  /// still removed from the library, so the file is no longer offered to
  /// anyone; it stays in the Cloudinary console until removed there.
  @override
  Future<void> delete(String storagePath) async {
    debugPrint(
      'Cloudinary: "$storagePath" removed from the library. The file itself '
      'stays in the Cloudinary console, since deleting it needs the API '
      'secret.',
    );
  }

  /// `media/english/123-cat.png` -> (`media/english`, `123-cat.png`).
  (String, String) _split(String storagePath) {
    final index = storagePath.lastIndexOf('/');
    if (index < 0) return ('little-learners', storagePath);
    return (storagePath.substring(0, index), storagePath.substring(index + 1));
  }

  Map<String, dynamic> _decode(String body) {
    try {
      final decoded = jsonDecode(body);
      return decoded is Map<String, dynamic> ? decoded : const {};
    } on FormatException {
      return const {};
    }
  }
}

class MediaStorageException implements Exception {
  const MediaStorageException(this.message);

  final String message;

  @override
  String toString() => message;
}
