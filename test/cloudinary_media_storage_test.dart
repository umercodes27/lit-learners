import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:little_learners/services/storage/cloudinary_media_storage_data_source.dart';

void main() {
  test('uploads through the unsigned preset and keeps the secure address',
      () async {
    late http.Request sent;
    final storage = CloudinaryMediaStorageDataSource(
      cloudName: 'demo',
      uploadPreset: 'little_learners_unsigned',
      httpClient: MockClient((request) async {
        sent = request;
        return http.Response(
          jsonEncode({
            'secure_url':
                'https://res.cloudinary.com/demo/image/upload/media/english/cat.png',
            'public_id': 'media/english/cat',
            'bytes': 3,
          }),
          200,
        );
      }),
    );

    final stored = await storage.uploadBytes(
      storagePath: 'media/english/cat.png',
      bytes: const [1, 2, 3],
      contentType: 'image/png',
    );

    expect(sent.url.toString(),
        'https://api.cloudinary.com/v1_1/demo/auto/upload');
    final body = latin1.decode(sent.bodyBytes);
    expect(body, contains('little_learners_unsigned'));
    expect(body, contains('media/english'));
    expect(body, isNot(contains('api_secret')),
        reason: 'the secret must never be in the app');
    expect(stored.downloadUrl, startsWith('https://'));
    expect(stored.storagePath, 'media/english/cat');
    expect(stored.sizeBytes, 3);
  });

  test('a refused upload says what to check', () async {
    final storage = CloudinaryMediaStorageDataSource(
      cloudName: 'demo',
      uploadPreset: 'missing',
      httpClient: MockClient((_) async => http.Response(
            jsonEncode({
              'error': {'message': 'Upload preset not found'},
            }),
            400,
          )),
    );

    expect(
      () => storage.uploadBytes(
        storagePath: 'media/english/cat.png',
        bytes: const [1],
        contentType: 'image/png',
      ),
      throwsA(isA<MediaStorageException>().having(
        (e) => e.message,
        'message',
        allOf(contains('Upload preset not found'), contains('Unsigned')),
      )),
    );
  });
}
