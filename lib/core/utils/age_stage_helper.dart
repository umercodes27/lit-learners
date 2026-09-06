class AgeStageHelper {
  const AgeStageHelper._();

  /// The youngest age the app accepts, and so the lowest stage any child
  /// reaches. Stage numbers are deliberately left as they were when age 1 was
  /// dropped: they are stored in progress rows, in `leaderboards/stage-{n}`
  /// document ids and in published admin content, so renumbering them would
  /// invalidate data that is already out there. Stage 1 simply has nobody in
  /// it any more.
  static const minStage = 2;

  static int stageForAge(int age) {
    if (age <= 2) return minStage;
    if (age == 3) return 3;
    return 4;
  }

  static bool shouldShowQuiz(int age) => age >= 3;
}
