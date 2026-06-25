import 'package:flutter_test/flutter_test.dart';
import 'package:little_learners/models/admin_content.dart';
import 'package:little_learners/models/learning_module.dart';
import 'package:little_learners/repositories/admin_authorization_repository.dart';
import 'package:little_learners/repositories/admin_content_repository.dart';
import 'package:little_learners/repositories/auth_repository.dart';
import 'package:little_learners/services/remote/content_remote_data_source.dart';

void main() {
  group('AuthorizedAdminContentRepository', () {
    test('blocks admin content writes for non-admin parents', () async {
      final authRepository = InMemoryAuthRepository();
      await authRepository.signUp(
        email: 'parent@example.com',
        password: 'Strong1!',
      );
      final repository = _authorizedRepository(authRepository);

      await expectLater(
        repository.upsertModule(_adminModule()),
        throwsA(isA<AdminPermissionException>()),
      );
    });

    test('allows approved admins to manage content', () async {
      final authRepository = InMemoryAuthRepository(
        adminEmails: const {'admin@example.com'},
      );
      await authRepository.signUp(
        email: 'admin@example.com',
        password: 'Strong1!',
      );
      final repository = _authorizedRepository(authRepository);

      await repository.upsertModule(_adminModule());

      expect(await repository.getModules(), hasLength(1));
    });
  });
}

AdminContentRepository _authorizedRepository(AuthRepository authRepository) {
  final remote = InMemoryContentRemoteDataSource();
  return AuthorizedAdminContentRepository(
    delegate: InMemoryAdminContentRepository(contentRemoteDataSource: remote),
    authorizationRepository: AuthAdminAuthorizationRepository(authRepository),
  );
}

AdminContentModule _adminModule() {
  final now = DateTime.utc(2026);
  return AdminContentModule(
    module: const LearningModule(
      id: 'math',
      title: 'Math',
      description: 'Numbers',
      category: ModuleCategory.math,
      minStage: 1,
      maxStage: 4,
      order: 1,
    ),
    isPublished: false,
    createdAt: now,
    updatedAt: now,
  );
}
