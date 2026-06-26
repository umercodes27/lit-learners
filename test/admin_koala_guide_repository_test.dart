import 'package:flutter_test/flutter_test.dart';
import 'package:little_learners/models/admin_content.dart';
import 'package:little_learners/models/koala_guide_message.dart';
import 'package:little_learners/repositories/admin_koala_guide_repository.dart';
import 'package:little_learners/services/remote/koala_guide_remote_data_source.dart';

void main() {
  group('InMemoryAdminKoalaGuideRepository', () {
    test('keeps draft guide messages out of published sync', () async {
      final remote = InMemoryKoalaGuideRemoteDataSource();
      final repository = InMemoryAdminKoalaGuideRepository(
        remoteDataSource: remote,
      );

      await repository.upsertMessage(_adminGuideMessage(isPublished: false));

      expect(await repository.getMessages(), hasLength(1));
      expect(await remote.getPublishedMessages(), isEmpty);
    });

    test('publishes and deletes guide messages for sync', () async {
      final remote = InMemoryKoalaGuideRemoteDataSource();
      final repository = InMemoryAdminKoalaGuideRepository(
        remoteDataSource: remote,
      );

      await repository.upsertMessage(_adminGuideMessage(isPublished: true));

      final published = await remote.getPublishedMessages();
      expect(published.single.id, 'custom-math-guide');
      expect(published.single.audioCueKey, 'custom_math_audio');

      await repository.deleteMessage('custom-math-guide');

      expect(await repository.getMessages(), isEmpty);
      expect(await remote.getPublishedMessages(), isEmpty);
    });

    test('persists guide publishing workflow metadata', () async {
      final remote = InMemoryKoalaGuideRemoteDataSource();
      final repository = InMemoryAdminKoalaGuideRepository(
        remoteDataSource: remote,
      );
      final submittedAt = DateTime.utc(2026, 1, 2);
      final publishedAt = DateTime.utc(2026, 1, 3);

      await repository.upsertMessage(
        _adminGuideMessage(isPublished: true).copyWith(
          publishStatus: AdminPublishStatus.published,
          version: 4,
          submittedAt: submittedAt,
          publishedAt: publishedAt,
        ),
      );

      final message = (await repository.getMessages()).single;

      expect(message.publishStatus, AdminPublishStatus.published);
      expect(message.version, 4);
      expect(message.submittedAt, submittedAt);
      expect(message.publishedAt, publishedAt);
    });
  });
}

AdminKoalaGuideMessage _adminGuideMessage({required bool isPublished}) {
  final now = DateTime.utc(2026);
  return AdminKoalaGuideMessage(
    message: const KoalaGuideMessage(
      id: 'custom-math-guide',
      trigger: KoalaGuideTrigger.moduleIntro,
      audience: KoalaGuideAudience.child,
      moduleId: 'math',
      message: 'Custom math guide.',
      audioCueKey: 'custom_math_audio',
      mood: KoalaGuideMood.thinking,
      priority: 30,
    ),
    isPublished: isPublished,
    createdAt: now,
    updatedAt: now,
  );
}
