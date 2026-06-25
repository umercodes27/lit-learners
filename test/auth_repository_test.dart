import 'package:flutter_test/flutter_test.dart';
import 'package:little_learners/models/parent_account.dart';
import 'package:little_learners/repositories/auth_repository.dart';

void main() {
  group('InMemoryAuthRepository', () {
    test('signs up and signs in a parent account', () async {
      final repository = InMemoryAuthRepository();

      final created = await repository.signUp(
        email: 'Parent@Example.com',
        password: 'Strong1!',
      );
      await repository.signOut();
      final signedIn = await repository.signIn(
        email: 'parent@example.com',
        password: 'Strong1!',
      );

      expect(signedIn.id, created.id);
      expect((await repository.currentParent())?.id, created.id);
    });

    test('rejects duplicate signup', () async {
      final repository = InMemoryAuthRepository();

      await repository.signUp(
        email: 'parent@example.com',
        password: 'Strong1!',
      );

      await expectLater(
        repository.signUp(
          email: 'parent@example.com',
          password: 'Strong1!',
        ),
        throwsA(isA<AuthException>()),
      );
    });

    test('marks configured admin emails with the admin role', () async {
      final repository = InMemoryAuthRepository(
        adminEmails: const {'owner@example.com'},
      );

      final admin = await repository.signUp(
        email: 'Owner@Example.com',
        password: 'Strong1!',
      );

      expect(admin.role, ParentRole.admin);
      expect(admin.canManageAdminContent, isTrue);
    });
  });
}
