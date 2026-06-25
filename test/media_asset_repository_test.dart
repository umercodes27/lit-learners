import 'package:flutter_test/flutter_test.dart';
import 'package:little_learners/models/media_asset.dart';
import 'package:little_learners/repositories/admin_authorization_repository.dart';
import 'package:little_learners/repositories/auth_repository.dart';
import 'package:little_learners/repositories/media_asset_repository.dart';
import 'package:little_learners/services/storage/media_storage_data_source.dart';

void main() {
  group('MediaAssetRepository', () {
    test('uploads, lists, and deletes media assets', () async {
      final storage = InMemoryMediaStorageDataSource();
      final repository = InMemoryMediaAssetRepository(
        storageDataSource: storage,
      );

      final asset = await repository.createAsset(
        parentId: 'parent-1',
        type: MediaAssetType.video,
        fileName: 'counting lesson.mp4',
        contentType: 'video/mp4',
        bytes: const [1, 2, 3],
      );

      expect(asset.type, MediaAssetType.video);
      expect(asset.fileName, 'counting-lesson.mp4');
      expect(asset.downloadUrl, startsWith('memory://'));
      expect(storage.bytesForPath(asset.storagePath), const [1, 2, 3]);
      expect(await repository.getAssets(type: MediaAssetType.video), [asset]);

      await repository.deleteAsset(asset.id);

      expect(await repository.getAssets(), isEmpty);
      expect(storage.bytesForPath(asset.storagePath), isNull);
    });

    test('blocks media management for non-admin parents', () async {
      final authRepository = InMemoryAuthRepository();
      await authRepository.signUp(
        email: 'parent@example.com',
        password: 'Strong1!',
      );
      final repository = AuthorizedMediaAssetRepository(
        delegate: InMemoryMediaAssetRepository(
          storageDataSource: InMemoryMediaStorageDataSource(),
        ),
        authorizationRepository: AuthAdminAuthorizationRepository(
          authRepository,
        ),
      );

      await expectLater(
        repository.getAssets(),
        throwsA(isA<AdminPermissionException>()),
      );
    });

    test('allows approved admins to manage media', () async {
      final authRepository = InMemoryAuthRepository(
        adminEmails: const {'admin@example.com'},
      );
      final admin = await authRepository.signUp(
        email: 'admin@example.com',
        password: 'Strong1!',
      );
      final repository = AuthorizedMediaAssetRepository(
        delegate: InMemoryMediaAssetRepository(
          storageDataSource: InMemoryMediaStorageDataSource(),
        ),
        authorizationRepository: AuthAdminAuthorizationRepository(
          authRepository,
        ),
      );

      await repository.createAsset(
        parentId: admin.id,
        type: MediaAssetType.audio,
        fileName: 'welcome.mp3',
        contentType: 'audio/mpeg',
        bytes: const [4, 5, 6],
      );

      expect(
          await repository.getAssets(type: MediaAssetType.audio), hasLength(1));
    });
  });
}
