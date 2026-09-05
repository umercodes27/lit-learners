import 'package:flutter_test/flutter_test.dart';
import 'package:little_learners/core/utils/age_stage_helper.dart';
import 'package:little_learners/data/seed_content.dart';
import 'package:little_learners/models/learning_level.dart';

/// The navigation flow is Child ▸ Modules ▸ Levels ▸ sequential content, where
/// each level covers one portion of its module — `A – F`, then `G – L`. These
/// guard that shape, which is easy to break by hand-editing the seed.
void main() {
  group('English alphabet ladder', () {
    test('covers A to Z exactly once per stage, in order', () {
      for (var stage = AgeStageHelper.minStage; stage <= 4; stage++) {
        final letters = _englishLevels(stage)
            .expand((level) => level.contentItems.map((item) => item.title))
            .toList();

        expect(
          letters.join(),
          'ABCDEFGHIJKLMNOPQRSTUVWXYZ',
          reason: 'stage $stage',
        );
      }
    });

    test('numbers its levels consecutively from one', () {
      for (var stage = AgeStageHelper.minStage; stage <= 4; stage++) {
        final levels = _englishLevels(stage);

        expect(
          levels.map((level) => level.levelNumber),
          List.generate(levels.length, (index) => index + 1),
          reason: 'stage $stage',
        );
      }
    });

    test('names the portion each level covers', () {
      for (final level in _englishLevels(3)) {
        final letters = level.contentItems.map((item) => item.title).toList();

        expect(
          level.portionLabel,
          '${letters.first} – ${letters.last}',
          reason: level.id,
        );
      }
    });

    test('asks quizzes only from stage three, about letters it taught', () {
      for (var stage = AgeStageHelper.minStage; stage <= 4; stage++) {
        for (final level in _englishLevels(stage)) {
          if (stage < 3) {
            expect(level.quizQuestions, isEmpty, reason: level.id);
            continue;
          }

          expect(level.quizQuestions, isNotEmpty, reason: level.id);
          final taught = level.contentItems.map((item) => item.title).toSet();
          for (final question in level.quizQuestions) {
            expect(
              taught.containsAll(question.options),
              isTrue,
              reason: '${question.id} offers a letter this level never taught',
            );
            // A wrong `correctIndex` would teach the child the wrong answer,
            // so check it against the word the question actually names.
            final word = question.prompt
                .split('does ')
                .last
                .split(' start')
                .first;
            expect(
              question.options[question.correctIndex],
              word[0].toUpperCase(),
              reason: '${question.id}: "$word"',
            );
          }
        }
      }
    });

    test('every level is playable offline out of the box', () {
      for (var stage = AgeStageHelper.minStage; stage <= 4; stage++) {
        for (final level in _englishLevels(stage)) {
          expect(level.isAvailableOffline, isTrue, reason: level.id);
        }
      }
    });
  });

  test('a portion label, where present, reads as a range', () {
    final labelled = seedLevels.where((level) => level.portionLabel != null);

    expect(labelled, isNotEmpty);
    for (final level in labelled) {
      expect(level.portionLabel!.trim(), isNotEmpty, reason: level.id);
      expect(level.contentItems, isNotEmpty, reason: level.id);
    }
  });
}

List<LearningLevel> _englishLevels(int stage) {
  return seedLevels
      .where((level) => level.moduleId == 'english' && level.stage == stage)
      .toList()
    ..sort((a, b) => a.levelNumber.compareTo(b.levelNumber));
}
