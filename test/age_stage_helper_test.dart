import 'package:flutter_test/flutter_test.dart';
import 'package:little_learners/core/utils/age_stage_helper.dart';

void main() {
  group('AgeStageHelper', () {
    test('maps toddler age to the expected learning stage', () {
      expect(AgeStageHelper.stageForAge(1), 1);
      expect(AgeStageHelper.stageForAge(2), 2);
      expect(AgeStageHelper.stageForAge(3), 3);
      expect(AgeStageHelper.stageForAge(4), 4);
    });

    test('shows quizzes only for ages 3 and above', () {
      expect(AgeStageHelper.shouldShowQuiz(1), isFalse);
      expect(AgeStageHelper.shouldShowQuiz(2), isFalse);
      expect(AgeStageHelper.shouldShowQuiz(3), isTrue);
      expect(AgeStageHelper.shouldShowQuiz(4), isTrue);
    });
  });
}
