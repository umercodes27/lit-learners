import '../../repositories/koala_guide_repository.dart';
import '../remote/koala_guide_remote_data_source.dart';

class KoalaGuideSyncReport {
  const KoalaGuideSyncReport({
    required this.messagesPulled,
    required this.didApplyRemoteMessages,
    required this.failedItems,
  });

  final int messagesPulled;
  final bool didApplyRemoteMessages;
  final int failedItems;

  bool get hasFailures => failedItems > 0;
}

class KoalaGuideSyncService {
  const KoalaGuideSyncService({
    required SeededKoalaGuideRepository repository,
    required KoalaGuideRemoteDataSource remoteDataSource,
  })  : _repository = repository,
        _remoteDataSource = remoteDataSource;

  final SeededKoalaGuideRepository _repository;
  final KoalaGuideRemoteDataSource _remoteDataSource;

  Future<KoalaGuideSyncReport> syncNow() async {
    try {
      final messages = await _remoteDataSource.getPublishedMessages();
      _repository.replaceSyncedMessages(messages);
      return KoalaGuideSyncReport(
        messagesPulled: messages.length,
        didApplyRemoteMessages: messages.isNotEmpty,
        failedItems: 0,
      );
    } catch (error) {
      return const KoalaGuideSyncReport(
        messagesPulled: 0,
        didApplyRemoteMessages: false,
        failedItems: 1,
      );
    }
  }
}
