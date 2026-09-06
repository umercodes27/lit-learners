import '../core/config/firebase_status.dart';
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
  Future<ParentAccount> signInWithGoogle();

  /// Mails the parent a reset link. Firebase owns the rest of the flow: the
  /// link opens Firebase's own page, and the app never sees the new password.
  Future<void> sendPasswordReset(String email);

  Future<void> signOut();
}

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Thrown when the parent closes the Google account chooser. Separate from a
/// plain [AuthException] so the UI can stay quiet instead of showing an error
/// for something the parent did deliberately.
class GoogleSignInCancelled extends AuthException {
  const GoogleSignInCancelled() : super('Google sign-in was cancelled.');
}

/// Optional capability for enumerating registered accounts.
///
/// Only the admin monitoring screens need this, so it is kept off
/// [AuthRepository] — a parent-facing repository has no business listing every
/// account. In Firebase mode the equivalent read happens in Firestore.
abstract class ParentDirectory {
  Future<List<ParentAccount>> allParents();
}

class InMemoryAuthRepository implements AuthRepository, ParentDirectory {
  InMemoryAuthRepository({
    Set<String> adminEmails = const {'admin@littlelearners.local'},
  }) : _adminEmails = adminEmails
            .map((email) => email.trim().toLowerCase())
            .where((email) => email.isNotEmpty)
            .toSet();

  final Map<String, _StoredParent> _parentsByEmail = {};
  final Set<String> _adminEmails;
  ParentAccount? _currentParent;

  /// Emails a reset was asked for, so a test can assert the call happened
  /// without a mail server.
  final List<String> passwordResetEmails = [];

  @override
  Future<ParentAccount?> currentParent() async => _currentParent;

  @override
  Future<List<ParentAccount>> allParents() async {
    return _parentsByEmail.values.map((stored) => stored.account).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

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

  /// Adds an account without signing anybody in.
  ///
  /// [signUp] deliberately signs the new account in, which is right for a
  /// parent registering and wrong for seeding demo data — it would leave the
  /// app logged in as whichever invented family happened to be added last.
  ///
  /// Idempotent: seeding twice leaves one account, so this is safe to call on
  /// every launch.
  void seedAccount({
    required String id,
    required String email,
    required String password,
    required DateTime createdAt,
  }) {
    final normalizedEmail = email.trim().toLowerCase();
    if (_parentsByEmail.containsKey(normalizedEmail)) return;

    _parentsByEmail[normalizedEmail] = _StoredParent(
      account: ParentAccount(
        id: id,
        email: normalizedEmail,
        createdAt: createdAt,
        role: _roleFor(normalizedEmail),
      ),
      password: password,
    );
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

  /// Local mode has no Google to sign in to.
  ///
  /// This used to mint a `google.parent@littlelearners.local` account and
  /// report success, which made a missing Firebase config look like a broken
  /// Google integration: no account chooser ever appeared, every run produced
  /// a different parent id, and the children created under the last one were
  /// gone. Refusing is the honest answer - the button cannot do what it says
  /// here, and saying so points at the thing that actually needs fixing.
  @override
  Future<ParentAccount> signInWithGoogle() async {
    throw const AuthException(FirebaseStatus.googleUnavailable);
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (!_parentsByEmail.containsKey(normalizedEmail)) {
      throw const AuthException('No account found for this email.');
    }
    passwordResetEmails.add(normalizedEmail);
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

