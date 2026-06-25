class AgeStageHelper {
  const AgeStageHelper._();

  static int stageForAge(int age) {
    if (age <= 1) return 1;
    if (age == 2) return 2;
    if (age == 3) return 3;
    return 4;
  }

  static bool shouldShowQuiz(int age) => age >= 3;
}
