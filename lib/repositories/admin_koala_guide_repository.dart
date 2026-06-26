import '../models/admin_content.dart';
import '../models/koala_guide_message.dart';
import '../services/remote/koala_guide_remote_data_source.dart';

abstract class AdminKoalaGuideRepository {
  Future<List<AdminKoalaGuideMessage>> getMessages();

  Future<AdminKoalaGuideMessage> upsertMessage(
    AdminKoalaGuideMessage message,
  );

  Future<void> deleteMessage(String messageId);
}

class InMemoryAdminKoalaGuideRepository implements AdminKoalaGuideRepository {
  InMemoryAdminKoalaGuideRepository({
    required InMemoryKoalaGuideRemoteDataSource remoteDataSource,
  }) : _remoteDataSource = remoteDataSource;

  final InMemoryKoalaGuideRemoteDataSource _remoteDataSource;
  final Map<String, DateTime> _createdAt = {};
  final Map<String, DateTime> _updatedAt = {};
  final Map<String, AdminPublishStatus> _publishStatus = {};
  final Map<String, int> _version = {};
  final Map<String, DateTime?> _submittedAt = {};
  final Map<String, DateTime?> _publishedAt = {};

  @override
  Future<void> deleteMessage(String messageId) async {
    _remoteDataSource.deleteMessage(messageId);
    _createdAt.remove(messageId);
    _updatedAt.remove(messageId);
    _publishStatus.remove(messageId);
    _version.remove(messageId);
    _submittedAt.remove(messageId);
    _publishedAt.remove(messageId);
  }

  @override
  Future<List<AdminKoalaGuideMessage>> getMessages() async {
    return _remoteDataSource.getAllMessages().map(_adminMessageFor).toList();
  }

  @override
  Future<AdminKoalaGuideMessage> upsertMessage(
    AdminKoalaGuideMessage message,
  ) async {
    final now = DateTime.now();
    final createdAt = _createdAt[message.message.id] ?? message.createdAt;
    _createdAt[message.message.id] = createdAt;
    _updatedAt[message.message.id] = now;
    _publishStatus[message.message.id] = message.publishStatus;
    _version[message.message.id] = message.version;
    _submittedAt[message.message.id] = message.submittedAt;
    _publishedAt[message.message.id] = message.publishedAt;
    _remoteDataSource.upsertMessage(
      message: message.message,
      isPublished: message.isPublished,
    );
    return message.copyWith(updatedAt: now);
  }

  AdminKoalaGuideMessage _adminMessageFor(KoalaGuideMessage message) {
    final now = DateTime.now();
    final isPublished = _remoteDataSource.isMessagePublished(message.id);
    return AdminKoalaGuideMessage(
      message: message,
      isPublished: isPublished,
      createdAt: _createdAt[message.id] ?? now,
      updatedAt: _updatedAt[message.id] ?? now,
      publishStatus: _publishStatus[message.id] ??
          (isPublished
              ? AdminPublishStatus.published
              : AdminPublishStatus.draft),
      version: _version[message.id] ?? 1,
      submittedAt: _submittedAt[message.id],
      publishedAt: _publishedAt[message.id],
    );
  }
}
