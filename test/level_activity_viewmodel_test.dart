import 'package:flutter_test/flutter_test.dart';
import 'package:little_learners/models/content_item.dart';
import 'package:little_learners/models/learning_level.dart';
import 'package:little_learners/viewmodels/level_activity_viewmodel.dart';

void main() {
  group('LevelActivityViewModel', () {
    test('counting activity completes after target taps', () {
      final viewModel = LevelActivityViewModel(_countingLevel());

      expect(viewModel.targetCount, 3);
      expect(viewModel.currentItemComplete, isFalse);

      viewModel.tapCounter();
      viewModel.tapCounter();

      expect(viewModel.currentItemComplete, isFalse);

      viewModel.tapCounter();

      expect(viewModel.currentItemComplete, isTrue);
      expect(viewModel.isActivityComplete, isFalse);

      viewModel.nextItem();
      viewModel.tapCounter();

      expect(viewModel.isActivityComplete, isTrue);
    });

    test('matching activity completes only on correct option', () {
      final viewModel = LevelActivityViewModel(_matchingLevel());

      viewModel.selectMatch('Triangle');

      expect(viewModel.currentItemComplete, isFalse);

      viewModel.selectMatch('Circle');

      expect(viewModel.currentItemComplete, isTrue);
    });

    test('drawing activity tracks color choice and resets on next prompt', () {
      final viewModel = LevelActivityViewModel(_drawingLevel());

      expect(viewModel.drawingColorOptions, ['Red', 'Blue', 'Yellow', 'Green']);
      expect(viewModel.selectedDrawingColor, 'Red');

      viewModel.selectDrawingColor('Blue');
      viewModel.selectDrawingColor('Purple');

      expect(viewModel.selectedDrawingColor, 'Blue');

      viewModel.markCurrentLearned();
      viewModel.nextItem();

      expect(viewModel.currentItem.title, 'Blue Dot');
      expect(viewModel.selectedDrawingColor, 'Red');
      expect(viewModel.currentItemComplete, isFalse);
    });
  });
}

LearningLevel _countingLevel() {
  return const LearningLevel(
    id: 'counting',
    moduleId: 'math',
    stage: 3,
    levelNumber: 1,
    title: 'Counting',
    subtitle: 'Count',
    type: LevelType.counting,
    passingScore: 70,
    isBundled: true,
    contentItems: [
      ContentItem(
        title: 'Three',
        prompt: 'Tap three times.',
        displayText: '3',
        visualLabel: 'Three dots',
      ),
      ContentItem(
        title: 'One',
        prompt: 'Tap once.',
        displayText: '1',
        visualLabel: 'One dot',
      ),
    ],
  );
}

LearningLevel _matchingLevel() {
  return const LearningLevel(
    id: 'matching',
    moduleId: 'math',
    stage: 3,
    levelNumber: 2,
    title: 'Matching',
    subtitle: 'Match',
    type: LevelType.matching,
    passingScore: 70,
    isBundled: true,
    contentItems: [
      ContentItem(
        title: 'Circle',
        prompt: 'Find circle.',
        displayText: 'O',
        visualLabel: 'Circle',
      ),
      ContentItem(
        title: 'Triangle',
        prompt: 'Find triangle.',
        displayText: '△',
        visualLabel: 'Triangle',
      ),
    ],
  );
}

LearningLevel _drawingLevel() {
  return const LearningLevel(
    id: 'drawing',
    moduleId: 'drawing',
    stage: 1,
    levelNumber: 1,
    title: 'Drawing',
    subtitle: 'Draw',
    type: LevelType.drawing,
    passingScore: 60,
    isBundled: true,
    contentItems: [
      ContentItem(
        title: 'Red Line',
        prompt: 'Draw a red line.',
        displayText: 'Red',
        visualLabel: 'Red line',
      ),
      ContentItem(
        title: 'Blue Dot',
        prompt: 'Draw a blue dot.',
        displayText: 'Blue',
        visualLabel: 'Blue dot',
      ),
    ],
  );
}
