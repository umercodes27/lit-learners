import 'package:flutter_test/flutter_test.dart';
import 'package:little_learners/models/koala_guide_message.dart';
import 'package:little_learners/repositories/koala_guide_repository.dart';
import 'package:little_learners/services/remote/koala_guide_remote_data_source.dart';
import 'package:little_learners/services/sync/koala_guide_sync_service.dart';
import 'package:little_learners/services/sync/sync_orchestrator.dart';

void main() {
  group('SyncOrchestrator', () {
    test('skips tasks while offline', () async {
      const connectivity = _FakeConnectivityStatusProvider(isOnline: false);
      final orchestrator = SyncOrchestrator(
        connectivityStatusProvider: connectivity,
      );
      var didRun = false;

      final report = await orchestrator.run([
        SyncTask(
          name: 'profile-sync',
          run: () async {
            didRun = true;
            return true;
          },
        ),
      ]);

      expect(didRun, isFalse);
      expect(report.results.single.status, SyncTaskStatus.skippedOffline);
    });

    test('backs off failed tasks and resets after success', () async {
      var now = DateTime.utc(2026, 1, 1, 12);
      final orchestrator = SyncOrchestrator(
        connectivityStatusProvider: const _FakeConnectivityStatusProvider(
          isOnline: true,
        ),
        clock: () => now,
        initialBackoff: const Duration(seconds: 10),
        maxBackoff: const Duration(minutes: 1),
      );
      var shouldSucceed = false;

      Future<SyncOrchestrationReport> run() {
        return orchestrator.run([
          SyncTask(
            name: 'progress-sync',
            run: () async => shouldSucceed,
          ),
        ]);
      }

      final first = await run();
      final second = await run();
      now = now.add(const Duration(seconds: 10));
      shouldSucceed = true;
      final third = await run();

      expect(first.results.single.status, SyncTaskStatus.failed);
      expect(first.results.single.attemptCount, 1);
      expect(second.results.single.status, SyncTaskStatus.skippedBackoff);
      expect(third.results.single.status, SyncTaskStatus.succeeded);
      expect(third.results.single.attemptCount, 0);
    });

    test('runs Koala guide sync as an orchestrated task', () async {
      final repository = SeededKoalaGuideRepository(seedMessages: const []);
      final guideSyncService = KoalaGuideSyncService(
        repository: repository,
        remoteDataSource: InMemoryKoalaGuideRemoteDataSource(
          messages: const [
            KoalaGuideMessage(
              id: 'remote-guide',
              trigger: KoalaGuideTrigger.dashboardWelcome,
              audience: KoalaGuideAudience.child,
              message: 'Remote guide.',
            ),
          ],
        ),
      );
      final orchestrator = SyncOrchestrator(
        connectivityStatusProvider: const _FakeConnectivityStatusProvider(
          isOnline: true,
        ),
      );

      final report = await orchestrator.run([
        SyncTask(
          name: 'koala-guide-sync',
          run: () async {
            final guideReport = await guideSyncService.syncNow();
            return !guideReport.hasFailures;
          },
        ),
      ]);

      expect(report.results.single.status, SyncTaskStatus.succeeded);
      expect(repository.syncedMessages.single.id, 'remote-guide');
    });
  });
}

class _FakeConnectivityStatusProvider implements ConnectivityStatusProvider {
  const _FakeConnectivityStatusProvider({required bool isOnline})
      : _isOnline = isOnline;

  final bool _isOnline;

  @override
  Future<bool> get isOnline async => _isOnline;
}
