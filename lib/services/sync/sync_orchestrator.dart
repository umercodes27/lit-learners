typedef SyncClock = DateTime Function();

enum SyncTaskStatus { succeeded, failed, skippedOffline, skippedBackoff }

abstract class ConnectivityStatusProvider {
  Future<bool> get isOnline;
}

class AlwaysOnlineConnectivityStatusProvider
    implements ConnectivityStatusProvider {
  const AlwaysOnlineConnectivityStatusProvider();

  @override
  Future<bool> get isOnline async => true;
}

class SyncTask {
  const SyncTask({
    required this.name,
    required this.run,
  });

  final String name;
  final Future<bool> Function() run;
}

class SyncTaskResult {
  const SyncTaskResult({
    required this.name,
    required this.status,
    required this.attemptCount,
    this.nextRetryAt,
    this.errorMessage,
  });

  final String name;
  final SyncTaskStatus status;
  final int attemptCount;
  final DateTime? nextRetryAt;
  final String? errorMessage;

  bool get succeeded => status == SyncTaskStatus.succeeded;
}

class SyncOrchestrationReport {
  const SyncOrchestrationReport({
    required this.startedAt,
    required this.completedAt,
    required this.results,
  });

  final DateTime startedAt;
  final DateTime completedAt;
  final List<SyncTaskResult> results;

  bool get hasFailures {
    return results.any((result) => result.status == SyncTaskStatus.failed);
  }

  bool get skippedForConnectivity {
    return results.any(
      (result) => result.status == SyncTaskStatus.skippedOffline,
    );
  }
}

class SyncOrchestrator {
  SyncOrchestrator({
    required ConnectivityStatusProvider connectivityStatusProvider,
    SyncClock? clock,
    Duration initialBackoff = const Duration(seconds: 30),
    Duration maxBackoff = const Duration(minutes: 10),
  })  : _connectivityStatusProvider = connectivityStatusProvider,
        _clock = clock ?? DateTime.now,
        _initialBackoff = initialBackoff,
        _maxBackoff = maxBackoff;

  final ConnectivityStatusProvider _connectivityStatusProvider;
  final SyncClock _clock;
  final Duration _initialBackoff;
  final Duration _maxBackoff;
  final Map<String, _SyncTaskBackoffState> _stateByTaskName = {};

  Future<SyncOrchestrationReport> run(List<SyncTask> tasks) async {
    final startedAt = _clock();
    final results = <SyncTaskResult>[];
    final online = await _connectivityStatusProvider.isOnline;

    for (final task in tasks) {
      final now = _clock();
      final state = _stateByTaskName[task.name];
      if (!online) {
        results.add(
          SyncTaskResult(
            name: task.name,
            status: SyncTaskStatus.skippedOffline,
            attemptCount: state?.attemptCount ?? 0,
            nextRetryAt: state?.nextRetryAt,
          ),
        );
        continue;
      }

      final nextRetryAt = state?.nextRetryAt;
      if (nextRetryAt != null && now.isBefore(nextRetryAt)) {
        results.add(
          SyncTaskResult(
            name: task.name,
            status: SyncTaskStatus.skippedBackoff,
            attemptCount: state?.attemptCount ?? 0,
            nextRetryAt: nextRetryAt,
          ),
        );
        continue;
      }

      try {
        final succeeded = await task.run();
        if (succeeded) {
          _stateByTaskName.remove(task.name);
          results.add(
            SyncTaskResult(
              name: task.name,
              status: SyncTaskStatus.succeeded,
              attemptCount: 0,
            ),
          );
        } else {
          results.add(_recordFailure(task.name, 'Sync task reported failure.'));
        }
      } catch (error) {
        results.add(_recordFailure(task.name, error.toString()));
      }
    }

    return SyncOrchestrationReport(
      startedAt: startedAt,
      completedAt: _clock(),
      results: results,
    );
  }

  SyncTaskResult _recordFailure(String taskName, String errorMessage) {
    final current = _stateByTaskName[taskName];
    final attemptCount = (current?.attemptCount ?? 0) + 1;
    final nextRetryAt = _clock().add(_backoffFor(attemptCount));
    _stateByTaskName[taskName] = _SyncTaskBackoffState(
      attemptCount: attemptCount,
      nextRetryAt: nextRetryAt,
    );
    return SyncTaskResult(
      name: taskName,
      status: SyncTaskStatus.failed,
      attemptCount: attemptCount,
      nextRetryAt: nextRetryAt,
      errorMessage: errorMessage,
    );
  }

  Duration _backoffFor(int attemptCount) {
    final multiplier = 1 << (attemptCount - 1).clamp(0, 30).toInt();
    final milliseconds = _initialBackoff.inMilliseconds * multiplier;
    if (milliseconds >= _maxBackoff.inMilliseconds) return _maxBackoff;
    return Duration(milliseconds: milliseconds);
  }
}

class _SyncTaskBackoffState {
  const _SyncTaskBackoffState({
    required this.attemptCount,
    required this.nextRetryAt,
  });

  final int attemptCount;
  final DateTime nextRetryAt;
}
