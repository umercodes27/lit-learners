import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../viewmodels/admin_content_viewmodel.dart';
import '../../viewmodels/ai_content_viewmodel.dart';
import 'widgets/admin_scaffold.dart';
import 'widgets/ai_draft_card.dart';
import 'widgets/ai_key_card.dart';
import 'widgets/ai_request_card.dart';

/// Generate a stage of levels, check them, and save the ones that are right.
///
/// A separate screen rather than a third form on the content page: this has
/// its own state machine — no key, ready, generating, reviewing — and the
/// content page is already two long forms and two lists.
///
/// Nothing here can reach a child. Everything saved lands as a draft, and the
/// sync that feeds the child app pulls published content only.
class AdminAiAuthoringPage extends StatefulWidget {
  const AdminAiAuthoringPage({super.key});

  @override
  State<AdminAiAuthoringPage> createState() => _AdminAiAuthoringPageState();
}

class _AdminAiAuthoringPageState extends State<AdminAiAuthoringPage> {
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AiContentViewModel>().loadCredentials();
      context.read<AdminContentViewModel>().loadContent();
    });
  }

  @override
  Widget build(BuildContext context) {
    final ai = context.watch<AiContentViewModel>();
    final admin = context.watch<AdminContentViewModel>();

    final modules = [for (final module in admin.modules) module.module];
    final levels = [for (final level in admin.levels) level.level];

    return AdminScaffold(
      title: 'AI Authoring',
      subtitle: 'Draft a stage of levels, then check every one',
      floatingActionButton: ai.drafts.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: ai.canSave
                  ? () => ai.saveApproved(admin.createLevelsFromDrafts)
                  : null,
              backgroundColor:
                  ai.canSave ? AppColors.violet : AppColors.line,
              icon: ai.isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.save_rounded, color: Colors.white),
              label: Text(
                ai.approvedCount == 0
                    ? 'Approve some levels'
                    : 'Save ${ai.approvedCount} '
                        '${ai.approvedCount == 1 ? 'level' : 'levels'}',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w800),
              ),
            ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          AiKeyCard(
            credentials: ai.credentials,
            onSave: (key, profile) =>
                ai.saveKey(apiKey: key, profile: profile),
            onForget: ai.forgetKey,
          ),
          const SizedBox(height: 12),
          AiRequestCard(
            viewModel: ai,
            modules: modules,
            existingLevels: levels,
            onGenerate: () =>
                ai.generate(modules: modules, existingLevels: levels),
          ),
          if (ai.errorMessage != null) ...[
            const SizedBox(height: 12),
            AdminInlineError(
              message: ai.errorMessage!,
              onDismiss: ai.clearMessages,
            ),
          ],
          if (ai.infoMessage != null) ...[
            const SizedBox(height: 12),
            AdminInlineSuccess(
              message: ai.infoMessage!,
              onDismiss: ai.clearMessages,
            ),
          ],
          if (admin.errorMessage != null) ...[
            const SizedBox(height: 12),
            AdminInlineError(message: admin.errorMessage!),
          ],
          // Problems with the batch rather than with any one level.
          for (final issue in ai.batchIssues) ...[
            const SizedBox(height: 12),
            AdminInlineError(message: issue.message),
          ],
          if (ai.isGenerating) ...[
            const SizedBox(height: 12),
            const AdminSoftCard(
              child: Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Writing levels. This usually takes under a minute.',
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (ai.drafts.isNotEmpty) ...[
            const SizedBox(height: 18),
            AdminSectionHeading(
              title: 'Drafts',
              subtitle: '${ai.approvedCount} of ${ai.drafts.length} approved'
                  '${ai.attempts > 1 ? ' · took ${ai.attempts} tries' : ''}',
            ),
            const SizedBox(height: 10),
            // Only worth saying once something is approved; before that the
            // FAB already explains itself.
            if (ai.approvedCount > 0 && ai.approvalProblem != null) ...[
              AdminInlineError(message: ai.approvalProblem!),
              const SizedBox(height: 10),
            ],
            for (var i = 0; i < ai.drafts.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: AiDraftCard(
                  draft: ai.drafts[i],
                  onApprovedChanged: (approved) =>
                      ai.toggleApproved(i, approved),
                  onEdited: (level) => ai.updateDraft(i, level),
                ),
              ),
          ] else if (!ai.isGenerating) ...[
            const SizedBox(height: 18),
            const AdminEmptyState(
              icon: Icons.auto_awesome_rounded,
              title: 'Nothing drafted yet',
              message: 'Pick a module and a stage, then press Generate. '
                  'Everything you save lands as a draft, so nothing reaches a '
                  'child until you publish it.',
            ),
          ],
        ],
      ),
    );
  }
}
