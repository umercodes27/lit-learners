import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/routing/route_names.dart';
import '../../models/admin_content.dart';
import '../../models/koala_guide_message.dart';
import '../../models/learning_level.dart';
import '../../models/learning_module.dart';
import '../../viewmodels/admin_auth_viewmodel.dart';
import '../../viewmodels/admin_content_viewmodel.dart';
import '../../widgets/app_primary_button.dart';
import '../../widgets/koala_guide.dart';
import 'widgets/admin_form_fields.dart';
import 'widgets/admin_scaffold.dart';

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
    final isAdmin = context.watch<AdminAuthViewModel>().isAuthenticated;
    if (isAdmin && !_didRequestLoad) {
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
    final admin = context.watch<AdminContentViewModel>();
    final modules = admin.modules;
    _selectedModuleId ??= modules.isEmpty ? null : modules.first.module.id;

    return AdminScaffold(
      title: 'Manage Content',
      subtitle: 'Modules, levels and quizzes',
      actions: [
        AdminHeaderAction(
          tooltip: 'Generate levels with AI',
          icon: Icons.auto_awesome_rounded,
          onPressed: () =>
              Navigator.of(context).pushNamed(RouteNames.adminAiAuthoring),
        ),
        const SizedBox(width: 4),
        AdminHeaderAction(
          tooltip: 'Media library',
          icon: Icons.perm_media_rounded,
          onPressed: () =>
              Navigator.of(context).pushNamed(RouteNames.adminMedia),
        ),
        const SizedBox(width: 4),
        AdminHeaderAction(
          tooltip: 'Refresh content',
          icon: Icons.refresh,
          onPressed: admin.isLoading
              ? null
              : () => context.read<AdminContentViewModel>().loadContent(),
        ),
      ],
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const ContextualKoalaGuide(
            trigger: KoalaGuideTrigger.adminContent,
            audience: KoalaGuideAudience.parent,
            fallbackMessage: 'Manage draft and published content for learners.',
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

class _AdminStatus extends StatelessWidget {
  const _AdminStatus({required this.admin});

  final AdminContentViewModel admin;

  @override
  Widget build(BuildContext context) {
    if (admin.errorMessage == null && admin.infoMessage == null) {
      return const SizedBox.shrink();
    }

    // Was a bare coloured sentence, which read as body copy rather than as a
    // result. Same washed banners the rest of the panel uses.
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: admin.errorMessage != null
          ? AdminInlineError(message: admin.errorMessage!)
          : AdminInlineSuccess(message: admin.infoMessage!),
    );
  }
}

class _ModuleList extends StatelessWidget {
  const _ModuleList({required this.modules});

  final List<AdminContentModule> modules;

  @override
  Widget build(BuildContext context) {
    if (modules.isEmpty) {
      return const AdminEmptyState(
        icon: Icons.widgets_rounded,
        title: 'No modules yet',
        message: 'Use the "Create module" form below to add the first one.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AdminSectionHeading(title: 'Modules'),
        const SizedBox(height: 10),
        for (final module in modules)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _ContentRow(
              icon: Icons.widgets_rounded,
              accent: AppColors.sky,
              title: module.module.title,
              pills: [
                _StatusPill(status: module.publishStatus),
                AdminPill(
                  label: module.module.category.name,
                  accent: AppColors.violet,
                ),
                AdminPill(
                  label: 'Stages ${module.module.minStage}'
                      '-${module.module.maxStage}',
                  accent: AppColors.aqua,
                ),
                AdminPill(
                  label: 'v${module.version}',
                  accent: AppColors.plum,
                ),
              ],
              actions: _AdminActions(
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
      return const AdminEmptyState(
        icon: Icons.map_rounded,
        title: 'No levels yet',
        message: 'Levels belong to a module. Create one below to get started.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AdminSectionHeading(title: 'Levels'),
        const SizedBox(height: 10),
        for (final level in levels)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _ContentRow(
              icon: Icons.map_rounded,
              accent: AppColors.leaf,
              title: level.level.title,
              pills: [
                _StatusPill(status: level.publishStatus),
                AdminPill(
                  icon: Icons.auto_stories_rounded,
                  label: level.level.moduleId,
                  accent: AppColors.sky,
                ),
                AdminPill(
                  label: 'Stage ${level.level.stage}',
                  accent: AppColors.aqua,
                ),
                AdminPill(
                  label: level.level.type.name,
                  accent: AppColors.violet,
                ),
                AdminPill(
                  label: 'v${level.version}',
                  accent: AppColors.plum,
                ),
              ],
              actions: _AdminActions(
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
                  context.read<AdminContentViewModel>().moveLevelToDraft(level);
                },
                onDelete: () {
                  context
                      .read<AdminContentViewModel>()
                      .deleteLevel(level.level.id);
                },
              ),
            ),
          ),
      ],
    );
  }
}

/// A module or level row.
///
/// The old `ListTile` crammed four facts into one grey subtitle line and hung
/// four controls off the trailing edge, which overflowed as soon as a title
/// was long. Facts are pills now, and the controls sit on their own row.
class _ContentRow extends StatelessWidget {
  const _ContentRow({
    required this.icon,
    required this.accent,
    required this.title,
    required this.pills,
    required this.actions,
  });

  final IconData icon;
  final Color accent;
  final String title;
  final List<Widget> pills;
  final Widget actions;

  @override
  Widget build(BuildContext context) {
    return AdminSoftCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AdminIconChip(icon: icon, color: accent, size: 38),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 6),
                    Wrap(spacing: 6, runSpacing: 6, children: pills),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Align(alignment: Alignment.centerRight, child: actions),
        ],
      ),
    );
  }
}

/// Draft / in review / published, colour-coded so the workflow state is
/// readable at a glance.
class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final AdminPublishStatus status;

  @override
  Widget build(BuildContext context) {
    final (icon, accent) = switch (status) {
      AdminPublishStatus.draft => (
          Icons.edit_note_rounded,
          AppColors.ink,
        ),
      AdminPublishStatus.inReview => (
          Icons.rate_review_rounded,
          AppColors.honey,
        ),
      AdminPublishStatus.published => (
          Icons.check_circle_rounded,
          AppColors.leaf,
        ),
    };

    return AdminPill(
      icon: icon,
      label: _statusLabel(status),
      accent: accent,
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
        Tooltip(
          message: isPublished ? 'Unpublish' : 'Publish',
          child: Switch(
            value: isPublished,
            activeThumbColor: Colors.white,
            activeTrackColor: AppColors.leaf,
            onChanged: onPublishedChanged,
          ),
        ),
        IconButton(
          tooltip: 'Submit for review',
          color: AppColors.honey,
          onPressed: publishStatus == AdminPublishStatus.inReview
              ? null
              : onSubmitReview,
          icon: const Icon(Icons.rate_review_rounded),
        ),
        IconButton(
          tooltip: 'Move to draft',
          color: AppColors.violet,
          onPressed:
              publishStatus == AdminPublishStatus.draft ? null : onMoveDraft,
          icon: const Icon(Icons.edit_note_rounded),
        ),
        IconButton(
          tooltip: 'Delete',
          color: AppColors.coral,
          onPressed: onDelete,
          icon: const Icon(Icons.delete_outline_rounded),
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
    return AdminSoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _FormTitle(
            title: 'Create module',
            icon: Icons.add_box_rounded,
            accent: AppColors.sky,
          ),
          AdminTextField(controller: idController, label: 'Module ID'),
          AdminTextField(controller: titleController, label: 'Title'),
          AdminTextField(controller: descriptionController, label: 'Description'),
          AdminTextField(
            controller: orderController,
            label: 'Sort order',
            keyboardType: TextInputType.number,
          ),
          AdminEnumDropdown<ModuleCategory>(
            label: 'Category',
            value: category,
            values: ModuleCategory.values,
            onChanged: onCategoryChanged,
          ),
          AdminIntDropdown(
            label: 'Min stage',
            value: minStage,
            values: const [1, 2, 3, 4],
            onChanged: onMinStageChanged,
          ),
          AdminIntDropdown(
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
    return AdminSoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _FormTitle(
            title: 'Create level',
            icon: Icons.add_location_alt_rounded,
            accent: AppColors.leaf,
          ),
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
          AdminTextField(controller: idController, label: 'Level ID'),
          AdminTextField(controller: titleController, label: 'Title'),
          AdminTextField(controller: subtitleController, label: 'Subtitle'),
          AdminTextField(
            controller: levelNumberController,
            label: 'Level number',
            keyboardType: TextInputType.number,
          ),
          AdminTextField(
            controller: passingScoreController,
            label: 'Passing score',
            keyboardType: TextInputType.number,
          ),
          AdminIntDropdown(
            label: 'Stage',
            value: stage,
            values: const [1, 2, 3, 4],
            onChanged: onStageChanged,
          ),
          AdminEnumDropdown<LevelType>(
            label: 'Level type',
            value: type,
            values: LevelType.values,
            onChanged: onTypeChanged,
          ),
          const SizedBox(height: 8),
          const _FormTitle(title: 'Activity card'),
          AdminTextField(controller: contentTitleController, label: 'Card title'),
          AdminTextField(controller: contentPromptController, label: 'Prompt'),
          AdminTextField(
            controller: contentDisplayController,
            label: 'Display text',
            helperText: type == LevelType.tracing
                ? 'Tracing draws and grades this exactly. Enter the single '
                    'letter or digit to trace, such as A or ا or 5.'
                : null,
          ),
          AdminTextField(controller: contentVisualController, label: 'Visual'),
          const SizedBox(height: 8),
          const _FormTitle(title: 'Quiz'),
          AdminTextField(controller: quizPromptController, label: 'Question'),
          AdminTextField(
            controller: quizOptionsController,
            label: 'Options comma separated',
          ),
          AdminTextField(
            controller: quizCorrectIndexController,
            label: 'Correct option index',
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 8),
          const _FormTitle(title: 'Video'),
          AdminTextField(controller: videoTitleController, label: 'Video title'),
          AdminTextField(controller: videoUrlController, label: 'Video URL'),
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
    );
  }
}

class _FormTitle extends StatelessWidget {
  const _FormTitle({required this.title, this.icon, this.accent});

  final String title;

  /// Set for the title of a whole form card. Left off for the sub-headings
  /// that group fields inside one, where a chip per group would be noise.
  final IconData? icon;

  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final label = Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w900,
          ),
    );

    if (icon == null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: label,
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          AdminIconChip(
            icon: icon!,
            color: accent ?? AppColors.violet,
            size: 38,
          ),
          const SizedBox(width: 10),
          Expanded(child: label),
        ],
      ),
    );
  }
}
