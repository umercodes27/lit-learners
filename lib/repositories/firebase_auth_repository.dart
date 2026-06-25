import '../models/parent_account.dart';
import '../services/firebase/firebase_auth_service.dart';
import '../services/firebase/parent_firestore_service.dart';
import 'auth_repository.dart';

class FirebaseAuthRepository implements AuthRepository {
  const FirebaseAuthRepository({
    required ParentAuthRemoteDataSource authService,
    required ParentRemoteDataSource parentRemoteDataSource,
  })  : _authService = authService,
        _parentRemoteDataSource = parentRemoteDataSource;

  final ParentAuthRemoteDataSource _authService;
  final ParentRemoteDataSource _parentRemoteDataSource;

  @override
  Future<ParentAccount?> currentParent() async {
    final parent = _authService.currentParent();
    if (parent == null) return null;

    return _parentRemoteDataSource.ensureParentDocument(parent);
  }

  @override
  Future<ParentAccount> signIn({
    required String email,
    required String password,
  }) async {
    final parent = await _authService.signIn(
      email: email,
      password: password,
    );
    return _parentRemoteDataSource.ensureParentDocument(parent);
  }

  @override
  Future<ParentAccount> signUp({
    required String email,
    required String password,
  }) async {
    final parent = await _authService.signUp(
      email: email,
      password: password,
    );
    return _parentRemoteDataSource.ensureParentDocument(parent);
  }

  @override
  Future<void> sendPasswordReset(String email) {
    return _authService.sendPasswordReset(email);
  }

  @override
  Future<void> signOut() {
    return _authService.signOut();
  }
}
