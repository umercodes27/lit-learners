import 'package:flutter_test/flutter_test.dart';
import 'package:little_learners/core/utils/age_stage_helper.dart';

void main() {
  group('AgeStageHelper', () {
    test('maps toddler age to the expected learning stage', () {
      expect(AgeStageHelper.stageForAge(2), AgeStageHelper.minStage);
      expect(AgeStageHelper.stageForAge(3), 3);
      expect(AgeStageHelper.stageForAge(4), 4);
    });

    test('a profile saved before age 2 was the floor still lands in range', () {
      // Age 1 was accepted until the app narrowed to 2-4. A profile created
      // back then is still in the database, and reads as the youngest stage
      // rather than as a stage nothing is authored for.
      expect(AgeStageHelper.stageForAge(1), AgeStageHelper.minStage);
    });

    test('shows quizzes only for ages 3 and above', () {
      expect(AgeStageHelper.shouldShowQuiz(2), isFalse);
      expect(AgeStageHelper.shouldShowQuiz(3), isTrue);
      expect(AgeStageHelper.shouldShowQuiz(4), isTrue);
    });
  });
}
