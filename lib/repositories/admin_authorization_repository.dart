import '../models/admin_content.dart';
import '../models/admin_user.dart';
import '../models/parent_account.dart';
import 'admin_auth_repository.dart';
import 'admin_content_repository.dart';
import 'admin_koala_guide_repository.dart';
import 'auth_repository.dart';

abstract class AdminAuthorizationRepository {
  Future<ParentAccount?> currentParent();

  Future<bool> canManageContent();

  Future<void> requireContentAdmin();

  /// The signed-in admin, when the session is a real admin session.
  ///
  /// Null for the parent-session implementation, which has no role beyond
  /// "is an admin".
  Future<AdminUser?> currentAdminUser() async => null;

  /// Guards system statistics. Every role may read them.
  Future<void> requireStatisticsAccess() => requireContentAdmin();

  /// Guards the parent account list, which carries parent emails and is
  /// therefore narrower than the rest of the portal.
  Future<void> requireParentAccountAccess() => requireContentAdmin();
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

  /// The parent session has no admin record, so there is no role to report.
  @override
  Future<AdminUser?> currentAdminUser() async => null;

  /// This implementation predates roles: an admin parent may do everything.
  @override
  Future<void> requireStatisticsAccess() => requireContentAdmin();

  @override
  Future<void> requireParentAccountAccess() => requireContentAdmin();
}

/// Authorizes admin work against the dedicated admin session (UC-18) rather
/// than the parent session.
///
/// [AuthAdminAuthorizationRepository] remains for flows that still key off a
/// parent account with `role == admin`.
class AdminSessionAuthorizationRepository
    implements AdminAuthorizationRepository {
  const AdminSessionAuthorizationRepository(this._adminAuthRepository);

  final AdminAuthRepository _adminAuthRepository;

  @override
  Future<bool> canManageContent() async {
    final admin = await currentAdminUser();
    return admin?.canManageContent ?? false;
  }

  @override
  Future<AdminUser?> currentAdminUser() {
    return _adminAuthRepository.currentAdmin();
  }

  /// Adapts the admin session to the shared interface.
  ///
  /// The decorators predate roles and only ask "is this an admin", so an
  /// active admin is presented as a parent account carrying the admin role.
  @override
  Future<ParentAccount?> currentParent() async {
    final admin = await currentAdminUser();
    if (admin == null) return null;

    return ParentAccount(
      id: admin.uid,
      email: admin.email,
      createdAt: admin.createdAt ?? DateTime.now(),
      role: ParentRole.admin,
    );
  }

  @override
  Future<void> requireContentAdmin() {
    return _require((admin) => admin.canManageContent);
  }

  @override
  Future<void> requireStatisticsAccess() {
    return _require((admin) => admin.canViewStatistics);
  }

  @override
  Future<void> requireParentAccountAccess() {
    return _require((admin) => admin.canViewParentAccounts);
  }

  Future<void> _require(bool Function(AdminUser admin) allowed) async {
    final admin = await currentAdminUser();
    if (admin == null) {
      throw const AdminPermissionException(
        'Sign in to the admin portal to manage content.',
      );
    }

    if (!admin.canSignIn) {
      throw const AdminPermissionException(AdminAuthMessages.suspended);
    }

    if (!allowed(admin)) {
      // The account is a valid admin; this particular role just cannot do it.
      throw AdminPermissionException(
        'Your ${admin.role.label} role does not allow this action.',
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
  Future<List<AdminContentLevel>> upsertLevels(List<AdminContentLevel> levels) {
    return _authorized(() => _delegate.upsertLevels(levels));
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

class AuthorizedAdminKoalaGuideRepository implements AdminKoalaGuideRepository {
  const AuthorizedAdminKoalaGuideRepository({
    required AdminKoalaGuideRepository delegate,
    required AdminAuthorizationRepository authorizationRepository,
  })  : _delegate = delegate,
        _authorizationRepository = authorizationRepository;

  final AdminKoalaGuideRepository _delegate;
  final AdminAuthorizationRepository _authorizationRepository;

  @override
  Future<void> deleteMessage(String messageId) {
    return _authorized(() => _delegate.deleteMessage(messageId));
  }

  @override
  Future<List<AdminKoalaGuideMessage>> getMessages() {
    return _authorized(_delegate.getMessages);
  }

  @override
  Future<AdminKoalaGuideMessage> upsertMessage(
    AdminKoalaGuideMessage message,
  ) {
    return _authorized(() => _delegate.upsertMessage(message));
  }

  Future<T> _authorized<T>(Future<T> Function() action) async {
    await _authorizationRepository.requireContentAdmin();
    return action();
  }
}
