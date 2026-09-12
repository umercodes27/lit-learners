import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/routing/route_names.dart';
import '../../core/utils/module_visuals.dart';
import '../../models/admin_content.dart';
import '../../models/koala_guide_message.dart';
import '../../viewmodels/admin_auth_viewmodel.dart';
import '../../viewmodels/admin_content_viewmodel.dart';
import '../../viewmodels/ai_content_viewmodel.dart';
import '../../widgets/koala_guide.dart';
import 'admin_level_editor_page.dart';
import 'admin_module_editor_page.dart';
import 'widgets/admin_form_fields.dart';
import 'widgets/admin_scaffold.dart';

class AdminContentPage extends StatefulWidget {
  const AdminContentPage({super.key});

  @override
  State<AdminContentPage> createState() => _AdminContentPageState();
}

class _AdminContentPageState extends State<AdminContentPage> {
  var _didRequestLoad = false;

  /// Which module is being looked at. Null means none picked, and the page
  /// shows the modules rather than every level in the app at once.
  String? _browseModuleId;

  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
  }

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
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AdminContentViewModel>();
    final modules = admin.modules;

    return AdminScaffold(
      title: 'Manage Content',
      subtitle: 'Modules, levels and quizzes',
      actions: [
        AdminHeaderAction(
          tooltip: 'Generate levels with AI',
          icon: Icons.auto_awesome_rounded,
          onPressed: () {
            context.read<AiContentViewModel>().cancelRevision();
            Navigator.of(context).pushNamed(RouteNames.adminAiAuthoring);
          },
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
          if (admin.isLoading && modules.isEmpty)
            const Center(child: CircularProgressIndicator())
          else ...[
            _AdminStatus(admin: admin),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  onPressed: () => _openModuleEditor(context),
                  icon: const Icon(Icons.add_box_rounded),
                  label: const Text('New module'),
                ),
                FilledButton.tonalIcon(
                  onPressed: modules.isEmpty
                      ? null
                      : () => _openLevelEditor(
                            context,
                            moduleId: _browseModuleId,
                          ),
                  icon: const Icon(Icons.add_location_alt_rounded),
                  label: Text(_browseModuleId == null
                      ? 'New level'
                      : 'New level in '
                          '${admin.moduleById(_browseModuleId!)?.module.title ?? 'module'}'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            AdminTextField(
              controller: _searchController,
              label: 'Search modules and levels',
            ),
            _ModuleBrowser(
              modules: modules,
              levels: admin.levels,
              selectedModuleId: _browseModuleId,
              query: _searchController.text,
              originOf: admin.moduleOrigin,
              onSelect: (moduleId) => setState(
                () => _browseModuleId =
                    _browseModuleId == moduleId ? null : moduleId,
              ),
            ),
            const SizedBox(height: 12),
            if (_browseModuleId != null) ...[
              _ModuleList(
                modules: [
                  for (final module in modules)
                    if (module.module.id == _browseModuleId) module,
                ],
                onEdit: (module) =>
                    _openModuleEditor(context, existing: module),
                onDelete: (module) => _confirmDelete(
                  context,
                  title: module.module.title,
                  onConfirmed: () => context
                      .read<AdminContentViewModel>()
                      .deleteModule(module.module.id),
                ),
              ),
              const SizedBox(height: 12),
            ],
            _LevelList(
              levels: _visibleLevels(admin.levels),
              subtitle: _levelListSubtitle(admin.levels),
              onEdit: (level) => _openLevelEditor(context, existing: level),
              onRewrite: (level) {
                context.read<AiContentViewModel>().startRevision(level.level);
                Navigator.of(context).pushNamed(RouteNames.adminAiAuthoring);
              },
              onDelete: (level) => _confirmDelete(
                context,
                title: level.level.title,
                onConfirmed: () => context
                    .read<AdminContentViewModel>()
                    .deleteLevel(level.level.id),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _openModuleEditor(
    BuildContext context, {
    AdminContentModule? existing,
  }) async {
    context.read<AdminContentViewModel>().clearMessages();
    await Navigator.of(context)
        .push(AdminModuleEditorPage.route(existing: existing));
  }

  Future<void> _openLevelEditor(
    BuildContext context, {
    AdminContentLevel? existing,
    String? moduleId,
  }) async {
    context.read<AdminContentViewModel>().clearMessages();
    await Navigator.of(context).push(
      AdminLevelEditorPage.route(existing: existing, moduleId: moduleId),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context, {
    required String title,
    required VoidCallback onConfirmed,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete "$title"?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep it'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.coral),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) onConfirmed();
  }

  /// Levels for the module being looked at, narrowed further by the search.
  ///
  /// Nothing is listed until a module is picked or something is searched for.
  /// Ten modules with twenty levels each is two hundred rows, which is the
  /// problem this page had.
  List<AdminContentLevel> _visibleLevels(List<AdminContentLevel> levels) {
    final query = _searchController.text.trim().toLowerCase();
    final moduleId = _browseModuleId;

    if (moduleId == null && query.isEmpty) return const [];

    return [
      for (final level in levels)
        if (moduleId == null || level.level.moduleId == moduleId)
          if (query.isEmpty || _matchesLevel(level, query)) level,
    ];
  }

  bool _matchesLevel(AdminContentLevel level, String query) {
    return level.level.title.toLowerCase().contains(query) ||
        level.level.id.toLowerCase().contains(query) ||
        level.level.subtitle.toLowerCase().contains(query);
  }

  String _levelListSubtitle(List<AdminContentLevel> levels) {
    final query = _searchController.text.trim();
    final moduleId = _browseModuleId;

    if (moduleId == null && query.isEmpty) {
      return 'Pick a module above, or search, to see its levels.';
    }

    final shown = _visibleLevels(levels).length;
    if (query.isNotEmpty) {
      return '$shown ${shown == 1 ? 'level matches' : 'levels match'} '
          '"$query"${moduleId == null ? '' : ' in this module'}.';
    }
    return '$shown ${shown == 1 ? 'level' : 'levels'} in this module.';
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
          ? AdminInlineError(
              message: admin.errorMessage!,
              onDismiss: admin.clearMessages,
            )
          : AdminInlineSuccess(
              message: admin.infoMessage!,
              onDismiss: admin.clearMessages,
            ),
    );
  }
}

class _ModuleList extends StatelessWidget {
  const _ModuleList({
    required this.modules,
    required this.onEdit,
    required this.onDelete,
  });

  final List<AdminContentModule> modules;
  final ValueChanged<AdminContentModule> onEdit;
  final ValueChanged<AdminContentModule> onDelete;

  @override
  Widget build(BuildContext context) {
    final vm = context.read<AdminContentViewModel>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AdminSectionHeading(title: 'Module'),
        const SizedBox(height: 10),
        for (final module in modules)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _ContentRow(
              icon: Icons.widgets_rounded,
              accent: AppColors.sky,
              title: module.module.title,
              pills: [
                _OriginPill(origin: vm.moduleOrigin(module.module.id)),
                _StatusPill(status: module.publishStatus),
                AdminPill(label: module.module.id, accent: AppColors.violet),
                AdminPill(
                  label: 'Stages ${module.module.minStage}'
                      '-${module.module.maxStage}',
                  accent: AppColors.aqua,
                ),
              ],
              actions: _RowActions(
                origin: vm.moduleOrigin(module.module.id),
                isPublished: module.isPublished,
                publishStatus: module.publishStatus,
                onEdit: () => onEdit(module),
                onPublishedChanged: (value) =>
                    vm.toggleModulePublished(module, value),
                onSubmitReview: () => vm.submitModuleForReview(module),
                onMoveDraft: () => vm.moveModuleToDraft(module),
                onRestore: () => vm.restoreBuiltInModule(module.module.id),
                onDelete: () => onDelete(module),
              ),
            ),
          ),
      ],
    );
  }
}

class _LevelList extends StatelessWidget {
  const _LevelList({
    required this.levels,
    required this.onEdit,
    required this.onRewrite,
    required this.onDelete,
    this.subtitle,
  });

  final List<AdminContentLevel> levels;
  final String? subtitle;
  final ValueChanged<AdminContentLevel> onEdit;
  final ValueChanged<AdminContentLevel> onRewrite;
  final ValueChanged<AdminContentLevel> onDelete;

  @override
  Widget build(BuildContext context) {
    if (levels.isEmpty) {
      return AdminEmptyState(
        icon: Icons.map_rounded,
        title: 'Nothing to show',
        message: subtitle ??
            'Levels belong to a module. Create one above to get started.',
      );
    }

    final vm = context.read<AdminContentViewModel>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdminSectionHeading(title: 'Levels', subtitle: subtitle),
        const SizedBox(height: 10),
        for (final level in levels)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _ContentRow(
              icon: Icons.map_rounded,
              accent: AppColors.leaf,
              title: level.level.title,
              pills: [
                _OriginPill(origin: vm.levelOrigin(level.level.id)),
                _StatusPill(status: level.publishStatus),
                AdminPill(
                  label: 'Stage ${level.level.stage} · '
                      'level ${level.level.levelNumber}',
                  accent: AppColors.aqua,
                ),
                AdminPill(
                  label: level.level.type.name,
                  accent: AppColors.violet,
                ),
                if (level.level.contentItems.isNotEmpty)
                  AdminPill(
                    label: '${level.level.contentItems.length} '
                        '${level.level.contentItems.length == 1 ? 'card' : 'cards'}',
                    accent: AppColors.plum,
                  ),
              ],
              actions: _RowActions(
                origin: vm.levelOrigin(level.level.id),
                isPublished: level.isPublished,
                publishStatus: level.publishStatus,
                onEdit: () => onEdit(level),
                onRewrite: () => onRewrite(level),
                onPublishedChanged: (value) =>
                    vm.toggleLevelPublished(level, value),
                onSubmitReview: () => vm.submitLevelForReview(level),
                onMoveDraft: () => vm.moveLevelToDraft(level),
                onRestore: () => vm.restoreBuiltInLevel(level.level.id),
                onDelete: () => onDelete(level),
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

/// Built-in, edited, or made by an admin — which decides what can be done
/// with it, so it is the first thing a row says.
class _OriginPill extends StatelessWidget {
  const _OriginPill({required this.origin});

  final ContentOrigin origin;

  @override
  Widget build(BuildContext context) {
    final (icon, label, accent) = switch (origin) {
      ContentOrigin.builtIn => (
          Icons.inventory_2_rounded,
          'Built-in',
          AppColors.honey,
        ),
      ContentOrigin.builtInEdited => (
          Icons.edit_rounded,
          'Built-in · edited',
          AppColors.plum,
        ),
      ContentOrigin.custom => (
          Icons.person_rounded,
          'Custom',
          AppColors.sky,
        ),
    };
    return AdminPill(icon: icon, label: label, accent: accent);
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

/// What can be done with a row depends on where it came from.
///
/// A built-in item is always live and cannot be deleted, so it offers only
/// Edit (and, for levels, a rewrite). Once edited it gains Restore, which
/// puts the original back. Only custom items can be deleted.
class _RowActions extends StatelessWidget {
  const _RowActions({
    required this.origin,
    required this.isPublished,
    required this.publishStatus,
    required this.onEdit,
    required this.onPublishedChanged,
    required this.onSubmitReview,
    required this.onMoveDraft,
    required this.onRestore,
    required this.onDelete,
    this.onRewrite,
  });

  final ContentOrigin origin;
  final bool isPublished;
  final AdminPublishStatus publishStatus;
  final VoidCallback onEdit;
  final VoidCallback? onRewrite;
  final ValueChanged<bool> onPublishedChanged;
  final VoidCallback onSubmitReview;
  final VoidCallback onMoveDraft;
  final VoidCallback onRestore;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final editable = origin != ContentOrigin.builtIn;

    return Wrap(
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (editable)
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
          tooltip: 'Edit',
          color: AppColors.sky,
          onPressed: onEdit,
          icon: const Icon(Icons.edit_rounded),
        ),
        if (onRewrite != null)
          IconButton(
            tooltip: 'Rewrite with AI',
            color: AppColors.violet,
            onPressed: onRewrite,
            icon: const Icon(Icons.auto_awesome_rounded),
          ),
        if (editable) ...[
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
        ],
        if (origin == ContentOrigin.builtInEdited)
          IconButton(
            tooltip: 'Restore the original',
            color: AppColors.plum,
            onPressed: onRestore,
            icon: const Icon(Icons.restore_rounded),
          ),
        if (origin == ContentOrigin.custom)
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

/// The modules, as something to navigate rather than something to scroll.
///
/// Every module is always shown — it is how the page is steered, so hiding
/// one behind a search would take the steering away. What the search changes
/// is the count on each card: type part of a level name and you can see at a
/// glance which module holds it, without opening any of them.
class _ModuleBrowser extends StatelessWidget {
  const _ModuleBrowser({
    required this.modules,
    required this.levels,
    required this.selectedModuleId,
    required this.query,
    required this.originOf,
    required this.onSelect,
  });

  final List<AdminContentModule> modules;
  final List<AdminContentLevel> levels;
  final String? selectedModuleId;
  final String query;
  final ContentOrigin Function(String moduleId) originOf;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    if (modules.isEmpty) {
      return const AdminEmptyState(
        icon: Icons.widgets_rounded,
        title: 'No modules yet',
        message: 'Press New module and its levels will live inside it.',
      );
    }

    final needle = query.trim().toLowerCase();
    final searching = needle.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdminSectionHeading(
          title: 'Modules',
          subtitle: searching
              ? 'Showing how many levels in each match "${query.trim()}".'
              : 'Tap one to see and edit its levels.',
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final module in modules)
              _ModuleCard(
                module: module,
                origin: originOf(module.module.id),
                levelCount: _levelsIn(module).length,
                publishedCount:
                    _levelsIn(module).where((l) => l.isPublished).length,
                matchCount: searching ? _matchesIn(module, needle) : null,
                isSelected: module.module.id == selectedModuleId,
                onTap: () => onSelect(module.module.id),
              ),
          ],
        ),
      ],
    );
  }

  List<AdminContentLevel> _levelsIn(AdminContentModule module) => [
        for (final level in levels)
          if (level.level.moduleId == module.module.id) level,
      ];

  int _matchesIn(AdminContentModule module, String needle) {
    return _levelsIn(module).where((level) {
      return level.level.title.toLowerCase().contains(needle) ||
          level.level.id.toLowerCase().contains(needle) ||
          level.level.subtitle.toLowerCase().contains(needle);
    }).length;
  }
}

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({
    required this.module,
    required this.origin,
    required this.levelCount,
    required this.publishedCount,
    required this.matchCount,
    required this.isSelected,
    required this.onTap,
  });

  final AdminContentModule module;
  final ContentOrigin origin;
  final int levelCount;
  final int publishedCount;

  /// Null when nothing is being searched for.
  final int? matchCount;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = ModuleVisuals.colorForModuleId(module.module.id);
    final theme = Theme.of(context);
    // Dimmed only while searching, and only when this module holds nothing
    // that matches — so it stays visible and still selectable.
    final faded = matchCount == 0;

    return SizedBox(
      width: 168,
      child: Opacity(
        opacity: faded ? 0.5 : 1,
        child: AdminSoftCard(
          onTap: onTap,
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  AdminIconChip(
                    icon: ModuleVisuals.iconFor(module.module.category),
                    color: accent,
                    size: 34,
                  ),
                  const Spacer(),
                  if (isSelected)
                    Icon(Icons.check_circle_rounded, size: 20, color: accent),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                module.module.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
              Text(
                switch (origin) {
                  ContentOrigin.builtIn => 'Built-in · ${module.module.id}',
                  ContentOrigin.builtInEdited =>
                    'Edited · ${module.module.id}',
                  ContentOrigin.custom => 'Custom · ${module.module.id}',
                },
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall,
              ),
              const SizedBox(height: 2),
              Text(
                matchCount != null
                    ? '$matchCount of $levelCount match'
                    : '$levelCount ${levelCount == 1 ? 'level' : 'levels'}',
                style: theme.textTheme.labelSmall,
              ),
              const SizedBox(height: 8),
              AdminProgressBar(
                value: levelCount == 0 ? 0 : publishedCount / levelCount,
                color: accent,
                minHeight: 6,
              ),
              const SizedBox(height: 5),
              Row(
                children: [
                  _StatusPill(status: module.publishStatus),
                  const Spacer(),
                  Text(
                    '$publishedCount live',
                    style: theme.textTheme.labelSmall,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
