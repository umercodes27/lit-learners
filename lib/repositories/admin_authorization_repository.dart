import '../models/admin_content.dart';
import '../models/parent_account.dart';
import 'admin_content_repository.dart';
import 'auth_repository.dart';

abstract class AdminAuthorizationRepository {
  Future<ParentAccount?> currentParent();

  Future<bool> canManageContent();

  Future<void> requireContentAdmin();
}

class AdminPermissionException implements Exception {
  const AdminPermissionException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AuthAdminAuthorizationRepository implements AdminAuthorizationRepository {
  const AuthAdminAuthorizationRepository(this._authRepository);

  final AuthRepository _authRepository;

  @override
  Future<bool> canManageContent() async {
    final parent = await currentParent();
    return parent?.canManageAdminContent ?? false;
  }

  @override
  Future<ParentAccount?> currentParent() {
    return _authRepository.currentParent();
  }

  @override
  Future<void> requireContentAdmin() async {
    final parent = await currentParent();
    if (parent == null) {
      throw const AdminPermissionException(
        'Sign in with an admin account to manage content.',
      );
    }

    if (!parent.canManageAdminContent) {
      throw const AdminPermissionException(
        'This parent account is not approved to manage content.',
      );
    }
  }
}

class AuthorizedAdminContentRepository implements AdminContentRepository {
  const AuthorizedAdminContentRepository({
    required AdminContentRepository delegate,
    required AdminAuthorizationRepository authorizationRepository,
  })  : _delegate = delegate,
        _authorizationRepository = authorizationRepository;

  final AdminContentRepository _delegate;
  final AdminAuthorizationRepository _authorizationRepository;

  @override
  Future<void> deleteLevel(String levelId) {
    return _authorized(() => _delegate.deleteLevel(levelId));
  }

  @override
  Future<void> deleteModule(String moduleId) {
    return _authorized(() => _delegate.deleteModule(moduleId));
  }

  @override
  Future<List<AdminContentLevel>> getLevels({String? moduleId}) {
    return _authorized(() => _delegate.getLevels(moduleId: moduleId));
  }

  @override
  Future<List<AdminContentModule>> getModules() {
    return _authorized(_delegate.getModules);
  }

  @override
  Future<AdminContentLevel> upsertLevel(AdminContentLevel level) {
    return _authorized(() => _delegate.upsertLevel(level));
  }

  @override
  Future<AdminContentModule> upsertModule(AdminContentModule module) {
    return _authorized(() => _delegate.upsertModule(module));
  }

  Future<T> _authorized<T>(Future<T> Function() action) async {
    await _authorizationRepository.requireContentAdmin();
    return action();
  }
}
