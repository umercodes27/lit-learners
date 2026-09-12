import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/age_stage_helper.dart';
import '../../core/utils/learning_text_direction.dart';
import '../../models/admin_content.dart';
import '../../models/content_item.dart';
import '../../models/learning_level.dart';
import '../../models/quiz_question.dart';
import '../../services/ai/content_draft_validator.dart';
import '../../viewmodels/admin_content_viewmodel.dart';
import '../../widgets/app_primary_button.dart';
import 'widgets/admin_form_fields.dart';
import 'widgets/admin_image_field.dart';
import 'widgets/admin_scaffold.dart';

/// Creates a level, or edits one that exists — built-in or custom — with as
/// many cards and quiz questions as it needs, each with an optional picture.
///
/// Replaces the old inline form, which allowed exactly one card and one
/// question: the levels that ship have up to ten cards, so the form could not
/// even reproduce the app's own content.
class AdminLevelEditorPage extends StatefulWidget {
  const AdminLevelEditorPage({super.key, this.existing, this.moduleId});

  /// Null when creating.
  final AdminContentLevel? existing;

  /// The module to start a new level in.
  final String? moduleId;

  /// Named under `/admin` so signing out closes it with the other admin
  /// screens.
  static Route<bool> route({AdminContentLevel? existing, String? moduleId}) =>
      MaterialPageRoute<bool>(
        settings: const RouteSettings(name: '/admin/content/level'),
        builder: (_) =>
            AdminLevelEditorPage(existing: existing, moduleId: moduleId),
      );

  @override
  State<AdminLevelEditorPage> createState() => _AdminLevelEditorPageState();
}

class _CardDraft {
  _CardDraft([ContentItem? item])
      : title = TextEditingController(text: item?.title ?? ''),
        prompt = TextEditingController(text: item?.prompt ?? ''),
        display = TextEditingController(text: item?.displayText ?? ''),
        visual = TextEditingController(text: item?.visualLabel ?? ''),
        imageUrl = item?.imageUrl,
        audioCueKey = item?.audioCueKey;

  final TextEditingController title;
  final TextEditingController prompt;
  final TextEditingController display;
  final TextEditingController visual;
  String? imageUrl;

  /// Carried over untouched: a recorded clip is not something this form can
  /// make, and dropping it would silence a built-in card that had one.
  final String? audioCueKey;

  ContentItem toItem() => ContentItem(
        title: title.text,
        prompt: prompt.text,
        displayText: display.text,
        visualLabel: visual.text,
        audioCueKey: audioCueKey,
        imageUrl: imageUrl,
      );

  void dispose() {
    title.dispose();
    prompt.dispose();
    display.dispose();
    visual.dispose();
  }
}

class _QuestionDraft {
  _QuestionDraft([QuizQuestion? question])
      : prompt = TextEditingController(text: question?.prompt ?? ''),
        options = [
          for (final option in question?.options ?? const ['', ''])
            TextEditingController(text: option),
        ],
        correct = question?.correctIndex ?? 0,
        imageUrl = question?.imageUrl,
        visualLabel = question?.visualLabel,
        explanation = question?.explanation;

  final TextEditingController prompt;
  final List<TextEditingController> options;
  int correct;
  String? imageUrl;
  final String? visualLabel;
  final String? explanation;

  QuizQuestion toQuestion() => QuizQuestion(
        // Assigned by the viewmodel, which keeps existing ids stable.
        id: '',
        prompt: prompt.text,
        options: [for (final option in options) option.text],
        correctIndex: correct,
        visualLabel: visualLabel,
        explanation: explanation,
        imageUrl: imageUrl,
      );

  void dispose() {
    prompt.dispose();
    for (final option in options) {
      option.dispose();
    }
  }
}

class _AdminLevelEditorPageState extends State<AdminLevelEditorPage> {
  late final TextEditingController _title;
  late final TextEditingController _subtitle;
  late final TextEditingController _number;
  late final TextEditingController _score;
  late final TextEditingController _videoTitle;
  late final TextEditingController _videoUrl;
  late String? _moduleId;
  late int _stage;
  late LevelType _type;
  late bool _published;
  late final List<_CardDraft> _cards;
  late final List<_QuestionDraft> _questions;
  var _numberEdited = false;
  var _saving = false;

  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final level = widget.existing?.level;
    _title = TextEditingController(text: level?.title ?? '');
    _subtitle = TextEditingController(text: level?.subtitle ?? '');
    _number = TextEditingController(text: '${level?.levelNumber ?? 1}');
    _score = TextEditingController(text: '${level?.passingScore ?? 70}');
    final video = level?.videoLessons.firstOrNull;
    _videoTitle = TextEditingController(text: video?.title ?? '');
    _videoUrl = TextEditingController(text: video?.videoUrl ?? '');
    _moduleId = level?.moduleId ?? widget.moduleId;
    _stage = (level?.stage ?? AgeStageHelper.minStage)
        .clamp(AgeStageHelper.minStage, 4);
    _type = level?.type ?? LevelType.flashcards;
    _published = widget.existing?.isPublished ?? false;
    _cards = [
      for (final item in level?.contentItems ?? const <ContentItem>[])
        _CardDraft(item),
    ];
    if (_cards.isEmpty) _cards.add(_CardDraft());
    _questions = [
      for (final question in level?.quizQuestions ?? const <QuizQuestion>[])
        _QuestionDraft(question),
    ];

    if (!_editing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final vm = context.read<AdminContentViewModel>();
        _moduleId ??= vm.modules.firstOrNull?.module.id;
        _fitStageToModule(vm);
        _suggestNumber(vm);
        setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _subtitle.dispose();
    _number.dispose();
    _score.dispose();
    _videoTitle.dispose();
    _videoUrl.dispose();
    for (final card in _cards) {
      card.dispose();
    }
    for (final question in _questions) {
      question.dispose();
    }
    super.dispose();
  }

  List<int> _stagesFor(AdminContentViewModel vm) {
    final module = _moduleId == null ? null : vm.moduleById(_moduleId!);
    final min = (module?.module.minStage ?? AgeStageHelper.minStage)
        .clamp(AgeStageHelper.minStage, 4);
    final max = (module?.module.maxStage ?? 4).clamp(min, 4);
    return [for (var stage = min; stage <= max; stage++) stage];
  }

  void _fitStageToModule(AdminContentViewModel vm) {
    final stages = _stagesFor(vm);
    if (!stages.contains(_stage)) _stage = stages.first;
  }

  /// A new level continues the ladder unless the admin has typed a number
  /// of their own.
  void _suggestNumber(AdminContentViewModel vm) {
    if (_editing || _numberEdited || _moduleId == null) return;
    _number.text = '${vm.nextLevelNumber(_moduleId!, _stage)}';
  }

  Future<void> _save() async {
    final moduleId = _moduleId;
    if (moduleId == null) return;
    setState(() => _saving = true);

    final vm = context.read<AdminContentViewModel>();
    final existing = widget.existing;
    final number = int.tryParse(_number.text.trim()) ?? 0;
    final score = int.tryParse(_score.text.trim()) ?? -1;
    final items = [for (final card in _cards) card.toItem()];
    final questions = [for (final q in _questions) q.toQuestion()];

    final ok = existing == null
        ? await vm.createLevel(
            id: '',
            moduleId: moduleId,
            stage: _stage,
            levelNumber: number,
            title: _title.text,
            subtitle: _subtitle.text,
            type: _type,
            passingScore: score,
            isPublished: _published,
            contentItems: items,
            quizQuestions: questions,
            videoTitle: _videoTitle.text,
            videoUrl: _videoUrl.text,
          )
        : await vm.updateLevel(
            existing,
            stage: _stage,
            levelNumber: number,
            title: _title.text,
            subtitle: _subtitle.text,
            type: _type,
            passingScore: score,
            isPublished: _published,
            contentItems: items,
            quizQuestions: questions,
            videoTitle: _videoTitle.text,
            videoUrl: _videoUrl.text,
          );

    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AdminContentViewModel>();
    final theme = Theme.of(context);
    final existing = widget.existing;
    final origin = existing == null ? null : vm.levelOrigin(existing.level.id);
    final module = _moduleId == null ? null : vm.moduleById(_moduleId!);
    final direction = module == null
        ? TextDirection.ltr
        : LearningTextDirection.forModule(module.module);
    final contentStyle = LearningTextDirection.styleFor(
      theme.textTheme.bodyLarge,
      direction,
    );

    Widget text(
      TextEditingController controller,
      String label, {
      String? helper,
      int maxLines = 1,
    }) =>
        AdminTextField(
          controller: controller,
          label: label,
          helperText: helper,
          maxLines: maxLines,
          textDirection: direction,
          style: contentStyle,
        );

    return AdminScaffold(
      title: _editing ? 'Edit level' : 'New level',
      subtitle: _editing ? existing!.level.title : 'Add to a module',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          if (origin != null && origin != ContentOrigin.custom) ...[
            const _Notice(
              icon: Icons.inventory_2_rounded,
              color: AppColors.honey,
              text: 'This level ships with the app. Saving stores your '
                  'version under the same ID; once it is published, children '
                  'see yours instead. Restore on the content page brings the '
                  'original back.',
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
          _basics(vm, text),
          const SizedBox(height: 12),
          if (_type == LevelType.video)
            _video(text)
          else
            _cardsSection(text),
          const SizedBox(height: 12),
          _quizSection(text),
          const SizedBox(height: 16),
          if (vm.errorMessage != null) ...[
            AdminInlineError(message: vm.errorMessage!),
            const SizedBox(height: 12),
          ],
          AppPrimaryButton(
            icon: Icons.save_rounded,
            label: _saving
                ? 'Saving…'
                : (_editing ? 'Save changes' : 'Create level'),
            onPressed: _saving || _moduleId == null ? null : _save,
          ),
        ],
      ),
    );
  }

  Widget _basics(
    AdminContentViewModel vm,
    Widget Function(TextEditingController, String,
            {String? helper, int maxLines})
        text,
  ) {
    final canvas = _type == LevelType.drawing || _type == LevelType.tracing;

    return AdminSoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AdminSectionHeading(title: 'The level'),
          const SizedBox(height: 10),
          if (_editing)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Module · level ID',
                  border: OutlineInputBorder(),
                ),
                child: Text('${widget.existing!.level.moduleId} · '
                    '${widget.existing!.level.id}'),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: DropdownButtonFormField<String>(
                initialValue: _moduleId,
                decoration: const InputDecoration(
                  labelText: 'Module',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final module in vm.modules)
                    DropdownMenuItem(
                      value: module.module.id,
                      child: Text('${module.module.title} '
                          '(${module.module.id})'),
                    ),
                ],
                onChanged: (id) => setState(() {
                  _moduleId = id;
                  _fitStageToModule(vm);
                  _suggestNumber(vm);
                }),
              ),
            ),
          Row(
            children: [
              Expanded(
                child: AdminIntDropdown(
                  label: 'Stage',
                  value: _stage,
                  values: _stagesFor(vm),
                  onChanged: (stage) => setState(() {
                    _stage = stage;
                    _suggestNumber(vm);
                  }),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Focus(
                  onFocusChange: (focused) {
                    if (focused) _numberEdited = true;
                  },
                  child: AdminTextField(
                    controller: _number,
                    label: 'Level number',
                    keyboardType: TextInputType.number,
                  ),
                ),
              ),
            ],
          ),
          text(_title, 'Title'),
          text(_subtitle, 'Subtitle (optional)',
              helper: 'One line on what the child will do.'),
          AdminEnumDropdown<LevelType>(
            label: 'Level type',
            value: _type,
            values: LevelType.values,
            onChanged: (type) => setState(() => _type = type),
          ),
          AdminTextField(
            controller: _score,
            label: 'Passing score',
            keyboardType: TextInputType.number,
            helperText: canvas
                ? 'A grown-up grades this. Use '
                    '${ContentDraftValidator.canvasMinPassingScore}–'
                    '${ContentDraftValidator.canvasMaxPassingScore}.'
                : '0 to 100.',
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Published'),
            subtitle: Text(_published
                ? 'Children can play it once their app refreshes.'
                : 'Draft — only admins can see it.'),
            value: _published,
            onChanged: (value) => setState(() => _published = value),
          ),
        ],
      ),
    );
  }

  Widget _cardsSection(
    Widget Function(TextEditingController, String,
            {String? helper, int maxLines})
        text,
  ) {
    final theme = Theme.of(context);
    final moduleId = _moduleId ?? 'general';

    return AdminSoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdminSectionHeading(
            title: 'Cards (${_cards.length})',
            subtitle: _cardsHint(),
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < _cards.length; i++) ...[
            Row(
              children: [
                Text('Card ${i + 1}',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w900)),
                const Spacer(),
                IconButton(
                  tooltip: 'Move up',
                  onPressed: i == 0
                      ? null
                      : () => setState(() {
                            final card = _cards.removeAt(i);
                            _cards.insert(i - 1, card);
                          }),
                  icon: const Icon(Icons.arrow_upward_rounded),
                ),
                IconButton(
                  tooltip: 'Move down',
                  onPressed: i == _cards.length - 1
                      ? null
                      : () => setState(() {
                            final card = _cards.removeAt(i);
                            _cards.insert(i + 1, card);
                          }),
                  icon: const Icon(Icons.arrow_downward_rounded),
                ),
                IconButton(
                  tooltip: 'Remove card',
                  color: AppColors.coral,
                  onPressed: () => setState(() {
                    _cards.removeAt(i).dispose();
                  }),
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ],
            ),
            text(_cards[i].title, 'Card title',
                helper: _type == LevelType.matching
                    ? 'On a matching level the titles are the answers the '
                        'child picks from.'
                    : null),
            text(_cards[i].prompt, 'Read aloud / instruction'),
            text(_cards[i].display, 'Shown big', helper: _displayHint()),
            text(_cards[i].visual, 'Picture description (optional)',
                helper: 'Shown under the card, and used if the picture '
                    'cannot load.'),
            AdminImageField(
              url: _cards[i].imageUrl,
              moduleId: moduleId,
              onChanged: (url) => setState(() => _cards[i].imageUrl = url),
            ),
            if (i < _cards.length - 1) const Divider(height: 24),
          ],
          OutlinedButton.icon(
            onPressed: () => setState(() => _cards.add(_CardDraft())),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add a card'),
          ),
        ],
      ),
    );
  }

  Widget _quizSection(
    Widget Function(TextEditingController, String,
            {String? helper, int maxLines})
        text,
  ) {
    final theme = Theme.of(context);
    final moduleId = _moduleId ?? 'general';

    return AdminSoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdminSectionHeading(
            title: 'Quiz (${_questions.length})',
            subtitle: 'Optional. Asked after the cards.',
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < _questions.length; i++) ...[
            Row(
              children: [
                Text('Question ${i + 1}',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w900)),
                const Spacer(),
                IconButton(
                  tooltip: 'Remove question',
                  color: AppColors.coral,
                  onPressed: () => setState(() {
                    _questions.removeAt(i).dispose();
                  }),
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ],
            ),
            text(_questions[i].prompt, 'Question'),
            AdminImageField(
              label: 'Question picture',
              url: _questions[i].imageUrl,
              moduleId: moduleId,
              onChanged: (url) =>
                  setState(() => _questions[i].imageUrl = url),
            ),
            Text('Answers — tick the right one',
                style: theme.textTheme.labelLarge),
            // A choice between the real answers rather than an index box, so
            // a right answer that points at nothing cannot be typed.
            RadioGroup<int>(
              groupValue: _questions[i].correct,
              onChanged: (value) {
                if (value == null) return;
                setState(() => _questions[i].correct = value);
              },
              child: Column(
                children: [
                  for (var o = 0; o < _questions[i].options.length; o++)
                    Row(
                      children: [
                        Radio<int>(value: o),
                        Expanded(
                          child: text(
                            _questions[i].options[o],
                            'Answer ${o + 1}',
                          ),
                        ),
                        IconButton(
                          tooltip: 'Remove answer',
                          onPressed: _questions[i].options.length <= 2
                              ? null
                              : () => setState(() => _removeOption(i, o)),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => setState(() =>
                    _questions[i].options.add(TextEditingController())),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add an answer'),
              ),
            ),
            if (i < _questions.length - 1) const Divider(height: 24),
          ],
          OutlinedButton.icon(
            onPressed: () => setState(() => _questions.add(_QuestionDraft())),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add a question'),
          ),
        ],
      ),
    );
  }

  /// Keeps the tick on the same words when an answer above it is removed.
  void _removeOption(int question, int option) {
    final draft = _questions[question];
    draft.options.removeAt(option).dispose();
    if (draft.correct == option) {
      draft.correct = 0;
    } else if (draft.correct > option) {
      draft.correct -= 1;
    }
  }

  Widget _video(
    Widget Function(TextEditingController, String,
            {String? helper, int maxLines})
        text,
  ) {
    return AdminSoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AdminSectionHeading(
            title: 'Video',
            subtitle: 'A full https:// link to the video file.',
          ),
          const SizedBox(height: 10),
          text(_videoTitle, 'Video title'),
          AdminTextField(controller: _videoUrl, label: 'Video URL'),
        ],
      ),
    );
  }

  String _cardsHint() => switch (_type) {
        LevelType.flashcards => 'Each card is shown one after another.',
        LevelType.story => 'Each card is one page of the story.',
        LevelType.counting => 'Each card asks the child to count to a number.',
        LevelType.matching => 'Add at least two cards with different titles.',
        LevelType.drawing => 'Each card is one thing to draw.',
        LevelType.tracing => 'Each card is one letter or digit to trace.',
        LevelType.video => '',
      };

  String? _displayHint() => switch (_type) {
        LevelType.tracing => 'Exactly one letter or digit, like A or ا or 5 — '
            'this is what gets traced.',
        LevelType.counting => 'Digits only, like 3. This is the number to '
            'count to.',
        _ => null,
      };
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.color, required this.text});

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return AdminSoftCard(
      child: Row(
        children: [
          AdminIconChip(icon: icon, color: color, size: 38),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}
