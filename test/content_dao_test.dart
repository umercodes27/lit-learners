import 'package:flutter_test/flutter_test.dart';
import 'package:little_learners/data/seed_content.dart';
import 'package:little_learners/services/local/content_dao.dart';

void main() {
  group('InMemoryContentDao', () {
    test('seeds modules and returns levels with child content', () async {
      final dao = InMemoryContentDao();

      expect(await dao.hasModules(), isFalse);

      await dao.seedContent(modules: seedModules, levels: seedLevels);

      expect(await dao.hasModules(), isTrue);
      expect(await dao.getModules(), hasLength(seedModules.length));

      final mathLevels = await dao.getLevelsForModule('math');
      expect(mathLevels.map((level) => level.id), contains('math-stage3-1'));

      final mathLevel = await dao.getLevelById('math-stage3-1');
      expect(mathLevel?.contentItems, hasLength(2));
      expect(mathLevel?.quizQuestions, hasLength(2));
    });
  });
}
