import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/learning_text_direction.dart';
import '../../../core/utils/module_visuals.dart';
import '../../../models/ai_level_draft.dart';
import '../../../models/content_item.dart';
import '../../../models/learning_level.dart';
import '../../../models/quiz_question.dart';
import 'admin_form_fields.dart';
import 'admin_theme.dart';

/// One generated level, with everything the admin needs to decide about it.
///
/// The approve control is disabled while any blocking issue remains. That is
/// the enforcement point of the whole feature: a level that would break in
/// front of a child cannot be saved, however keen anyone is to get on with it.
class AiDraftCard extends StatelessWidget {
  const AiDraftCard({
    super.key,
    required this.draft,
    required this.onApprovedChanged,
    required this.onEdited,
  });

  final AiLevelDraft draft;
  final ValueChanged<bool> onApprovedChanged;
  final ValueChanged<LearningLevel> onEdited;

  @override
  Widget build(BuildContext context) {
    final level = draft.level;
    final category = ModuleVisuals.categoryForModuleId(level.moduleId);
    final accent = ModuleVisuals.colorFor(category);
    final direction = LearningTextDirection.forLevel(level);
    final theme = Theme.of(context);

    return AdminSoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AdminIconChip(
                icon: ModuleVisuals.iconFor(category),
                color: accent,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      level.title,
                      textDirection: direction,
                      style: LearningTextDirection.styleFor(
                        theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w900),
                        direction,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      level.subtitle,
                      textDirection: direction,
                      style: LearningTextDirection.styleFor(
                        theme.textTheme.bodySmall,
                        direction,
                      ),
                    ),
                  ],
                ),
              ),
              _ApproveBox(draft: draft, onChanged: onApprovedChanged),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              AdminPill(label: 'Level ${level.levelNumber}', accent: accent),
              AdminPill(label: level.type.name, accent: AppColors.violet),
              if (level.contentItems.isNotEmpty)
                AdminPill(
                  label: '${level.contentItems.length} '
                      '${level.contentItems.length == 1 ? 'card' : 'cards'}',
                  accent: AppColors.aqua,
                ),
              if (level.quizQuestions.isNotEmpty)
                AdminPill(
                  label: '${level.quizQuestions.length} '
                      '${level.quizQuestions.length == 1 ? 'question' : 'questions'}',
                  accent: AppColors.mint,
                ),
              AdminPill(label: 'Pass ${level.passingScore}', accent: AppColors.lilac),
              if (level.portionLabel != null)
                AdminPill(label: level.portionLabel!, accent: AppColors.honey),
            ],
          ),
          for (final issue in draft.blocking) ...[
            const SizedBox(height: 8),
            AdminInlineError(message: '${issue.path}\n${issue.message}'),
          ],
          if (draft.warnings.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final warning in draft.warnings)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        size: 16, color: AppColors.honey),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(warning.message,
                          style: theme.textTheme.bodySmall),
                    ),
                  ],
                ),
              ),
          ],
          // Never let a repair happen silently: an admin approving a level
          // should know the app changed something in it.
          if (draft.repairs.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final repair in draft.repairs)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.auto_fix_high_rounded,
                        size: 16, color: AppColors.leaf),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text('Fixed for you: $repair',
                          style: theme.textTheme.bodySmall),
                    ),
                  ],
                ),
              ),
          ],
          Theme(
            data: theme.copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text('Edit this level',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
              children: [
                _DraftEditor(level: level, onEdited: onEdited),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ApproveBox extends StatelessWidget {
  const _ApproveBox({required this.draft, required this.onChanged});

  final AiLevelDraft draft;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final blocked = draft.isBlocked;

    return Tooltip(
      message: blocked
          ? draft.blocking.first.message
          : (draft.isApproved ? 'Will be saved' : 'Approve this level'),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            blocked ? 'Blocked' : 'Approve',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: blocked ? AppColors.coral : null,
                  fontWeight: FontWeight.w700,
                ),
          ),
          Checkbox(
            value: draft.isApproved,
            // Not merely unchecked — unusable. A blocked level is one the app
            // knows would break, so approving it is not a judgement call.
            onChanged: blocked ? null : (value) => onChanged(value ?? false),
          ),
        ],
      ),
    );
  }
}

/// Edits one generated level in place.
///
/// Every change goes straight back through the viewmodel, which re-checks the
/// whole batch, so the Approve box above enables the moment the last problem
/// is fixed. That immediate feedback is the point: without it an admin is
/// guessing what the app objects to.
class _DraftEditor extends StatefulWidget {
  const _DraftEditor({required this.level, required this.onEdited});

  final LearningLevel level;
  final ValueChanged<LearningLevel> onEdited;

  @override
  State<_DraftEditor> createState() => _DraftEditorState();
}

class _DraftEditorState extends State<_DraftEditor> {
  late final TextEditingController _title;
  late final TextEditingController _subtitle;
  late final TextEditingController _score;
  late final List<List<TextEditingController>> _cards;
  late final List<TextEditingController> _questions;
  late List<int> _correctIndexes;

  @override
  void initState() {
    super.initState();
    final level = widget.level;
    _title = TextEditingController(text: level.title);
    _subtitle = TextEditingController(text: level.subtitle);
    _score = TextEditingController(text: level.passingScore.toString());
    _cards = [
      for (final item in level.contentItems)
        [
          TextEditingController(text: item.title),
          TextEditingController(text: item.prompt),
          TextEditingController(text: item.displayText),
          TextEditingController(text: item.visualLabel),
        ],
    ];
    _questions = [
      for (final question in level.quizQuestions)
        TextEditingController(text: question.prompt),
    ];
    _correctIndexes = [
      for (final question in level.quizQuestions) question.correctIndex,
    ];
  }

  @override
  void dispose() {
    _title.dispose();
    _subtitle.dispose();
    _score.dispose();
    for (final card in _cards) {
      for (final controller in card) {
        controller.dispose();
      }
    }
    for (final controller in _questions) {
      controller.dispose();
    }
    super.dispose();
  }

  void _emit() {
    final level = widget.level;
    widget.onEdited(
      level.copyWith(
        title: _title.text,
        subtitle: _subtitle.text,
        passingScore: int.tryParse(_score.text.trim()) ?? level.passingScore,
        contentItems: [
          for (var i = 0; i < _cards.length; i++)
            ContentItem(
              title: _cards[i][0].text,
              prompt: _cards[i][1].text,
              displayText: _cards[i][2].text,
              visualLabel: _cards[i][3].text,
              audioCueKey: level.contentItems[i].audioCueKey,
            ),
        ],
        quizQuestions: [
          for (var i = 0; i < _questions.length; i++)
            QuizQuestion(
              id: level.quizQuestions[i].id,
              prompt: _questions[i].text,
              options: level.quizQuestions[i].options,
              correctIndex: _correctIndexes[i],
              visualLabel: level.quizQuestions[i].visualLabel,
              explanation: level.quizQuestions[i].explanation,
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final direction = LearningTextDirection.forLevel(widget.level);
    final style = LearningTextDirection.styleFor(
      Theme.of(context).textTheme.bodyLarge,
      direction,
    );

    Widget field(TextEditingController controller, String label,
            {String? helper}) =>
        AdminTextField(
          controller: controller,
          label: label,
          helperText: helper,
          textDirection: direction,
          style: style,
        );

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          field(_title, 'Title'),
          field(_subtitle, 'Subtitle'),
          AdminTextField(
            controller: _score,
            label: 'Passing score',
            keyboardType: TextInputType.number,
          ),
          for (var i = 0; i < _cards.length; i++) ...[
            const SizedBox(height: 4),
            Text('Card ${i + 1}',
                style: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            field(_cards[i][0], 'What this card is'),
            field(_cards[i][1], 'Read aloud'),
            field(
              _cards[i][2],
              'Shown big',
              helper: widget.level.type == LevelType.tracing
                  ? 'Exactly one character — this is traced.'
                  : widget.level.type == LevelType.counting
                      ? 'Digits only, like 3.'
                      : null,
            ),
            field(_cards[i][3], 'Picture description'),
          ],
          for (var i = 0; i < _questions.length; i++) ...[
            const SizedBox(height: 4),
            Text('Question ${i + 1}',
                style: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            field(_questions[i], 'Question'),
            // A radio over the real options rather than a number box, so an
            // index pointing at nothing is not something the UI can express.
            RadioGroup<int>(
              groupValue: _correctIndexes[i],
              onChanged: (value) {
                if (value == null) return;
                setState(() => _correctIndexes[i] = value);
                _emit();
              },
              child: Column(
                children: [
                  for (var option = 0;
                      option < widget.level.quizQuestions[i].options.length;
                      option++)
                    RadioListTile<int>(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      value: option,
                      title: Text(
                        widget.level.quizQuestions[i].options[option],
                        textDirection: direction,
                        style: style,
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: _emit,
              icon: const Icon(Icons.check_rounded, size: 18),
              label: const Text('Apply changes'),
            ),
          ),
        ],
      ),
    );
  }
}
