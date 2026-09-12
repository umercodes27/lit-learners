import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/age_stage_helper.dart';
import '../../models/admin_content.dart';
import '../../models/learning_module.dart';
import '../../viewmodels/admin_content_viewmodel.dart';
import '../../widgets/app_primary_button.dart';
import 'widgets/admin_form_fields.dart';
import 'widgets/admin_scaffold.dart';

/// Creates a module, or edits one that exists — built-in or custom.
///
/// One screen for both, with one difference that matters: when editing, the
/// ID is shown but cannot be changed. The ID is what levels and children's
/// progress point at, and it is what the old "Replace existing" switch let an
/// admin collide with by accident.
class AdminModuleEditorPage extends StatefulWidget {
  const AdminModuleEditorPage({super.key, this.existing});

  /// Null when creating.
  final AdminContentModule? existing;

  /// Named under `/admin` so signing out of the admin panel closes it along
  /// with every other admin screen.
  static Route<bool> route({AdminContentModule? existing}) =>
      MaterialPageRoute<bool>(
        settings: const RouteSettings(name: '/admin/content/module'),
        builder: (_) => AdminModuleEditorPage(existing: existing),
      );

  @override
  State<AdminModuleEditorPage> createState() => _AdminModuleEditorPageState();
}

class _AdminModuleEditorPageState extends State<AdminModuleEditorPage> {
  late final TextEditingController _id;
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _order;
  late ModuleCategory _category;
  late int _minStage;
  late int _maxStage;
  late bool _published;
  var _saving = false;

  bool get _editing => widget.existing != null;

  static final _stages = [
    for (var stage = AgeStageHelper.minStage; stage <= 4; stage++) stage,
  ];

  @override
  void initState() {
    super.initState();
    final module = widget.existing?.module;
    _id = TextEditingController(text: module?.id ?? '');
    _title = TextEditingController(text: module?.title ?? '');
    _description = TextEditingController(text: module?.description ?? '');
    _order = TextEditingController(text: '${module?.order ?? 20}');
    _category = module?.category ?? ModuleCategory.english;
    // Clamped: a module saved before age 1 was dropped can still say stage 1,
    // and a dropdown whose value is not one of its items throws.
    _minStage = (module?.minStage ?? AgeStageHelper.minStage)
        .clamp(AgeStageHelper.minStage, 4);
    _maxStage = (module?.maxStage ?? 4).clamp(_minStage, 4);
    _published = widget.existing?.isPublished ?? false;
  }

  @override
  void dispose() {
    _id.dispose();
    _title.dispose();
    _description.dispose();
    _order.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final vm = context.read<AdminContentViewModel>();
    final existing = widget.existing;
    final order = int.tryParse(_order.text.trim()) ?? 20;

    final ok = existing == null
        ? await vm.createModule(
            id: _id.text,
            title: _title.text,
            description: _description.text,
            category: _category,
            minStage: _minStage,
            maxStage: _maxStage,
            order: order,
            isPublished: _published,
          )
        : await vm.updateModule(
            existing,
            title: _title.text,
            description: _description.text,
            category: _category,
            minStage: _minStage,
            maxStage: _maxStage,
            order: order,
            isPublished: _published,
          );

    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AdminContentViewModel>();
    final existing = widget.existing;
    final origin = existing == null ? null : vm.moduleOrigin(existing.module.id);
    final theme = Theme.of(context);

    return AdminScaffold(
      title: _editing ? 'Edit module' : 'New module',
      subtitle: _editing ? existing!.module.title : 'Add a subject',
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (origin != null && origin != ContentOrigin.custom) ...[
            AdminSoftCard(
              child: Row(
                children: [
                  const AdminIconChip(
                    icon: Icons.inventory_2_rounded,
                    color: AppColors.honey,
                    size: 38,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'This module ships with the app. Saving stores your '
                      'version, and children see it once it is published. '
                      'Its levels are not touched.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (vm.errorMessage != null) ...[
            AdminInlineError(
              message: vm.errorMessage!,
              onDismiss: vm.clearMessages,
            ),
            const SizedBox(height: 12),
          ],
          AdminSoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_editing)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Module ID',
                        helperText: 'Fixed — levels and progress point at it.',
                        border: OutlineInputBorder(),
                      ),
                      child: Text(existing!.module.id),
                    ),
                  )
                else
                  AdminTextField(
                    controller: _id,
                    label: 'Module ID (optional)',
                    helperText: 'Leave blank to make one from the title. '
                        'Must be new — math, english, urdu and the other '
                        'built-in IDs are taken. To change those, use Edit.',
                  ),
                AdminTextField(controller: _title, label: 'Title'),
                AdminTextField(
                  controller: _description,
                  label: 'Description',
                  maxLines: 2,
                ),
                AdminEnumDropdown<ModuleCategory>(
                  label: 'Category (sets the colour and icon)',
                  value: _category,
                  values: ModuleCategory.values,
                  onChanged: (value) => setState(() => _category = value),
                ),
                Row(
                  children: [
                    Expanded(
                      child: AdminIntDropdown(
                        label: 'Youngest stage',
                        value: _minStage,
                        values: _stages,
                        onChanged: (value) => setState(() {
                          _minStage = value;
                          if (_maxStage < value) _maxStage = value;
                        }),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: AdminIntDropdown(
                        label: 'Oldest stage',
                        value: _maxStage,
                        values: [
                          for (final stage in _stages)
                            if (stage >= _minStage) stage,
                        ],
                        onChanged: (value) =>
                            setState(() => _maxStage = value),
                      ),
                    ),
                  ],
                ),
                AdminTextField(
                  controller: _order,
                  label: 'Position in the list',
                  helperText: 'Smaller numbers come first.',
                  keyboardType: TextInputType.number,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Published'),
                  subtitle: Text(
                    _published
                        ? 'Children can see it.'
                        : 'Draft — only admins can see it. A module needs at '
                            'least one level before it can go live.',
                  ),
                  value: _published,
                  onChanged: (value) => setState(() => _published = value),
                ),
                const SizedBox(height: 8),
                AppPrimaryButton(
                  icon: Icons.save_rounded,
                  label: _saving
                      ? 'Saving…'
                      : (_editing ? 'Save changes' : 'Create module'),
                  onPressed: _saving ? null : _save,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
