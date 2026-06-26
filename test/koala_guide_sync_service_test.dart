import 'package:flutter_test/flutter_test.dart';
import 'package:little_learners/models/koala_guide_message.dart';
import 'package:little_learners/repositories/koala_guide_repository.dart';
import 'package:little_learners/services/remote/koala_guide_remote_data_source.dart';
import 'package:little_learners/services/sync/koala_guide_sync_service.dart';

void main() {
  group('KoalaGuideSyncService', () {
    test('pulls published remote messages into the guide repository', () async {
      final repository = SeededKoalaGuideRepository(
        seedMessages: const [
          KoalaGuideMessage(
            id: 'seed-math',
            trigger: KoalaGuideTrigger.moduleIntro,
            audience: KoalaGuideAudience.child,
            moduleId: 'math',
            message: 'Seed math.',
          ),
        ],
      );
      final remote = InMemoryKoalaGuideRemoteDataSource(
        messages: const [
          KoalaGuideMessage(
            id: 'remote-math',
            trigger: KoalaGuideTrigger.moduleIntro,
            audience: KoalaGuideAudience.child,
            moduleId: 'math',
            message: 'Remote math.',
            priority: 10,
          ),
        ],
      );
      final syncService = KoalaGuideSyncService(
        repository: repository,
        remoteDataSource: remote,
      );

      final report = await syncService.syncNow();
      final message = await repository.getMessage(
        const KoalaGuideRequest(
          trigger: KoalaGuideTrigger.moduleIntro,
          audience: KoalaGuideAudience.child,
          moduleId: 'math',
        ),
      );

      expect(report.messagesPulled, 1);
      expect(report.didApplyRemoteMessages, isTrue);
      expect(report.hasFailures, isFalse);
      expect(message.id, 'remote-math');
      expect(message.message, 'Remote math.');
    });

    test('falls back to seeded messages when remote is empty', () async {
      final repository = SeededKoalaGuideRepository(
        seedMessages: const [
          KoalaGuideMessage(
            id: 'seed-math',
            trigger: KoalaGuideTrigger.moduleIntro,
            audience: KoalaGuideAudience.child,
            moduleId: 'math',
            message: 'Seed math.',
          ),
        ],
      );
      final syncService = KoalaGuideSyncService(
        repository: repository,
        remoteDataSource: InMemoryKoalaGuideRemoteDataSource(),
      );

      final report = await syncService.syncNow();
      final message = await repository.getMessage(
        const KoalaGuideRequest(
          trigger: KoalaGuideTrigger.moduleIntro,
          audience: KoalaGuideAudience.child,
          moduleId: 'math',
        ),
      );

      expect(report.messagesPulled, 0);
      expect(report.didApplyRemoteMessages, isFalse);
      expect(message.id, 'seed-math');
    });
  });
}
