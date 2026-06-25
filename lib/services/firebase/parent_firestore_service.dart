import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/onboarding.dart';
import '../../models/parent_account.dart';

abstract class ParentRemoteDataSource {
  Future<ParentAccount> ensureParentDocument(ParentAccount parent);

  Future<ParentOnboardingState> getOnboardingState(String parentId);

  Future<ParentOnboardingState> updateManualPage({
    required String parentId,
    required int pageIndex,
  });

  Future<ParentOnboardingState> completeManual(String parentId);

  Future<ParentOnboardingState> updateReadinessResult({
    required String parentId,
    required int score,
    required bool passed,
  });
}

class ParentFirestoreService implements ParentRemoteDataSource {
  ParentFirestoreService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _parents {
    return _firestore.collection('parents');
  }

  @override
  Future<ParentAccount> ensureParentDocument(ParentAccount parent) async {
    final ref = _parents.doc(parent.id);
    final snapshot = await ref.get();
    if (snapshot.exists) {
      final data = snapshot.data() ?? {};
      if (!data.containsKey('role')) {
        await ref.set({
          'role': ParentRole.parent.name,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      return parent.copyWith(role: _roleFromRemote(data));
    }

    await ref.set({
      'email': parent.email,
      'role': ParentRole.parent.name,
      'manualViewed': false,
      'testPassed': false,
      'testScore': 0,
      'lastManualPageIndex': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return parent.copyWith(role: ParentRole.parent);
  }

  @override
  Future<ParentOnboardingState> getOnboardingState(String parentId) async {
    final snapshot = await _parents.doc(parentId).get();
    if (!snapshot.exists) {
      return ParentOnboardingState.initial(parentId);
    }

    final data = snapshot.data() ?? {};
    return ParentOnboardingState(
      parentId: parentId,
      manualCompleted: (data['manualViewed'] as bool?) ?? false,
      testPassed: (data['testPassed'] as bool?) ?? false,
      testScore: (data['testScore'] as num?)?.toInt() ?? 0,
      lastManualPageIndex: (data['lastManualPageIndex'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  Future<ParentOnboardingState> updateManualPage({
    required String parentId,
    required int pageIndex,
  }) async {
    await _parents.doc(parentId).set({
      'lastManualPageIndex': pageIndex,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    return getOnboardingState(parentId);
  }

  @override
  Future<ParentOnboardingState> completeManual(String parentId) async {
    await _parents.doc(parentId).set({
      'manualViewed': true,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    return getOnboardingState(parentId);
  }

  @override
  Future<ParentOnboardingState> updateReadinessResult({
    required String parentId,
    required int score,
    required bool passed,
  }) async {
    final current = await getOnboardingState(parentId);
    await _parents.doc(parentId).set({
      'testPassed': current.testPassed || passed,
      'testScore': score,
      'testDate': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    return getOnboardingState(parentId);
  }

  ParentRole _roleFromRemote(Map<String, dynamic> data) {
    if (data['isAdmin'] == true) return ParentRole.admin;

    final role = data['role'];
    if (role is! String) return ParentRole.parent;

    final normalizedRole = role.trim().toLowerCase();
    return ParentRole.values.firstWhere(
      (value) => value.name == normalizedRole,
      orElse: () => ParentRole.parent,
    );
  }
}
