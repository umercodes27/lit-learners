class ManualPageContent {
  const ManualPageContent({
    required this.title,
    required this.body,
    required this.iconName,
  });

  final String title;
  final String body;
  final String iconName;
}

class ReadinessQuestion {
  const ReadinessQuestion({
    required this.id,
    required this.prompt,
    required this.options,
    required this.correctIndex,
    required this.tip,
  });

  final String id;
  final String prompt;
  final List<String> options;
  final int correctIndex;
  final String tip;

  bool isCorrect(int answerIndex) => answerIndex == correctIndex;
}

class ParentOnboardingState {
  const ParentOnboardingState({
    required this.parentId,
    required this.manualCompleted,
    required this.testPassed,
    required this.testScore,
    required this.lastManualPageIndex,
  });

  factory ParentOnboardingState.initial(String parentId) {
    return ParentOnboardingState(
      parentId: parentId,
      manualCompleted: false,
      testPassed: false,
      testScore: 0,
      lastManualPageIndex: 0,
    );
  }

  final String parentId;
  final bool manualCompleted;
  final bool testPassed;
  final int testScore;
  final int lastManualPageIndex;

  ParentOnboardingState copyWith({
    bool? manualCompleted,
    bool? testPassed,
    int? testScore,
    int? lastManualPageIndex,
  }) {
    return ParentOnboardingState(
      parentId: parentId,
      manualCompleted: manualCompleted ?? this.manualCompleted,
      testPassed: testPassed ?? this.testPassed,
      testScore: testScore ?? this.testScore,
      lastManualPageIndex: lastManualPageIndex ?? this.lastManualPageIndex,
    );
  }
}
