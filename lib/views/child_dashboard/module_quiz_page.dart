import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/activity_option.dart';
import '../../models/module_quiz.dart';
import '../../viewmodels/module_quiz_viewmodel.dart';
import '../../widgets/activities/activity_asset_image.dart';
import '../../widgets/play/play.dart';

/// The quiz that closes a module: a handful of slides drawn from the
/// activities above it, then a pass or a try-again.
///
/// This is the trophy at the end of the road, so it is built out of the play
/// kit like every other child screen — a painted ground, a jelly card per
/// answer, squishy targets, confetti on a pass. It used to be a bare Material
/// scaffold with an app bar and a progress bar, which made the one screen a
/// child reaches by *finishing* a module the least playful thing in the app.
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
      body: PlayGround(
        color: accent,
        safeArea: false,
        child: SafeArea(
          child: vm.isFinished
              ? _QuizResult(accent: accent)
              : _QuizSlide(accent: accent),
        ),
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
        PlayHeader(
          title: '${vm.quiz.moduleTitle} quiz',
          subtitle: 'Question ${vm.questionNumber} of ${vm.totalQuestions}',
          onBack: () => Navigator.of(context).maybePop(),
        ),
        // How far along, as a row of stars rather than a progress bar: a
        // four-year-old reads "three of five stars", not a filling line.
        PoppingStars(
          count: vm.questionNumber - 1,
          total: vm.totalQuestions,
          size: 30,
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
            child: Column(
              children: [
                PopIn(
                  child: PlayPanel(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      children: [
                        Directionality(
                          textDirection: question.isRtl
                              ? TextDirection.rtl
                              : TextDirection.ltr,
                          child: Text(
                            question.prompt,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontFamily: 'Fredoka',
                              fontSize: 24,
                              height: 1.2,
                              fontWeight: FontWeight.w700,
                              color: PlayColors.ink,
                            ),
                          ),
                        ),
                        if (question.promptImage != null) ...[
                          const SizedBox(height: 16),
                          // Counting questions draw the picture as many times
                          // as there are things to count; every other question
                          // draws it once.
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              for (var i = 0; i < question.promptRepeat; i++)
                                ActivityAssetImage(
                                  path: question.promptImage,
                                  size: question.promptRepeat > 1 ? 60 : 116,
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                _OptionGrid(question: question, accent: accent),
              ],
            ),
          ),
        ),
        _SlideFooter(accent: accent),
      ],
    );
  }
}

/// The answers, two to a row.
///
/// A grid rather than a list because most options are pictures and a small
/// hand aims better at a large square than a wide strip.
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
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 1.05,
      ),
      itemBuilder: (context, index) {
        return PopIn(
          index: index,
          child: _OptionTile(
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
          ),
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
      _OptionState.correct => (PlayColors.grass, PlayColors.grass),
      _OptionState.wrong => (PlayColors.strawberry, PlayColors.strawberry),
      _OptionState.idle => (accent, PlayColors.card),
    };
    final marked = state != _OptionState.idle;

    return Squishy(
      onTap: onTap,
      semanticLabel: option.label ?? 'Picture answer',
      scale: 0.96,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: marked ? fill.withValues(alpha: 0.18) : PlayColors.card,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: border, width: marked ? 5 : 3),
        ),
        child: Stack(
          children: [
            Center(child: _content()),
            if (marked)
              Align(
                alignment: AlignmentDirectional.topEnd,
                child: Icon(
                  state == _OptionState.correct
                      ? Icons.check_circle_rounded
                      : Icons.cancel_rounded,
                  color: border,
                  size: 28,
                ),
              ),
          ],
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
            fontFamily: 'Fredoka',
            fontSize: 36,
            fontWeight: FontWeight.w700,
            color: PlayColors.ink,
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
    if (!vm.answered) return const SizedBox(height: 28);

    final right = vm.currentQuestion.isCorrect(vm.selectedIndex!);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
      child: PopIn(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  right ? Icons.stars_rounded : Icons.favorite_rounded,
                  color: right ? PlayColors.sunshine : PlayColors.strawberry,
                  size: 26,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    right ? 'Well done!' : 'The green one is right.',
                    style: const TextStyle(
                      fontFamily: 'Fredoka',
                      fontSize: 19,
                      fontWeight: FontWeight.w600,
                      color: PlayColors.ink,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            PlayButton(
              label: vm.isLastQuestion ? 'See my result' : 'Next',
              icon: vm.isLastQuestion
                  ? Icons.emoji_events_rounded
                  : Icons.arrow_forward_rounded,
              color: accent,
              onPressed: vm.next,
            ),
          ],
        ),
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

    return Stack(
      children: [
        Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                PopIn(
                  child: Icon(
                    passed
                        ? Icons.emoji_events_rounded
                        : Icons.favorite_rounded,
                    size: 104,
                    color: passed ? PlayColors.sunshine : PlayColors.bubblegum,
                  ),
                ),
                const SizedBox(height: 14),
                PopIn(
                  index: 1,
                  child: Text(
                    passed ? 'Trophy won!' : 'Nearly there',
                    style: const TextStyle(
                      fontFamily: 'Fredoka',
                      fontSize: 34,
                      fontWeight: FontWeight.w700,
                      color: PlayColors.ink,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                PopIn(
                  index: 2,
                  child: PoppingStars(
                    count: vm.correctCount,
                    total: vm.totalQuestions,
                    size: 42,
                  ),
                ),
                const SizedBox(height: 14),
                PopIn(
                  index: 3,
                  child: PlayPanel(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 16,
                    ),
                    child: Text(
                      passed
                          ? '${vm.correctCount} of ${vm.totalQuestions} right!'
                          : 'You got ${vm.correctCount} of '
                              '${vm.totalQuestions}. Play the levels again, '
                              'then come back for the trophy.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'Fredoka',
                        fontSize: 18,
                        height: 1.3,
                        fontWeight: FontWeight.w600,
                        color: PlayColors.ink,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 26),
                PlayButton(
                  label: passed ? 'Done' : 'Try again',
                  icon: passed
                      ? Icons.check_rounded
                      : Icons.refresh_rounded,
                  color: accent,
                  big: true,
                  onPressed: passed
                      ? () => Navigator.of(context).pop(true)
                      : vm.restart,
                ),
                if (!passed) ...[
                  const SizedBox(height: 10),
                  PlayButton(
                    label: 'Back to the map',
                    color: PlayColors.card,
                    textColor: PlayColors.ink,
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ],
              ],
            ),
          ),
        ),
        // Only on a pass: confetti for a near miss would be telling a child
        // they succeeded when the screen says they did not.
        if (passed)
          const Positioned.fill(
            child: IgnorePointer(child: ConfettiBurst()),
          ),
      ],
    );
  }
}
