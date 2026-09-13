import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/localization/urdu_letters.dart';
import '../../models/activity_option.dart';
import '../../models/module_quiz.dart';
import '../../services/audio/app_sounds.dart';
import '../../services/audio/quiz_voice.dart';
import '../../services/audio/sound_controller.dart';
import '../../viewmodels/module_quiz_viewmodel.dart';
import '../../widgets/activities/activity_asset_image.dart';
import '../../widgets/activities/age2_mascot.dart';
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
    this.voice,
  });

  final ModuleQuiz quiz;
  final Color accent;

  /// Injected by the widget tests so they never reach a real speech engine.
  final QuizVoice? voice;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ModuleQuizViewModel(quiz),
      child: _ModuleQuizView(accent: accent, voice: voice),
    );
  }
}

class _ModuleQuizView extends StatelessWidget {
  const _ModuleQuizView({required this.accent, this.voice});

  final Color accent;
  final QuizVoice? voice;

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
              : _QuizSlide(accent: accent, voice: voice),
        ),
      ),
    );
  }
}

class _QuizSlide extends StatefulWidget {
  const _QuizSlide({required this.accent, this.voice});

  final Color accent;
  final QuizVoice? voice;

  @override
  State<_QuizSlide> createState() => _QuizSlideState();
}

class _QuizSlideState extends State<_QuizSlide> {
  late final QuizVoice _voice = widget.voice ?? QuizVoice();

  /// The question whose verdict has already been said, so the line is not
  /// repeated by the rebuilds that follow it.
  String? _verdictSpokenFor;

  /// Held so the star can be cancelled: a child who taps Next inside the
  /// gap would otherwise leave a timer running on a dead screen.
  Timer? _starTimer;

  Color get accent => widget.accent;

  @override
  void dispose() {
    _starTimer?.cancel();
    _voice.dispose();
    super.dispose();
  }

  /// Says the question, and then the answer once one is given.
  ///
  /// Driven from `build` because the slide stays mounted as the quiz moves
  /// from question to question; [QuizVoice] is what keeps each line to once.
  void _speak(ModuleQuizViewModel vm) {
    final question = vm.currentQuestion;
    _voice.askQuestion(
      questionId: question.id,
      text: question.prompt,
      urdu: QuizVoice.urduFor(question.prompt, levelIsRtl: question.isRtl),
    );

    if (!vm.answered || _verdictSpokenFor == question.id) return;
    _verdictSpokenFor = question.id;

    if (question.isCorrect(vm.selectedIndex!)) {
      // Clapping and confetti, the same as the levels give: a child who
      // cannot read the "Well done!" above it hears and sees one anyway, and
      // words spoken over applause would only compete with it.
      AppSound.play(Sfx.applause);
      // A star for the question just won, with the pop the rest of the app
      // uses for one. Both the sound and the star row already existed here;
      // neither was ever fired by an answer.
      _starTimer?.cancel();
      _starTimer = Timer(const Duration(milliseconds: 280), () {
        if (mounted) AppSound.play(Sfx.starPop);
      });
      return;
    }

    // The wrong-answer line is the one worth saying: it names the colour of
    // the card that lit up, which is the only part a child cannot work out
    // from the screen alone.
    _voice.sayVerdict('The green one is right.', urdu: question.isRtl);
  }

  /// Whether the answer just given was right, which is what the burst needs.
  bool _justGotItRight(ModuleQuizViewModel vm) =>
      vm.answered &&
      vm.selectedIndex != null &&
      vm.currentQuestion.isCorrect(vm.selectedIndex!);

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ModuleQuizViewModel>();
    final question = vm.currentQuestion;

    _speak(vm);

    return Stack(
      children: [
        Column(
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
                            // The koala asks the question here, the way it
                            // does in every activity that led to this quiz.
                            // Its absence was why the one screen a child
                            // reaches by *finishing* a module had none of the
                            // character of the modules themselves.
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // The koala answers back: a hop for a right
                                // answer, a sympathetic tilt for a wrong one.
                                // A child who cannot read the verdict can read
                                // this.
                                AnimatedScale(
                                  scale: _justGotItRight(vm) ? 1.18 : 1,
                                  duration: PlayMotion.springBack,
                                  curve: Curves.elasticOut,
                                  child: AnimatedRotation(
                                    turns: vm.answered && !_justGotItRight(vm)
                                        ? -0.04
                                        : 0,
                                    duration: PlayMotion.springBack,
                                    child: const Age2Mascot(size: 46),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // In a bubble, so the koala is saying it
                                // rather than standing next to some text.
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: PlayColors.cream,
                                      borderRadius: BorderRadius.circular(22),
                                      border: Border.all(
                                        color: accent.withValues(alpha: 0.35),
                                        width: 3,
                                      ),
                                    ),
                                    child: Directionality(
                                      textDirection: question.isRtl
                                          ? TextDirection.rtl
                                          : TextDirection.ltr,
                                      child: Text(
                                        question.prompt,
                                        textAlign: question.isRtl
                                            ? TextAlign.right
                                            : TextAlign.left,
                                        style: const TextStyle(
                                          fontFamily: 'Fredoka',
                                          fontSize: 24,
                                          height: 1.2,
                                          fontWeight: FontWeight.w700,
                                          color: PlayColors.ink,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            // The pattern itself, in order, with a trailing blank
                            // for the answer the child is about to choose.
                            if (question.promptSequence.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              Wrap(
                                alignment: WrapAlignment.center,
                                spacing: 10,
                                runSpacing: 10,
                                children: [
                                  for (final path in question.promptSequence)
                                    ActivityAssetImage(path: path, size: 84),
                                  const _SequenceBlank(),
                                ],
                              ),
                            ],
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
                                  for (var i = 0;
                                      i < question.promptRepeat;
                                      i++)
                                    ActivityAssetImage(
                                      path: question.promptImage,
                                      size:
                                          question.promptRepeat > 1 ? 60 : 116,
                                    ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // A quiz slide is the one screen a child reaches by finishing
                    // a module, and it asks its question out loud. Saying it again
                    // has to be as easy as it is in the activities.
                    PlayButton(
                      label: 'Listen again',
                      icon: Icons.volume_up_rounded,
                      color: Colors.white,
                      expand: false,
                      onPressed: () => _voice.repeatQuestion(
                        text: question.prompt,
                        urdu: QuizVoice.urduFor(
                          question.prompt,
                          levelIsRtl: question.isRtl,
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
        ),
        // Per answer, not just on the final result: every right answer earns
        // the burst, the way every right answer in a level does.
        if (_justGotItRight(vm))
          Positioned.fill(
            child: IgnorePointer(
              child: ConfettiBurst(key: ValueKey('burst${question.id}')),
            ),
          ),
      ],
    );
  }
}

/// The gap at the end of a pattern: what the child is choosing to fill.
class _SequenceBlank extends StatelessWidget {
  const _SequenceBlank();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 84,
      height: 84,
      decoration: BoxDecoration(
        color: PlayColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: PlayColors.ink.withValues(alpha: 0.35),
          width: 3,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        '?',
        style: TextStyle(
          fontFamily: 'Fredoka',
          fontSize: 40,
          fontWeight: FontWeight.w700,
          color: PlayColors.ink.withValues(alpha: 0.55),
        ),
      ),
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
            position: index,
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
    required this.position,
    required this.onTap,
  });

  /// Which card this is in the grid, so each gets its own colour.
  final int position;

  final ActivityOption option;
  final bool isRtl;
  final _OptionState state;
  final Color accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    // Unanswered cards each take their own colour from the play palette.
    // A grid of identical white boxes is the most grown-up thing a child sees
    // in this app; the levels they came from are full of colour. Right and
    // wrong still override it, so the feedback is never ambiguous.
    final own = PlayColors.byIndex(position);
    final (border, fill) = switch (state) {
      _OptionState.correct => (PlayColors.grass, PlayColors.grass),
      _OptionState.wrong => (PlayColors.strawberry, PlayColors.strawberry),
      _OptionState.idle => (own, own),
    };
    final marked = state != _OptionState.idle;

    return Squishy(
      onTap: onTap,
      semanticLabel: option.label ?? 'Picture answer',
      scale: 0.96,
      // The right card swells and the chosen wrong one shrinks back, so the
      // answer is felt before it is read. Colour alone asked a child to know
      // that green means yes.
      child: AnimatedScale(
        scale: switch (state) {
          _OptionState.correct => 1.06,
          _OptionState.wrong => 0.96,
          _OptionState.idle => 1,
        },
        duration: PlayMotion.springBack,
        curve: Curves.elasticOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: fill.withValues(alpha: marked ? 0.18 : 0.12),
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
      ),
    );
  }

  Widget _content() {
    final label = option.label;
    if (label != null && label.isNotEmpty) {
      // The packs name Urdu letters in Latin — "Bay" — as an identifier. The
      // activities have always drawn the script instead; the quiz was showing
      // the identifier, so the same round asked in Urdu and answered in
      // "Bay".
      final glyph = UrduLetters.glyphFor(label);
      return Directionality(
        textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: Text(
          glyph ?? label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: glyph == null ? 'Fredoka' : 'NotoNastaliqUrdu',
            fontSize: glyph == null ? 36 : 42,
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

class _QuizResult extends StatefulWidget {
  const _QuizResult({required this.accent});

  final Color accent;

  @override
  State<_QuizResult> createState() => _QuizResultState();
}

class _QuizResultState extends State<_QuizResult> {
  /// So the fanfare plays once, not on every rebuild of the result.
  bool _sounded = false;

  Color get accent => widget.accent;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ModuleQuizViewModel>();
    final passed = vm.passed;

    // The end of a module is the biggest moment the app has, and it arrived in
    // silence: the sound for it already existed and nothing ever played it.
    // Only on a pass — a fanfare over "try again" would be celebrating the
    // wrong thing.
    if (passed && !_sounded) {
      _sounded = true;
      AppSound.play(Sfx.moduleComplete);
    }

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
                  icon: passed ? Icons.check_rounded : Icons.refresh_rounded,
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
