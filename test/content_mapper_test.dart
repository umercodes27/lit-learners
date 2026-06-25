import 'package:flutter_test/flutter_test.dart';
import 'package:little_learners/data/seed_content.dart';
import 'package:little_learners/services/local/content_mapper.dart';

void main() {
  test('ContentMapper round-trips a learning module', () {
    final module = seedModules.first;

    final restored = ContentMapper.moduleFromLocalMap(
      ContentMapper.moduleToLocalMap(module),
    );

    expect(restored.id, module.id);
    expect(restored.category, module.category);
    expect(restored.order, module.order);
  });

  test('ContentMapper round-trips level children', () {
    final level = seedLevels.firstWhere((item) => item.id == 'math-stage3-1');

    final restored = ContentMapper.levelFromLocalMaps(
      levelMap: ContentMapper.levelToLocalMap(level),
      contentItems: level.contentItems,
      quizQuestions: [
        ContentMapper.quizQuestionFromLocalMap(
          ContentMapper.quizQuestionToLocalMap(
            question: level.quizQuestions.first,
            levelId: level.id,
            sortOrder: 0,
          ),
        ),
      ],
      videoLessons: level.videoLessons,
    );

    expect(restored.id, level.id);
    expect(restored.type, level.type);
    expect(restored.contentItems, hasLength(2));
    expect(restored.quizQuestions.single.options, ['2', '3', '4']);
  });
}
