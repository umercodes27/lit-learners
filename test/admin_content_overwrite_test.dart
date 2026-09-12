import 'package:flutter_test/flutter_test.dart';
import 'package:little_learners/core/utils/age_stage_helper.dart';
import 'package:little_learners/data/seed_content.dart';
import 'package:little_learners/models/content_item.dart';
import 'package:little_learners/models/learning_level.dart';
import 'package:little_learners/models/learning_module.dart';
import 'package:little_learners/repositories/admin_content_repository.dart';
import 'package:little_learners/services/remote/content_remote_data_source.dart';
import 'package:little_learners/viewmodels/admin_content_viewmodel.dart';

/// With [withBundle] the viewmodel knows the curriculum that ships in the
/// app, as it does in the real app. Without it, only what an admin made.
AdminContentViewModel viewModel({bool withBundle = false}) {
  return AdminContentViewModel(
    InMemoryAdminContentRepository(
      contentRemoteDataSource: InMemoryContentRemoteDataSource(),
    ),
    bundledModules: withBundle ? null : const [],
    bundledLevels: withBundle ? null : const [],
  );
}

Future<bool> createModule(
  AdminContentViewModel vm, {
  String id = 'math',
  String title = 'Math',
}) {
  return vm.createModule(
    id: id,
    title: title,
    description: 'Numbers',
    category: ModuleCategory.math,
    minStage: AgeStageHelper.minStage,
    maxStage: 4,
    order: 1,
    isPublished: true,
  );
}

const oneCard = [
  ContentItem(
    title: 'One',
    prompt: 'Say one.',
    displayText: '1',
    visualLabel: 'One apple',
  ),
];

Future<bool> createLevel(
  AdminContentViewModel vm, {
  String id = '',
  String moduleId = 'math',
  int stage = AgeStageHelper.minStage,
  int levelNumber = 1,
  String title = 'First',
}) {
  return vm.createLevel(
    id: id,
    moduleId: moduleId,
    stage: stage,
    levelNumber: levelNumber,
    title: title,
    subtitle: 'Together',
    type: LevelType.flashcards,
    passingScore: 60,
    isPublished: true,
    contentItems: oneCard,
  );
}

void main() {
  group('creating a module never replaces one', () {
    test('a second module with the same ID is refused', () async {
      final vm = viewModel();
      expect(await createModule(vm), isTrue);

      expect(await createModule(vm, title: 'Mathematics'), isFalse);
      expect(vm.errorMessage, contains('already exists'));
      expect(vm.modules.single.module.title, 'Math',
          reason: 'the original must survive untouched');
    });

    test('a title that slugs onto an existing ID is caught as well', () async {
      final vm = viewModel();
      await createModule(vm);

      expect(await createModule(vm, id: '', title: 'Math'), isFalse);
      expect(vm.modules, hasLength(1));
    });

    // The reported case. "English" slugs to "english", which is the module
    // that ships in the app — and the panel used to have no idea it existed.
    test('reusing a built-in ID is refused and points at Edit', () async {
      final vm = viewModel(withBundle: true);

      final created =
          await createModule(vm, id: 'English', title: 'Phonics');

      expect(created, isFalse);
      expect(vm.errorMessage, contains('built-in'));
      expect(vm.errorMessage, contains('Edit'));
      expect(vm.moduleById('english')!.module.title, isNot('Phonics'));
    });

    test('a module with its own ID is added beside the built-in ones',
        () async {
      final vm = viewModel(withBundle: true);

      expect(await createModule(vm, id: 'phonics', title: 'Phonics'), isTrue);

      expect(vm.moduleById('english'), isNotNull);
      expect(vm.moduleById('phonics'), isNotNull);
      expect(vm.moduleOrigin('phonics'), ContentOrigin.custom);
    });

    test('there is no longer a way to overwrite by creating', () async {
      final vm = viewModel();
      await createModule(vm);
      await createLevel(vm);

      await createModule(vm, title: 'Mathematics');

      expect(vm.levels, hasLength(1));
      expect(vm.modules.single.module.title, 'Math');
    });
  });

  group('creating a level never replaces one', () {
    test('the same module, stage and number is refused', () async {
      final vm = viewModel();
      await createModule(vm);
      expect(await createLevel(vm), isTrue);

      expect(await createLevel(vm, title: 'Also first'), isFalse);
      expect(vm.errorMessage, contains('already exists'));
      expect(vm.levels.single.level.title, 'First');
    });

    test('a second level 1 under a different ID is refused too', () async {
      final vm = viewModel();
      await createModule(vm);
      await createLevel(vm);

      expect(await createLevel(vm, id: 'another-one'), isFalse);
      expect(vm.errorMessage, contains('already has a level 1'));
      expect(vm.errorMessage, contains('level number 2'));
    });

    test('a built-in level cannot be created over', () async {
      final vm = viewModel(withBundle: true);
      final builtIn = seedLevels.firstWhere((l) => l.moduleId == 'english');

      final created = await createLevel(
        vm,
        moduleId: 'english',
        stage: builtIn.stage,
        levelNumber: builtIn.levelNumber,
      );

      expect(created, isFalse);
      expect(vm.levelById(builtIn.id)!.level.title, builtIn.title);
    });

    test('the next number continues the ladder', () async {
      final vm = viewModel();
      await createModule(vm);
      await createLevel(vm);

      expect(vm.nextLevelNumber('math', AgeStageHelper.minStage), 2);
      expect(await createLevel(vm, levelNumber: 2, title: 'Second'), isTrue);
    });
  });

  group('editing is explicit', () {
    test('a module keeps its ID and gains a version', () async {
      final vm = viewModel();
      await createModule(vm);
      await createLevel(vm);
      final before = vm.modules.single;

      final updated = await vm.updateModule(
        before,
        title: 'Numbers',
        description: 'Counting',
        category: ModuleCategory.math,
        minStage: AgeStageHelper.minStage,
        maxStage: 4,
        order: 1,
        isPublished: true,
      );

      expect(updated, isTrue, reason: vm.errorMessage);
      expect(vm.modules.single.module.id, 'math');
      expect(vm.modules.single.module.title, 'Numbers');
      expect(vm.modules.single.version, before.version + 1);
    });

    test('a built-in level can be edited and restored', () async {
      final vm = viewModel(withBundle: true);
      final builtIn = seedLevels.firstWhere((l) => l.moduleId == 'math');
      final existing = vm.levelById(builtIn.id)!;

      final saved = await vm.updateLevel(
        existing,
        stage: builtIn.stage,
        levelNumber: builtIn.levelNumber,
        title: 'Count the ducks',
        subtitle: builtIn.subtitle,
        type: builtIn.type,
        passingScore: builtIn.passingScore,
        isPublished: true,
        contentItems: builtIn.contentItems,
        quizQuestions: builtIn.quizQuestions,
      );

      expect(saved, isTrue, reason: vm.errorMessage);
      expect(vm.levelOrigin(builtIn.id), ContentOrigin.builtInEdited);
      expect(vm.levelById(builtIn.id)!.level.title, 'Count the ducks');
      expect(vm.levelById(builtIn.id)!.level.isBundled, isTrue,
          reason: 'still available offline, like the original');

      expect(await vm.restoreBuiltInLevel(builtIn.id), isTrue);
      expect(vm.levelOrigin(builtIn.id), ContentOrigin.builtIn);
      expect(vm.levelById(builtIn.id)!.level.title, builtIn.title);
    });

    test('restoring a built-in module keeps the levels added to it', () async {
      final vm = viewModel(withBundle: true);
      final english = vm.moduleById('english')!;
      await vm.updateModule(
        english,
        title: 'Phonics and English',
        description: english.module.description,
        category: english.module.category,
        minStage: english.module.minStage,
        maxStage: english.module.maxStage,
        order: english.module.order,
        isPublished: true,
      );
      final stage = english.module.maxStage;
      final number = vm.nextLevelNumber('english', stage);
      expect(
        await createLevel(vm,
            moduleId: 'english', stage: stage, levelNumber: number),
        isTrue,
        reason: vm.errorMessage,
      );
      final added = vm.levels.last.level.id;

      expect(await vm.restoreBuiltInModule('english'), isTrue);

      expect(vm.moduleOrigin('english'), ContentOrigin.builtIn);
      expect(vm.levelById(added), isNotNull,
          reason: 'restoring a module must not take new levels with it');
    });

    test('built-in content cannot be deleted', () async {
      final vm = viewModel(withBundle: true);
      final builtIn = seedLevels.first;

      expect(await vm.deleteLevel(builtIn.id), isFalse);
      expect(await vm.deleteModule(builtIn.moduleId), isFalse);
      expect(vm.levelById(builtIn.id), isNotNull);
    });
  });

  group('a hand-made level is checked like a generated one', () {
    test('it can have many cards', () async {
      final vm = viewModel();
      await createModule(vm);

      final saved = await vm.createLevel(
        id: '',
        moduleId: 'math',
        stage: AgeStageHelper.minStage,
        levelNumber: 1,
        title: 'Count',
        subtitle: '',
        type: LevelType.counting,
        passingScore: 60,
        isPublished: false,
        contentItems: [
          for (var n = 1; n <= 5; n++)
            ContentItem(
              title: '$n',
              prompt: 'Count to $n.',
              displayText: '$n',
              visualLabel: '',
            ),
        ],
      );

      expect(saved, isTrue, reason: vm.errorMessage);
      expect(vm.levels.single.level.contentItems, hasLength(5));
      expect(vm.levels.single.level.contentItems.first.visualLabel, '1',
          reason: 'a blank picture description falls back to the title');
    });

    test('a counting card that is not a number is refused', () async {
      final vm = viewModel();
      await createModule(vm);

      final saved = await vm.createLevel(
        id: '',
        moduleId: 'math',
        stage: AgeStageHelper.minStage,
        levelNumber: 1,
        title: 'Count',
        subtitle: '',
        type: LevelType.counting,
        passingScore: 60,
        isPublished: false,
        contentItems: const [
          ContentItem(
            title: 'Three',
            prompt: 'Count.',
            displayText: 'three',
            visualLabel: '',
          ),
        ],
      );

      expect(saved, isFalse);
      expect(vm.errorMessage, startsWith('Card 1'));
    });
  });
}
