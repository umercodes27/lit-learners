import 'package:flutter_test/flutter_test.dart';
import 'package:little_learners/models/onboarding.dart';
import 'package:little_learners/models/parent_account.dart';
import 'package:little_learners/repositories/firestore_onboarding_repository.dart';
import 'package:little_learners/services/firebase/parent_firestore_service.dart';

void main() {
  group('FirestoreOnboardingRepository', () {
    test('loads bundled manual and readiness content', () async {
      final repository = FirestoreOnboardingRepository(
        parentRemoteDataSource: _FakeParentRemoteDataSource(),
      );

      final manualPages = await repository.getManualPages();
      final questions = await repository.getReadinessQuestions();

      expect(manualPages, isNotEmpty);
      expect(questions, isNotEmpty);
    });

    test('delegates onboarding progress to the remote parent data source',
        () async {
      final remoteDataSource = _FakeParentRemoteDataSource();
      final repository = FirestoreOnboardingRepository(
        parentRemoteDataSource: remoteDataSource,
      );

      final pageState = await repository.saveManualPage(
        parentId: 'parent-1',
        pageIndex: 2,
      );
      final manualState = await repository.completeManual('parent-1');
      final testState = await repository.saveReadinessResult(
        parentId: 'parent-1',
        score: 80,
        passed: true,
      );

      expect(pageState.lastManualPageIndex, 2);
      expect(manualState.manualCompleted, isTrue);
      expect(testState.testPassed, isTrue);
      expect(testState.testScore, 80);
    });
  });
}

class _FakeParentRemoteDataSource implements ParentRemoteDataSource {
  ParentOnboardingState _state = ParentOnboardingState.initial('parent-1');

  @override
  Future<ParentAccount> ensureParentDocument(ParentAccount parent) async {
    return parent;
  }

  @override
  Future<ParentOnboardingState> getOnboardingState(String parentId) async {
    return _state;
  }

  @override
  Future<ParentOnboardingState> updateManualPage({
    required String parentId,
    required int pageIndex,
  }) async {
    _state = _state.copyWith(lastManualPageIndex: pageIndex);
    return _state;
  }

  @override
  Future<ParentOnboardingState> completeManual(String parentId) async {
    _state = _state.copyWith(manualCompleted: true);
    return _state;
  }

  @override
  Future<ParentOnboardingState> updateReadinessResult({
    required String parentId,
    required int score,
    required bool passed,
  }) async {
    _state = _state.copyWith(
      testPassed: _state.testPassed || passed,
      testScore: score,
    );
    return _state;
  }
}
