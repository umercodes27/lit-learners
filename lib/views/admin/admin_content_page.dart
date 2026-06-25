import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/admin_content.dart';
import '../../models/koala_guide_message.dart';
import '../../models/learning_level.dart';
import '../../models/learning_module.dart';
import '../../viewmodels/admin_content_viewmodel.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../widgets/app_primary_button.dart';
import '../../widgets/koala_guide.dart';

class AdminContentPage extends StatefulWidget {
  const AdminContentPage({super.key});

  @override
  State<AdminContentPage> createState() => _AdminContentPageState();
}

class _AdminContentPageState extends State<AdminContentPage> {
  final _moduleIdController = TextEditingController();
  final _moduleTitleController = TextEditingController();
  final _moduleDescriptionController = TextEditingController();
  final _moduleOrderController = TextEditingController(text: '1');
  var _moduleCategory = ModuleCategory.math;
  var _moduleMinStage = 1;
  var _moduleMaxStage = 4;
  var _modulePublished = false;

  final _levelIdController = TextEditingController();
  final _levelTitleController = TextEditingController();
  final _levelSubtitleController = TextEditingController();
  final _levelNumberController = TextEditingController(text: '1');
  final _levelPassingScoreController = TextEditingController(text: '70');
  final _contentTitleController = TextEditingController();
  final _contentPromptController = TextEditingController();
  final _contentDisplayController = TextEditingController();
  final _contentVisualController = TextEditingController();
  final _quizPromptController = TextEditingController();
  final _quizOptionsController = TextEditingController();
  final _quizCorrectIndexController = TextEditingController(text: '0');
  final _videoTitleController = TextEditingController();
  final _videoUrlController = TextEditingController();
  String? _selectedModuleId;
  var _levelStage = 1;
  var _levelType = LevelType.flashcards;
  var _levelPublished = false;
  var _didRequestLoad = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final parent = context.watch<AuthViewModel>().parent;
    if (parent?.canManageAdminContent == true && !_didRequestLoad) {
      _didRequestLoad = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<AdminContentViewModel>().loadContent();
      });
    }
  }

  @override
  void dispose() {
    _moduleIdController.dispose();
    _moduleTitleController.dispose();
    _moduleDescriptionController.dispose();
    _moduleOrderController.dispose();
    _levelIdController.dispose();
    _levelTitleController.dispose();
    _levelSubtitleController.dispose();
    _levelNumberController.dispose();
    _levelPassingScoreController.dispose();
    _contentTitleController.dispose();
    _contentPromptController.dispose();
    _contentDisplayController.dispose();
    _contentVisualController.dispose();
    _quizPromptController.dispose();
    _quizOptionsController.dispose();
    _quizCorrectIndexController.dispose();
    _videoTitleController.dispose();
    _videoUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();
    if (auth.isLoading) {
      return const Scaffold(
        body: SafeArea(child: Center(child: CircularProgressIndicator())),
      );
    }

    if (auth.parent?.canManageAdminContent != true) {
      return const _AdminAccessDeniedPage();
    }

    final admin = context.watch<AdminContentViewModel>();
    final modules = admin.modules;
    _selectedModuleId ??= modules.isEmpty ? null : modules.first.module.id;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Content'),
        actions: [
          IconButton(
            tooltip: 'Refresh content',
            onPressed: admin.isLoading
                ? null
                : () => context.read<AdminContentViewModel>().loadContent(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const ContextualKoalaGuide(
              trigger: KoalaGuideTrigger.adminContent,
              audience: KoalaGuideAudience.parent,
              fallbackMessage:
                  'Manage draft and published content for learners.',
            ),
            const SizedBox(height: 16),
            if (admin.isLoading)
              const Center(child: CircularProgressIndicator())
            else ...[
              _AdminStatus(admin: admin),
              _ModuleList(modules: modules),
              const SizedBox(height: 12),
              _LevelList(levels: admin.levels),
              const SizedBox(height: 16),
              _ModuleForm(
                idController: _moduleIdController,
                titleController: _moduleTitleController,
                descriptionController: _moduleDescriptionController,
                orderController: _moduleOrderController,
                category: _moduleCategory,
                minStage: _moduleMinStage,
                maxStage: _moduleMaxStage,
                isPublished: _modulePublished,
                onCategoryChanged: (value) {
                  setState(() => _moduleCategory = value);
                },
                onMinStageChanged: (value) {
                  setState(() => _moduleMinStage = value);
                },
                onMaxStageChanged: (value) {
                  setState(() => _moduleMaxStage = value);
                },
                onPublishedChanged: (value) {
                  setState(() => _modulePublished = value);
                },
                onSubmit: _createModule,
              ),
              const SizedBox(height: 16),
              _LevelForm(
                modules: modules,
                selectedModuleId: _selectedModuleId,
                idController: _levelIdController,
                titleController: _levelTitleController,
                subtitleController: _levelSubtitleController,
                levelNumberController: _levelNumberController,
                passingScoreController: _levelPassingScoreController,
                contentTitleController: _contentTitleController,
                contentPromptController: _contentPromptController,
                contentDisplayController: _contentDisplayController,
                contentVisualController: _contentVisualController,
                quizPromptController: _quizPromptController,
                quizOptionsController: _quizOptionsController,
                quizCorrectIndexController: _quizCorrectIndexController,
                videoTitleController: _videoTitleController,
                videoUrlController: _videoUrlController,
                stage: _levelStage,
                type: _levelType,
                isPublished: _levelPublished,
                onModuleChanged: (value) {
                  setState(() => _selectedModuleId = value);
                },
                onStageChanged: (value) {
                  setState(() => _levelStage = value);
                },
                onTypeChanged: (value) {
                  setState(() => _levelType = value);
                },
                onPublishedChanged: (value) {
                  setState(() => _levelPublished = value);
                },
                onSubmit: _createLevel,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _createModule() async {
    final created = await context.read<AdminContentViewModel>().createModule(
          id: _moduleIdController.text,
          title: _moduleTitleController.text,
          description: _moduleDescriptionController.text,
          category: _moduleCategory,
          minStage: _moduleMinStage,
          maxStage: _moduleMaxStage,
          order: int.tryParse(_moduleOrderController.text) ?? 1,
          isPublished: _modulePublished,
        );
    if (!created || !mounted) return;

    _moduleIdController.clear();
    _moduleTitleController.clear();
    _moduleDescriptionController.clear();
  }

  Future<void> _createLevel() async {
    final moduleId = _selectedModuleId;
    if (moduleId == null) return;

    final created = await context.read<AdminContentViewModel>().createLevel(
          id: _levelIdController.text,
          moduleId: moduleId,
          stage: _levelStage,
          levelNumber: int.tryParse(_levelNumberController.text) ?? 1,
          title: _levelTitleController.text,
          subtitle: _levelSubtitleController.text,
          type: _levelType,
          passingScore: int.tryParse(_levelPassingScoreController.text) ?? 70,
          isPublished: _levelPublished,
          contentTitle: _contentTitleController.text,
          contentPrompt: _contentPromptController.text,
          contentDisplayText: _contentDisplayController.text,
          contentVisualLabel: _contentVisualController.text,
          quizPrompt: _quizPromptController.text,
          quizOptions: _quizOptionsController.text.split(','),
          quizCorrectIndex: int.tryParse(_quizCorrectIndexController.text) ?? 0,
          videoTitle: _videoTitleController.text,
          videoUrl: _videoUrlController.text,
        );
    if (!created || !mounted) return;

    _levelIdController.clear();
    _levelTitleController.clear();
    _levelSubtitleController.clear();
    _contentTitleController.clear();
    _contentPromptController.clear();
    _contentDisplayController.clear();
    _contentVisualController.clear();
    _quizPromptController.clear();
    _quizOptionsController.clear();
    _videoTitleController.clear();
    _videoUrlController.clear();
  }
}

class _AdminAccessDeniedPage extends StatelessWidget {
  const _AdminAccessDeniedPage();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Content')),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.admin_panel_settings,
                  size: 48,
                  color: colorScheme.primary,
                ),
                const SizedBox(height: 12),
                Text(
                  'Admin access required',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'This parent account is not approved to manage content.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminStatus extends StatelessWidget {
  const _AdminStatus({required this.admin});

  final AdminContentViewModel admin;

  @override
  Widget build(BuildContext context) {
    if (admin.errorMessage == null && admin.infoMessage == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        admin.errorMessage ?? admin.infoMessage!,
        style: TextStyle(
          color: admin.errorMessage == null
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.error,
        ),
      ),
    );
  }
}

class _ModuleList extends StatelessWidget {
  const _ModuleList({required this.modules});

  final List<AdminContentModule> modules;

  @override
  Widget build(BuildContext context) {
    if (modules.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('No admin modules yet.'),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Modules',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 8),
        for (final module in modules)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Card(
              child: ListTile(
                title: Text(module.module.title),
                subtitle: Text(
                  '${module.module.category.name} - '
                  'Stages ${module.module.minStage}-${module.module.maxStage} - '
                  '${_statusLabel(module.publishStatus)} v${module.version}',
                ),
                trailing: _AdminActions(
                  isPublished: module.isPublished,
                  publishStatus: module.publishStatus,
                  onPublishedChanged: (value) {
                    context
                        .read<AdminContentViewModel>()
                        .toggleModulePublished(module, value);
                  },
                  onSubmitReview: () {
                    context
                        .read<AdminContentViewModel>()
                        .submitModuleForReview(module);
                  },
                  onMoveDraft: () {
                    context
                        .read<AdminContentViewModel>()
                        .moveModuleToDraft(module);
                  },
                  onDelete: () {
                    context
                        .read<AdminContentViewModel>()
                        .deleteModule(module.module.id);
                  },
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _LevelList extends StatelessWidget {
  const _LevelList({required this.levels});

  final List<AdminContentLevel> levels;

  @override
  Widget build(BuildContext context) {
    if (levels.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('No admin levels yet.'),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Levels',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 8),
        for (final level in levels)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Card(
              child: ListTile(
                title: Text(level.level.title),
                subtitle: Text(
                  '${level.level.moduleId} - stage ${level.level.stage} - '
                  '${level.level.type.name} - '
                  '${_statusLabel(level.publishStatus)} v${level.version}',
                ),
                trailing: _AdminActions(
                  isPublished: level.isPublished,
                  publishStatus: level.publishStatus,
                  onPublishedChanged: (value) {
                    context
                        .read<AdminContentViewModel>()
                        .toggleLevelPublished(level, value);
                  },
                  onSubmitReview: () {
                    context
                        .read<AdminContentViewModel>()
                        .submitLevelForReview(level);
                  },
                  onMoveDraft: () {
                    context
                        .read<AdminContentViewModel>()
                        .moveLevelToDraft(level);
                  },
                  onDelete: () {
                    context
                        .read<AdminContentViewModel>()
                        .deleteLevel(level.level.id);
                  },
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _AdminActions extends StatelessWidget {
  const _AdminActions({
    required this.isPublished,
    required this.publishStatus,
    required this.onPublishedChanged,
    required this.onSubmitReview,
    required this.onMoveDraft,
    required this.onDelete,
  });

  final bool isPublished;
  final AdminPublishStatus publishStatus;
  final ValueChanged<bool> onPublishedChanged;
  final VoidCallback onSubmitReview;
  final VoidCallback onMoveDraft;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Switch(value: isPublished, onChanged: onPublishedChanged),
        IconButton(
          tooltip: 'Submit for review',
          onPressed: publishStatus == AdminPublishStatus.inReview
              ? null
              : onSubmitReview,
          icon: const Icon(Icons.rate_review_outlined),
        ),
        IconButton(
          tooltip: 'Move to draft',
          onPressed:
              publishStatus == AdminPublishStatus.draft ? null : onMoveDraft,
          icon: const Icon(Icons.drafts_outlined),
        ),
        IconButton(
          tooltip: 'Delete',
          onPressed: onDelete,
          icon: const Icon(Icons.delete_outline),
        ),
      ],
    );
  }
}

String _statusLabel(AdminPublishStatus status) {
  return switch (status) {
    AdminPublishStatus.draft => 'Draft',
    AdminPublishStatus.inReview => 'In review',
    AdminPublishStatus.published => 'Published',
  };
}

class _ModuleForm extends StatelessWidget {
  const _ModuleForm({
    required this.idController,
    required this.titleController,
    required this.descriptionController,
    required this.orderController,
    required this.category,
    required this.minStage,
    required this.maxStage,
    required this.isPublished,
    required this.onCategoryChanged,
    required this.onMinStageChanged,
    required this.onMaxStageChanged,
    required this.onPublishedChanged,
    required this.onSubmit,
  });

  final TextEditingController idController;
  final TextEditingController titleController;
  final TextEditingController descriptionController;
  final TextEditingController orderController;
  final ModuleCategory category;
  final int minStage;
  final int maxStage;
  final bool isPublished;
  final ValueChanged<ModuleCategory> onCategoryChanged;
  final ValueChanged<int> onMinStageChanged;
  final ValueChanged<int> onMaxStageChanged;
  final ValueChanged<bool> onPublishedChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _FormTitle(title: 'Create module'),
            _TextField(controller: idController, label: 'Module ID'),
            _TextField(controller: titleController, label: 'Title'),
            _TextField(controller: descriptionController, label: 'Description'),
            _TextField(
              controller: orderController,
              label: 'Sort order',
              keyboardType: TextInputType.number,
            ),
            _EnumDropdown<ModuleCategory>(
              label: 'Category',
              value: category,
              values: ModuleCategory.values,
              onChanged: onCategoryChanged,
            ),
            _IntDropdown(
              label: 'Min stage',
              value: minStage,
              values: const [1, 2, 3, 4],
              onChanged: onMinStageChanged,
            ),
            _IntDropdown(
              label: 'Max stage',
              value: maxStage,
              values: const [1, 2, 3, 4],
              onChanged: onMaxStageChanged,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Published'),
              value: isPublished,
              onChanged: onPublishedChanged,
            ),
            AppPrimaryButton(
              icon: Icons.add,
              label: 'Save module',
              onPressed: onSubmit,
            ),
          ],
        ),
      ),
    );
  }
}

class _LevelForm extends StatelessWidget {
  const _LevelForm({
    required this.modules,
    required this.selectedModuleId,
    required this.idController,
    required this.titleController,
    required this.subtitleController,
    required this.levelNumberController,
    required this.passingScoreController,
    required this.contentTitleController,
    required this.contentPromptController,
    required this.contentDisplayController,
    required this.contentVisualController,
    required this.quizPromptController,
    required this.quizOptionsController,
    required this.quizCorrectIndexController,
    required this.videoTitleController,
    required this.videoUrlController,
    required this.stage,
    required this.type,
    required this.isPublished,
    required this.onModuleChanged,
    required this.onStageChanged,
    required this.onTypeChanged,
    required this.onPublishedChanged,
    required this.onSubmit,
  });

  final List<AdminContentModule> modules;
  final String? selectedModuleId;
  final TextEditingController idController;
  final TextEditingController titleController;
  final TextEditingController subtitleController;
  final TextEditingController levelNumberController;
  final TextEditingController passingScoreController;
  final TextEditingController contentTitleController;
  final TextEditingController contentPromptController;
  final TextEditingController contentDisplayController;
  final TextEditingController contentVisualController;
  final TextEditingController quizPromptController;
  final TextEditingController quizOptionsController;
  final TextEditingController quizCorrectIndexController;
  final TextEditingController videoTitleController;
  final TextEditingController videoUrlController;
  final int stage;
  final LevelType type;
  final bool isPublished;
  final ValueChanged<String?> onModuleChanged;
  final ValueChanged<int> onStageChanged;
  final ValueChanged<LevelType> onTypeChanged;
  final ValueChanged<bool> onPublishedChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _FormTitle(title: 'Create level'),
            DropdownButtonFormField<String>(
              initialValue: selectedModuleId,
              decoration: const InputDecoration(labelText: 'Module'),
              items: [
                for (final module in modules)
                  DropdownMenuItem(
                    value: module.module.id,
                    child: Text(module.module.title),
                  ),
              ],
              onChanged: onModuleChanged,
            ),
            _TextField(controller: idController, label: 'Level ID'),
            _TextField(controller: titleController, label: 'Title'),
            _TextField(controller: subtitleController, label: 'Subtitle'),
            _TextField(
              controller: levelNumberController,
              label: 'Level number',
              keyboardType: TextInputType.number,
            ),
            _TextField(
              controller: passingScoreController,
              label: 'Passing score',
              keyboardType: TextInputType.number,
            ),
            _IntDropdown(
              label: 'Stage',
              value: stage,
              values: const [1, 2, 3, 4],
              onChanged: onStageChanged,
            ),
            _EnumDropdown<LevelType>(
              label: 'Level type',
              value: type,
              values: LevelType.values,
              onChanged: onTypeChanged,
            ),
            const SizedBox(height: 8),
            const _FormTitle(title: 'Activity card'),
            _TextField(controller: contentTitleController, label: 'Card title'),
            _TextField(controller: contentPromptController, label: 'Prompt'),
            _TextField(
              controller: contentDisplayController,
              label: 'Display text',
            ),
            _TextField(controller: contentVisualController, label: 'Visual'),
            const SizedBox(height: 8),
            const _FormTitle(title: 'Quiz'),
            _TextField(controller: quizPromptController, label: 'Question'),
            _TextField(
              controller: quizOptionsController,
              label: 'Options comma separated',
            ),
            _TextField(
              controller: quizCorrectIndexController,
              label: 'Correct option index',
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 8),
            const _FormTitle(title: 'Video'),
            _TextField(controller: videoTitleController, label: 'Video title'),
            _TextField(controller: videoUrlController, label: 'Video URL'),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Published'),
              value: isPublished,
              onChanged: onPublishedChanged,
            ),
            AppPrimaryButton(
              icon: Icons.add,
              label: 'Save level',
              onPressed: modules.isEmpty ? null : onSubmit,
            ),
          ],
        ),
      ),
    );
  }
}

class _FormTitle extends StatelessWidget {
  const _FormTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
            ),
      ),
    );
  }
}

class _TextField extends StatelessWidget {
  const _TextField({
    required this.controller,
    required this.label,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}

class _EnumDropdown<T extends Enum> extends StatelessWidget {
  const _EnumDropdown({
    required this.label,
    required this.value,
    required this.values,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<T> values;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DropdownButtonFormField<T>(
        initialValue: value,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        items: [
          for (final item in values)
            DropdownMenuItem(value: item, child: Text(item.name)),
        ],
        onChanged: (value) {
          if (value != null) onChanged(value);
        },
      ),
    );
  }
}

class _IntDropdown extends StatelessWidget {
  const _IntDropdown({
    required this.label,
    required this.value,
    required this.values,
    required this.onChanged,
  });

  final String label;
  final int value;
  final List<int> values;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DropdownButtonFormField<int>(
        initialValue: value,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        items: [
          for (final item in values)
            DropdownMenuItem(value: item, child: Text(item.toString())),
        ],
        onChanged: (value) {
          if (value != null) onChanged(value);
        },
      ),
    );
  }
}
