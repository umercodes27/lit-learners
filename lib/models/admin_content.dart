import 'koala_guide_message.dart';
import 'learning_level.dart';
import 'learning_module.dart';

enum AdminPublishStatus { draft, inReview, published }

class AdminContentModule {
  AdminContentModule({
    required this.module,
    required this.isPublished,
    required this.createdAt,
    required this.updatedAt,
    AdminPublishStatus? publishStatus,
    int? version,
    this.submittedAt,
    this.publishedAt,
  })  : publishStatus = publishStatus ??
            (isPublished
                ? AdminPublishStatus.published
                : AdminPublishStatus.draft),
        version = version ?? 1;

  final LearningModule module;
  final bool isPublished;
  final DateTime createdAt;
  final DateTime updatedAt;
  final AdminPublishStatus publishStatus;
  final int version;
  final DateTime? submittedAt;
  final DateTime? publishedAt;

  AdminContentModule copyWith({
    LearningModule? module,
    bool? isPublished,
    DateTime? updatedAt,
    AdminPublishStatus? publishStatus,
    int? version,
    DateTime? submittedAt,
    DateTime? publishedAt,
  }) {
    return AdminContentModule(
      module: module ?? this.module,
      isPublished: isPublished ?? this.isPublished,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      publishStatus: publishStatus ?? this.publishStatus,
      version: version ?? this.version,
      submittedAt: submittedAt ?? this.submittedAt,
      publishedAt: publishedAt ?? this.publishedAt,
    );
  }
}

class AdminContentLevel {
  AdminContentLevel({
    required this.level,
    required this.isPublished,
    required this.createdAt,
    required this.updatedAt,
    AdminPublishStatus? publishStatus,
    int? version,
    this.submittedAt,
    this.publishedAt,
  })  : publishStatus = publishStatus ??
            (isPublished
                ? AdminPublishStatus.published
                : AdminPublishStatus.draft),
        version = version ?? 1;

  final LearningLevel level;
  final bool isPublished;
  final DateTime createdAt;
  final DateTime updatedAt;
  final AdminPublishStatus publishStatus;
  final int version;
  final DateTime? submittedAt;
  final DateTime? publishedAt;

  AdminContentLevel copyWith({
    LearningLevel? level,
    bool? isPublished,
    DateTime? updatedAt,
    AdminPublishStatus? publishStatus,
    int? version,
    DateTime? submittedAt,
    DateTime? publishedAt,
  }) {
    return AdminContentLevel(
      level: level ?? this.level,
      isPublished: isPublished ?? this.isPublished,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      publishStatus: publishStatus ?? this.publishStatus,
      version: version ?? this.version,
      submittedAt: submittedAt ?? this.submittedAt,
      publishedAt: publishedAt ?? this.publishedAt,
    );
  }
}

class AdminKoalaGuideMessage {
  AdminKoalaGuideMessage({
    required this.message,
    required this.isPublished,
    required this.createdAt,
    required this.updatedAt,
    AdminPublishStatus? publishStatus,
    int? version,
    this.submittedAt,
    this.publishedAt,
  })  : publishStatus = publishStatus ??
            (isPublished
                ? AdminPublishStatus.published
                : AdminPublishStatus.draft),
        version = version ?? 1;

  final KoalaGuideMessage message;
  final bool isPublished;
  final DateTime createdAt;
  final DateTime updatedAt;
  final AdminPublishStatus publishStatus;
  final int version;
  final DateTime? submittedAt;
  final DateTime? publishedAt;

  AdminKoalaGuideMessage copyWith({
    KoalaGuideMessage? message,
    bool? isPublished,
    DateTime? updatedAt,
    AdminPublishStatus? publishStatus,
    int? version,
    DateTime? submittedAt,
    DateTime? publishedAt,
  }) {
    return AdminKoalaGuideMessage(
      message: message ?? this.message,
      isPublished: isPublished ?? this.isPublished,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      publishStatus: publishStatus ?? this.publishStatus,
      version: version ?? this.version,
      submittedAt: submittedAt ?? this.submittedAt,
      publishedAt: publishedAt ?? this.publishedAt,
    );
  }
}
