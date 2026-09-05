import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../services/ai/llm_client.dart';
import '../../../services/ai/llm_provider_profile.dart';
import '../../../widgets/app_primary_button.dart';
import 'admin_form_fields.dart';
import 'admin_theme.dart';

/// Where the admin puts their own API key.
///
/// Collapsed to a single line once a key is stored, because this is setup an
/// admin does once and then wants out of the way of the work.
class AiKeyCard extends StatefulWidget {
  const AiKeyCard({
    super.key,
    required this.credentials,
    required this.onSave,
    required this.onForget,
  });

  final LlmCredentials credentials;
  final void Function(String apiKey, LlmProviderProfile profile) onSave;
  final VoidCallback onForget;

  @override
  State<AiKeyCard> createState() => _AiKeyCardState();
}

class _AiKeyCardState extends State<AiKeyCard> {
  final _key = TextEditingController();
  late LlmProviderProfile _profile = widget.credentials.profile;
  bool _editing = false;

  bool get _showForm => _editing || !widget.credentials.isConfigured;

  @override
  void dispose() {
    _key.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AdminSoftCard(
      child: _showForm ? _form(context) : _summary(context),
    );
  }

  Widget _summary(BuildContext context) {
    return Row(
      children: [
        const AdminIconChip(icon: Icons.key_rounded, color: AppColors.leaf),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.credentials.profile.label,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
              Text(
                '${widget.credentials.maskedKey} · '
                '${widget.credentials.profile.model}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: () => setState(() => _editing = true),
          child: const Text('Change'),
        ),
        TextButton(
          onPressed: widget.onForget,
          child: const Text('Forget'),
        ),
      ],
    );
  }

  Widget _form(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AdminSectionHeading(
          title: 'AI provider',
          subtitle: 'Your own key, stored on this device only',
        ),
        const SizedBox(height: 12),
        AdminEnumDropdownLike(
          label: 'Provider',
          value: _profile.id,
          items: {
            for (final preset in LlmProviderProfile.presets)
              preset.id: preset.label,
          },
          onChanged: (id) => setState(
            () => _profile = LlmProviderProfile.presetById(id),
          ),
        ),
        AdminTextField(
          controller: _key,
          label: 'API key',
          helperText: _profile.keyHint,
        ),
        // Said plainly rather than buried: an admin choosing a key should
        // know what protects it, which is the app sandbox and nothing else.
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.honey.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline_rounded, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'The key is kept in plain text on this device and is never '
                  'sent anywhere except your provider. Use a key with a spend '
                  'limit, and press Forget when you are done.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: AppPrimaryButton(
                label: 'Save key',
                onPressed: () {
                  widget.onSave(_key.text, _profile);
                  _key.clear();
                  setState(() => _editing = false);
                },
              ),
            ),
            if (widget.credentials.isConfigured) ...[
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => setState(() => _editing = false),
                child: const Text('Cancel'),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// A string-keyed dropdown in the same shape as [AdminEnumDropdown], for the
/// provider list, which is a set of presets rather than an enum.
class AdminEnumDropdownLike extends StatelessWidget {
  const AdminEnumDropdownLike({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final String value;
  final Map<String, String> items;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        items: [
          for (final entry in items.entries)
            DropdownMenuItem(value: entry.key, child: Text(entry.value)),
        ],
        onChanged: (next) {
          if (next != null) onChanged(next);
        },
      ),
    );
  }
}
