import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../models/learning_level.dart';
import '../../../models/learning_module.dart';
import '../../../viewmodels/ai_content_viewmodel.dart';
import '../../../widgets/app_primary_button.dart';
import 'admin_form_fields.dart';
import 'admin_theme.dart';

/// What to generate: a module, a stage, how many levels and of what kind.
class AiRequestCard extends StatefulWidget {
  const AiRequestCard({
    super.key,
    required this.viewModel,
    required this.modules,
    required this.existingLevels,
    required this.onGenerate,
  });

  final AiContentViewModel viewModel;
  final List<LearningModule> modules;
  final List<LearningLevel> existingLevels;
  final VoidCallback onGenerate;

  @override
  State<AiRequestCard> createState() => _AiRequestCardState();
}

class _AiRequestCardState extends State<AiRequestCard> {
  final _guidance = TextEditingController();

  @override
  void dispose() {
    _guidance.dispose();
    super.dispose();
  }

  int get _levelsInStage => widget.existingLevels
      .where((level) =>
          level.moduleId == widget.viewModel.moduleId &&
          level.stage == widget.viewModel.stage)
      .length;

  @override
  Widget build(BuildContext context) {
    final vm = widget.viewModel;
    final ready = vm.moduleId != null && vm.hasKey && !vm.isBusy;

    return AdminSoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdminSectionHeading(
            title: vm.revising == null ? 'Generate a stage' : 'Rewrite a level',
            subtitle: vm.revising == null
                ? 'Levels arrive as drafts for you to check'
                : 'The new version arrives as a draft for you to check',
          ),
          const SizedBox(height: 12),
          if (vm.revising == null) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: DropdownButtonFormField<String>(
              initialValue: vm.moduleId,
              decoration: const InputDecoration(
                labelText: 'Module',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final module in widget.modules)
                  DropdownMenuItem(
                    value: module.id,
                    child: Text('${module.title} (${module.id})'),
                  ),
              ],
              onChanged: vm.isBusy
                  ? null
                  : (id) {
                      vm.selectModule(id, modules: widget.modules);
                      vm.refreshPreview(widget.existingLevels);
                    },
            ),
          ),
          Row(
            children: [
              Expanded(
                child: AdminIntDropdown(
                  label: 'Stage',
                  value: vm.stage,
                  values: vm.stagesFor(widget.modules),
                  onChanged: (stage) {
                    vm.setStage(stage);
                    vm.refreshPreview(widget.existingLevels);
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AdminIntDropdown(
                  label: 'How many',
                  value: vm.levelCount,
                  values: [
                    for (var n = 1;
                        n <= AiContentViewModel.maxLevelCount;
                        n++)
                      n,
                  ],
                  onChanged: vm.setLevelCount,
                ),
              ),
            ],
          ),
          AdminEnumDropdown<LevelType>(
            label: 'Level type',
            value: vm.type,
            values: LevelType.values,
            onChanged: vm.setType,
          ),
          ],
          AdminTextField(
            controller: _guidance,
            label: vm.revising == null
                ? 'Anything else? (optional)'
                : 'What should change?',
            helperText: vm.revising == null
                ? 'For example: use animals rather than fruit.'
                : 'For example: easier words, more cards, or animals instead '
                    'of fruit.',
            maxLines: 2,
          ),
          // Shown before anything is generated, because the numbering is the
          // one thing that cannot be fixed afterwards: a gap locks the rest
          // of the module permanently.
          if (vm.moduleId != null && vm.revising == null)
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 12),
              child: Row(
                children: [
                  const Icon(Icons.stairs_rounded,
                      size: 16, color: AppColors.violet),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Will create ${vm.levelCount == 1 ? 'level' : 'levels'} '
                      '${vm.firstLevelNumber}'
                      '${vm.levelCount == 1 ? '' : ' to ${vm.lastLevelNumber}'}. '
                      'Stage ${vm.stage} currently has $_levelsInStage '
                      '${_levelsInStage == 1 ? 'level' : 'levels'}.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          AppPrimaryButton(
            label: vm.isGenerating
                ? 'Generating${vm.attempts > 1 ? ' (try ${vm.attempts})' : ''}…'
                : (vm.revising == null ? 'Generate' : 'Rewrite'),
            icon: Icons.auto_awesome_rounded,
            onPressed: ready
                ? () {
                    vm.setGuidance(_guidance.text);
                    widget.onGenerate();
                  }
                : null,
          ),
          if (!vm.hasKey)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Add an API key above first.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }
}
