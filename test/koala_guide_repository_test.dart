import 'package:flutter_test/flutter_test.dart';
import 'package:little_learners/models/koala_guide_message.dart';
import 'package:little_learners/repositories/koala_guide_repository.dart';

void main() {
  group('SeededKoalaGuideRepository', () {
    test('selects module-specific child guidance before generic guidance',
        () async {
      const repository = SeededKoalaGuideRepository(
        messages: [
          KoalaGuideMessage(
            id: 'generic',
            trigger: KoalaGuideTrigger.activityStart,
            audience: KoalaGuideAudience.child,
            message: 'Generic activity.',
          ),
          KoalaGuideMessage(
            id: 'english',
            trigger: KoalaGuideTrigger.activityStart,
            audience: KoalaGuideAudience.child,
            moduleId: 'english',
            message: 'English activity.',
          ),
        ],
      );

      final message = await repository.getMessage(
        const KoalaGuideRequest(
          trigger: KoalaGuideTrigger.activityStart,
          audience: KoalaGuideAudience.child,
          moduleId: 'english',
          stage: 3,
        ),
      );

      expect(message.id, 'english');
      expect(message.message, 'English activity.');
    });

    test('selects level-specific guidance before module guidance', () async {
      const repository = SeededKoalaGuideRepository(
        messages: [
          KoalaGuideMessage(
            id: 'module',
            trigger: KoalaGuideTrigger.activityStart,
            audience: KoalaGuideAudience.child,
            moduleId: 'story',
            message: 'Story module.',
          ),
          KoalaGuideMessage(
            id: 'level',
            trigger: KoalaGuideTrigger.activityStart,
            audience: KoalaGuideAudience.child,
            moduleId: 'story',
            levelId: 'story-stage3-1',
            message: 'Kite story.',
          ),
        ],
      );

      final message = await repository.getMessage(
        const KoalaGuideRequest(
          trigger: KoalaGuideTrigger.activityStart,
          audience: KoalaGuideAudience.child,
          moduleId: 'story',
          levelId: 'story-stage3-1',
          stage: 3,
        ),
      );

      expect(message.id, 'level');
      expect(message.message, 'Kite story.');
    });

    test('returns fallback message when no seeded message matches', () async {
      const repository = SeededKoalaGuideRepository(messages: []);

      final message = await repository.getMessage(
        const KoalaGuideRequest(
          trigger: KoalaGuideTrigger.lockedLevel,
          audience: KoalaGuideAudience.child,
          fallbackMessage: 'Finish the previous level first.',
        ),
      );

      expect(message.id, 'fallback-lockedLevel-child');
      expect(message.message, 'Finish the previous level first.');
      expect(message.mood, KoalaGuideMood.encouraging);
    });

    test('loads seeded parent admin guidance with a parent tip', () async {
      const repository = SeededKoalaGuideRepository();

      final message = await repository.getMessage(
        const KoalaGuideRequest(
          trigger: KoalaGuideTrigger.adminContent,
          audience: KoalaGuideAudience.parent,
        ),
      );

      expect(message.id, 'admin-content');
      expect(message.parentTip, isNotNull);
      expect(message.mood, KoalaGuideMood.parent);
    });
  });
}
