import '../data/onboarding_content.dart';
import '../models/onboarding.dart';

abstract class OnboardingRepository {
  Future<ParentOnboardingState> getState(String parentId);
  Future<ParentOnboardingState> saveManualPage({
    required String parentId,
    required int pageIndex,
  });
  Future<ParentOnboardingState> completeManual(String parentId);
  Future<ParentOnboardingState> saveReadinessResult({
    required String parentId,
    required int score,
    required bool passed,
  });
  Future<List<ManualPageContent>> getManualPages();
  Future<List<ReadinessQuestion>> getReadinessQuestions();
}

class InMemoryOnboardingRepository implements OnboardingRepository {
  final Map<String, ParentOnboardingState> _statesByParentId = {};

  @override
  Future<ParentOnboardingState> completeManual(String parentId) async {
    final state = await getState(parentId);
    final updated = state.copyWith(
      manualCompleted: true,
      lastManualPageIndex: manualPages.length - 1,
    );
    _statesByParentId[parentId] = updated;
    return updated;
  }

  @override
  Future<List<ManualPageContent>> getManualPages() async => manualPages;

  @override
  Future<List<ReadinessQuestion>> getReadinessQuestions() async {
    return readinessQuestions;
  }

  @override
  Future<ParentOnboardingState> getState(String parentId) async {
    return _statesByParentId.putIfAbsent(
      parentId,
      () => ParentOnboardingState.initial(parentId),
    );
  }

  @override
  Future<ParentOnboardingState> saveManualPage({
    required String parentId,
    required int pageIndex,
  }) async {
    final state = await getState(parentId);
    final updated = state.copyWith(lastManualPageIndex: pageIndex);
    _statesByParentId[parentId] = updated;
    return updated;
  }

  @override
  Future<ParentOnboardingState> saveReadinessResult({
    required String parentId,
    required int score,
    required bool passed,
  }) async {
    final state = await getState(parentId);
    final updated = state.copyWith(
      testPassed: state.testPassed || passed,
      testScore: score,
    );
    _statesByParentId[parentId] = updated;
    return updated;
  }
}
