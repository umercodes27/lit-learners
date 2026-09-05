import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../models/activity_option.dart';
import '../../models/module_quiz.dart';
import '../../viewmodels/module_quiz_viewmodel.dart';
import '../../widgets/activities/activity_asset_image.dart';

/// The quiz that closes a module: a handful of slides drawn from the
/// activities above it, then a pass or a try-again.
class ModuleQuizPage extends StatelessWidget {
  const ModuleQuizPage({
    required this.quiz,
    required this.accent,
    super.key,
  });

  final ModuleQuiz quiz;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ModuleQuizViewModel(quiz),
      child: _ModuleQuizView(accent: accent),
    );
  }
}

class _ModuleQuizView extends StatelessWidget {
  const _ModuleQuizView({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ModuleQuizViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: Text('${vm.quiz.moduleTitle} quiz'),
      ),
      body: SafeArea(
        child: vm.isFinished
            ? _QuizResult(accent: accent)
            : _QuizSlide(accent: accent),
      ),
    );
  }
}

class _QuizSlide extends StatelessWidget {
  const _QuizSlide({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ModuleQuizViewModel>();
    final question = vm.currentQuestion;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Question ${vm.questionNumber} of ${vm.totalQuestions}',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink.withValues(alpha: 0.65),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Pass at ${ModuleQuiz.passingPercent}%',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: AppColors.ink.withValues(alpha: 0.45),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: vm.progress,
                  minHeight: 8,
                  backgroundColor: accent.withValues(alpha: 0.15),
                  valueColor: AlwaysStoppedAnimation<Color>(accent),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Directionality(
                textDirection:
                    question.isRtl ? TextDirection.rtl : TextDirection.ltr,
                child: Text(
                  question.prompt,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: AppColors.ink,
                  ),
                ),
              ),
              if (question.promptImage != null) ...[
                const SizedBox(height: 16),
                // Counting questions draw the picture as many times as there
                // are things to count; every other question draws it once.
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (var i = 0; i < question.promptRepeat; i++)
                      ActivityAssetImage(
                        path: question.promptImage,
                        size: question.promptRepeat > 1 ? 64 : 120,
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 24),
              _OptionGrid(question: question, accent: accent),
            ],
          ),
        ),
        _SlideFooter(accent: accent),
      ],
    );
  }
}

/// The answers, two to a row.
///
/// A grid rather than a list because most options are pictures and a
/// two-year-old aims better at a large square than a wide strip.
class _OptionGrid extends StatelessWidget {
  const _OptionGrid({required this.question, required this.accent});

  final ModuleQuizQuestion question;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ModuleQuizViewModel>();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: question.options.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.1,
      ),
      itemBuilder: (context, index) {
        return _OptionTile(
          option: question.options[index],
          isRtl: question.isRtl,
          // Right and wrong only show once the child has committed, so the
          // colours cannot be used to hunt for the answer.
          state: !vm.answered
              ? _OptionState.idle
              : index == question.correctIndex
                  ? _OptionState.correct
                  : index == vm.selectedIndex
                      ? _OptionState.wrong
                      : _OptionState.idle,
          accent: accent,
          onTap: vm.answered ? null : () => vm.selectAnswer(index),
        );
      },
    );
  }
}

enum _OptionState { idle, correct, wrong }

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.option,
    required this.isRtl,
    required this.state,
    required this.accent,
    required this.onTap,
  });

  final ActivityOption option;
  final bool isRtl;
  final _OptionState state;
  final Color accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final (border, fill) = switch (state) {
      _OptionState.correct => (AppColors.leaf, AppColors.mint),
      _OptionState.wrong => (AppColors.coral, AppColors.lemon),
      _OptionState.idle => (AppColors.line, AppColors.panel),
    };

    return Material(
      color: fill,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: border, width: 2),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Stack(
            children: [
              Center(child: _content()),
              if (state != _OptionState.idle)
                Align(
                  alignment: Alignment.topRight,
                  child: Icon(
                    state == _OptionState.correct
                        ? Icons.check_circle_rounded
                        : Icons.cancel_rounded,
                    color: border,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _content() {
    final label = option.label;
    if (label != null && label.isNotEmpty) {
      return Directionality(
        textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w900,
            color: AppColors.ink,
          ),
        ),
      );
    }
    return ActivityAssetImage(path: option.image, size: 84);
  }
}

class _SlideFooter extends StatelessWidget {
  const _SlideFooter({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ModuleQuizViewModel>();
    if (!vm.answered) return const SizedBox(height: 24);

    final right = vm.currentQuestion.isCorrect(vm.selectedIndex!);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(
        children: [
          Icon(
            right ? Icons.stars_rounded : Icons.refresh_rounded,
            color: right ? AppColors.leaf : AppColors.coral,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              right ? 'Well done!' : 'Not quite — the green one is right.',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
          ),
          FilledButton(
            onPressed: vm.next,
            style: FilledButton.styleFrom(backgroundColor: accent),
            child: Text(vm.isLastQuestion ? 'See result' : 'Next'),
          ),
        ],
      ),
    );
  }
}

class _QuizResult extends StatelessWidget {
  const _QuizResult({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ModuleQuizViewModel>();
    final passed = vm.passed;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              passed ? Icons.emoji_events_rounded : Icons.replay_rounded,
              size: 96,
              color: passed ? AppColors.honey : AppColors.plum,
            ),
            const SizedBox(height: 16),
            Text(
              passed ? 'Passed!' : 'Nearly there',
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w900,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${vm.correctCount} of ${vm.totalQuestions} right '
              '— ${vm.scorePercent}%',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.ink.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              passed
                  ? 'You needed ${ModuleQuiz.passingPercent}%.'
                  : 'You need ${ModuleQuiz.passingPercent}% to pass. '
                      'Try the activities again, then come back.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.ink.withValues(alpha: 0.55),
              ),
            ),
            const SizedBox(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: vm.restart,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Try again'),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(passed),
                  style: FilledButton.styleFrom(backgroundColor: accent),
                  child: const Text('Done'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
