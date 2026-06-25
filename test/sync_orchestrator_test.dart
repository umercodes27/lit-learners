import 'package:flutter_test/flutter_test.dart';
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
  });
}

class _FakeConnectivityStatusProvider implements ConnectivityStatusProvider {
  const _FakeConnectivityStatusProvider({required bool isOnline})
      : _isOnline = isOnline;

  final bool _isOnline;

  @override
  Future<bool> get isOnline async => _isOnline;
}
