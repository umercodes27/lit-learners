import 'package:flutter_test/flutter_test.dart';
import 'package:little_learners/core/config/firebase_status.dart';
import 'package:little_learners/services/auth/last_account_store.dart';
import 'package:little_learners/repositories/auth_repository.dart';
import 'package:little_learners/viewmodels/auth_viewmodel.dart';

void main() {
  group('AuthViewModel password reset', () {
    test('asks the repository to mail a link and confirms in place', () async {
      final repository = InMemoryAuthRepository();
      await repository.signUp(email: 'parent@example.com', password: 'Old1!aaa');
      final viewModel = AuthViewModel(repository);

      expect(await viewModel.sendPasswordReset('Parent@Example.com '), isTrue);

      expect(repository.passwordResetEmails, ['parent@example.com']);
      expect(viewModel.infoMessage, contains('Reset link sent'));
      expect(viewModel.errorMessage, isNull);
    });

    test('rejects a malformed email without calling the backend', () async {
      final repository = InMemoryAuthRepository();
      final viewModel = AuthViewModel(repository);

      expect(await viewModel.sendPasswordReset('not-an-email'), isFalse);

      expect(repository.passwordResetEmails, isEmpty);
      expect(viewModel.errorMessage, 'Enter a valid email address.');
    });

    test('surfaces an unknown account as an error', () async {
      final viewModel = AuthViewModel(InMemoryAuthRepository());

      expect(await viewModel.sendPasswordReset('nobody@example.com'), isFalse);

      expect(viewModel.errorMessage, 'No account found for this email.');
      expect(viewModel.infoMessage, isNull);
    });

    test('clears a stale message when the screen is reopened', () async {
      final repository = InMemoryAuthRepository();
      await repository.signUp(email: 'parent@example.com', password: 'Old1!aaa');
      final viewModel = AuthViewModel(repository);
      await viewModel.sendPasswordReset('parent@example.com');

      viewModel.resetPasswordFlow();

      expect(viewModel.infoMessage, isNull);
      expect(viewModel.errorMessage, isNull);
    });
  });

  group('AuthViewModel Google sign-in', () {
    test('local mode says Google is unavailable rather than faking it',
        () async {
      final viewModel = AuthViewModel(InMemoryAuthRepository());

      // This used to hand back a `google.parent@littlelearners.local` account
      // and report success, which made a missing Firebase config look like a
      // broken Google integration.
      expect(await viewModel.signInWithGoogle(), isFalse);
      expect(viewModel.isAuthenticated, isFalse);
      expect(viewModel.errorMessage, FirebaseStatus.googleUnavailable);
    });

    test('stays quiet when the parent dismisses the chooser', () async {
      final viewModel = AuthViewModel(_CancellingAuthRepository());

      expect(await viewModel.signInWithGoogle(), isFalse);
      expect(viewModel.isAuthenticated, isFalse);
      // Backing out on purpose is not something to shout about.
      expect(viewModel.errorMessage, isNull);
    });
  });

  group('AuthViewModel remembered email', () {
    test('a successful sign-in is what makes the address worth keeping',
        () async {
      final store = InMemoryLastAccountStore();
      final repository = InMemoryAuthRepository();
      await repository.signUp(email: 'Parent@Example.com', password: 'Old1!aaa');
      final viewModel = AuthViewModel(repository, lastAccountStore: store);

      await viewModel.signIn(
        email: 'Parent@Example.com',
        password: 'Old1!aaa',
      );

      // Normalised, because that is what the parent will be shown next time.
      expect(await store.read(), 'parent@example.com');
      expect(viewModel.rememberedEmail, 'parent@example.com');
    });

    test('signing out keeps the address, which is the point of it', () async {
      final store = InMemoryLastAccountStore();
      final repository = InMemoryAuthRepository();
      await repository.signUp(email: 'parent@example.com', password: 'Old1!aaa');
      final viewModel = AuthViewModel(repository, lastAccountStore: store);
      await viewModel.signIn(
        email: 'parent@example.com',
        password: 'Old1!aaa',
      );

      await viewModel.signOut();

      expect(await store.read(), 'parent@example.com');
    });

    test('a failed sign-in leaves the remembered address alone', () async {
      final store = InMemoryLastAccountStore('kept@example.com');
      final viewModel = AuthViewModel(
        InMemoryAuthRepository(),
        lastAccountStore: store,
      );

      await viewModel.signIn(email: 'nobody@example.com', password: 'Old1!aaa');

      expect(await store.read(), 'kept@example.com');
    });

    test('"not you?" drops it', () async {
      final store = InMemoryLastAccountStore('parent@example.com');
      final viewModel = AuthViewModel(
        InMemoryAuthRepository(),
        lastAccountStore: store,
      );
      await viewModel.loadRememberedEmail();
      expect(viewModel.rememberedEmail, 'parent@example.com');

      await viewModel.forgetEmail();

      expect(viewModel.rememberedEmail, isNull);
      expect(await store.read(), isNull);
    });
  });
}

class _CancellingAuthRepository extends InMemoryAuthRepository {
  @override
  Future<Never> signInWithGoogle() async => throw const GoogleSignInCancelled();
}
