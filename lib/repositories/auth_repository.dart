import '../models/parent_account.dart';

abstract class AuthRepository {
  Future<ParentAccount?> currentParent();
  Future<ParentAccount> signIn({
    required String email,
    required String password,
  });
  Future<ParentAccount> signUp({
    required String email,
    required String password,
  });
  Future<void> sendPasswordReset(String email);
  Future<void> signOut();
}

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

class InMemoryAuthRepository implements AuthRepository {
  InMemoryAuthRepository({
    Set<String> adminEmails = const {'admin@littlelearners.local'},
  }) : _adminEmails = adminEmails
            .map((email) => email.trim().toLowerCase())
            .where((email) => email.isNotEmpty)
            .toSet();

  final Map<String, _StoredParent> _parentsByEmail = {};
  final Set<String> _adminEmails;
  ParentAccount? _currentParent;

  @override
  Future<ParentAccount?> currentParent() async => _currentParent;

  @override
  Future<ParentAccount> signIn({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final storedParent = _parentsByEmail[normalizedEmail];

    if (storedParent == null || storedParent.password != password) {
      throw const AuthException('Email or password is incorrect.');
    }

    _currentParent = storedParent.account;
    return storedParent.account;
  }

  @override
  Future<ParentAccount> signUp({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (_parentsByEmail.containsKey(normalizedEmail)) {
      throw const AuthException('An account already exists for this email.');
    }

    final account = ParentAccount(
      id: 'parent-${DateTime.now().microsecondsSinceEpoch}',
      email: normalizedEmail,
      createdAt: DateTime.now(),
      role: _roleFor(normalizedEmail),
    );
    _parentsByEmail[normalizedEmail] = _StoredParent(
      account: account,
      password: password,
    );
    _currentParent = account;
    return account;
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (!_parentsByEmail.containsKey(normalizedEmail)) {
      throw const AuthException('No account found for this email.');
    }
  }

  @override
  Future<void> signOut() async {
    _currentParent = null;
  }

  ParentRole _roleFor(String normalizedEmail) {
    return _adminEmails.contains(normalizedEmail)
        ? ParentRole.admin
        : ParentRole.parent;
  }
}

class _StoredParent {
  const _StoredParent({
    required this.account,
    required this.password,
  });

  final ParentAccount account;
  final String password;
}
