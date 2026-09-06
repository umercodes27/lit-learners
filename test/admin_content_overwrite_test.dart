import 'package:flutter_test/flutter_test.dart';
import 'package:little_learners/models/learning_level.dart';
import 'package:little_learners/models/learning_module.dart';
import 'package:little_learners/repositories/admin_content_repository.dart';
import 'package:little_learners/services/remote/content_remote_data_source.dart';
import 'package:little_learners/viewmodels/admin_content_viewmodel.dart';

AdminContentViewModel viewModel([InMemoryContentRemoteDataSource? remote]) {
  return AdminContentViewModel(
    InMemoryAdminContentRepository(
      contentRemoteDataSource: remote ?? InMemoryContentRemoteDataSource(),
    ),
  );
}

Future<bool> createMath(
  AdminContentViewModel vm, {
  required String title,
  bool allowOverwrite = false,
}) {
  return vm.createModule(
    id: 'math',
    title: title,
    description: 'Numbers',
    category: ModuleCategory.math,
    minStage: 1,
    maxStage: 4,
    order: 1,
    isPublished: true,
    allowOverwrite: allowOverwrite,
  );
}

void main() {
  group('a module is never replaced by accident', () {
    test('a second module with the same ID is refused', () async {
      final vm = viewModel();
      expect(await createMath(vm, title: 'Math'), isTrue);

      final second = await createMath(vm, title: 'Mathematics');

      expect(second, isFalse);
      expect(vm.errorMessage, contains('already exists'));
      expect(vm.modules, hasLength(1));
      expect(vm.modules.single.module.title, 'Math',
          reason: 'the original must survive untouched');
    });

    test('the levels under it survive too', () async {
      final vm = viewModel();
      await createMath(vm, title: 'Math');
      await vm.createLevel(
        id: '',
        moduleId: 'math',
        stage: 1,
        levelNumber: 1,
        title: 'Count to 3',
        subtitle: 'Together',
        type: LevelType.counting,
        passingScore: 60,
        isPublished: true,
        contentTitle: 'Three',
        contentPrompt: 'Count three.',
        contentDisplayText: '3',
        contentVisualLabel: 'Three apples',
      );

      await createMath(vm, title: 'Mathematics');

      // The report was that creating a module wiped the existing one; a
      // module upsert does not touch level rows, but losing the module is
      // enough to orphan every level under it.
      expect(vm.levels, hasLength(1));
      expect(vm.modules.single.module.title, 'Math');
    });

    test('a title that slugs onto an existing ID is caught as well', () async {
      final vm = viewModel();
      await createMath(vm, title: 'Math');

      // No ID typed, so it is derived from the title — which slugs to "math".
      final clash = await vm.createModule(
        id: '',
        title: 'Math',
        description: 'Again',
        category: ModuleCategory.math,
        minStage: 1,
        maxStage: 4,
        order: 2,
        isPublished: true,
      );

      expect(clash, isFalse);
      expect(vm.modules, hasLength(1));
    });

    test('replacing is still possible when it is asked for', () async {
      final vm = viewModel();
      await createMath(vm, title: 'Math');

      final replaced =
          await createMath(vm, title: 'Mathematics', allowOverwrite: true);

      expect(replaced, isTrue);
      expect(vm.modules, hasLength(1));
      expect(vm.modules.single.module.title, 'Mathematics');
    });

    test('a different ID creates a second module rather than clashing',
        () async {
      final vm = viewModel();
      await createMath(vm, title: 'Math');

      final created = await vm.createModule(
        id: 'shapes',
        title: 'Shapes',
        description: 'Circles and squares',
        category: ModuleCategory.logic,
        minStage: 1,
        maxStage: 4,
        order: 9,
        isPublished: true,
      );

      expect(created, isTrue);
      expect(vm.modules, hasLength(2));
    });
  });

  group('a level is never replaced by accident', () {
    Future<bool> createLevel(
      AdminContentViewModel vm, {
      required String title,
      bool allowOverwrite = false,
    }) {
      return vm.createLevel(
        id: '',
        moduleId: 'math',
        stage: 1,
        levelNumber: 1,
        title: title,
        subtitle: 'Together',
        type: LevelType.flashcards,
        passingScore: 60,
        isPublished: true,
        contentTitle: 'One',
        contentPrompt: 'Say one.',
        contentDisplayText: '1',
        contentVisualLabel: 'One apple',
        allowOverwrite: allowOverwrite,
      );
    }

    test('the same module, stage and number is refused', () async {
      final vm = viewModel();
      await createMath(vm, title: 'Math');
      expect(await createLevel(vm, title: 'First'), isTrue);

      expect(await createLevel(vm, title: 'Also first'), isFalse);
      expect(vm.errorMessage, contains('already exists'));
      expect(vm.levels, hasLength(1));
      expect(vm.levels.single.level.title, 'First');
    });

    test('replacing works when asked for', () async {
      final vm = viewModel();
      await createMath(vm, title: 'Math');
      await createLevel(vm, title: 'First');

      expect(
        await createLevel(vm, title: 'Rewritten', allowOverwrite: true),
        isTrue,
      );
      expect(vm.levels.single.level.title, 'Rewritten');
    });
  });
}
