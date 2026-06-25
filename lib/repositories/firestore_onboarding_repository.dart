import '../data/onboarding_content.dart';
import '../models/onboarding.dart';
import '../services/firebase/parent_firestore_service.dart';
import 'onboarding_repository.dart';

class FirestoreOnboardingRepository implements OnboardingRepository {
  const FirestoreOnboardingRepository({
    required ParentRemoteDataSource parentRemoteDataSource,
  }) : _parentRemoteDataSource = parentRemoteDataSource;

  final ParentRemoteDataSource _parentRemoteDataSource;

  @override
  Future<ParentOnboardingState> getState(String parentId) {
    return _parentRemoteDataSource.getOnboardingState(parentId);
  }

  @override
  Future<ParentOnboardingState> saveManualPage({
    required String parentId,
    required int pageIndex,
  }) {
    return _parentRemoteDataSource.updateManualPage(
      parentId: parentId,
      pageIndex: pageIndex,
    );
  }

  @override
  Future<ParentOnboardingState> completeManual(String parentId) {
    return _parentRemoteDataSource.completeManual(parentId);
  }

  @override
  Future<ParentOnboardingState> saveReadinessResult({
    required String parentId,
    required int score,
    required bool passed,
  }) {
    return _parentRemoteDataSource.updateReadinessResult(
      parentId: parentId,
      score: score,
      passed: passed,
    );
  }

  @override
  Future<List<ManualPageContent>> getManualPages() async => manualPages;

  @override
  Future<List<ReadinessQuestion>> getReadinessQuestions() async {
    return readinessQuestions;
  }
}
