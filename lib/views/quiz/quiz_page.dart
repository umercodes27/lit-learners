import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../core/routing/app_router.dart';
import '../../core/routing/route_names.dart';
import '../../core/utils/learning_text_direction.dart';
import '../../models/koala_guide_message.dart';
import '../../models/learning_level.dart';
import '../../models/quiz_question.dart';
import '../../viewmodels/active_child_session.dart';
import '../../viewmodels/learning_viewmodel.dart';
import '../../viewmodels/quiz_viewmodel.dart';
import '../../widgets/koala_guide.dart';
import '../../services/audio/app_sounds.dart';
import '../../services/audio/sound_controller.dart';
import '../../widgets/play/play.dart';

class QuizPage extends StatefulWidget {
  const QuizPage({
    required this.args,
    super.key,
  });

  final QuizArgs args;

  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  late final Future<LearningLevel?> _levelFuture;

  @override
  void initState() {
    super.initState();
    _levelFuture =
        context.read<LearningViewModel>().levelById(widget.args.levelId);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<LearningLevel?>(
      future: _levelFuture,
      builder: (context, snapshot) {
        final level = snapshot.data;

        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (level == null || level.quizQuestions.isEmpty) {
          return const Scaffold(
            body: Center(child: Text('Quiz not available.')),
          );
        }

        return ChangeNotifierProvider(
          create: (_) => QuizViewModel(level),
          child: _QuizBody(
            level: level,
            parentMark: widget.args.parentMark,
          ),
        );
      },
    );
  }
}

/// The quiz, rebuilt for children who cannot read a form.
///
/// The answers used to be a vertical stack of left-aligned `OutlinedButton`s
/// with a disabled "Next question" button underneath — a web form, given to a
/// two-year-old. They are now big square cards in a grid, and answering
/// advances by itself, so nothing depends on finding a small control.
///
/// The scoring rules are untouched: `QuizViewModel.selectAnswer` still locks
/// after the first choice. Letting a child retry until correct would change
/// what a score means, and with it level passing, stars and progress — that is
/// a product decision, not a restyle.
class _QuizBody extends StatefulWidget {
  const _QuizBody({
    required this.level,
    this.parentMark,
  });

  final LearningLevel level;
  final int? parentMark;

  @override
  State<_QuizBody> createState() => _QuizBodyState();
}

class _QuizBodyState extends State<_QuizBody> {
  Timer? _advanceTimer;
  int? _celebratingIndex;

  @override
  void dispose() {
    _advanceTimer?.cancel();
    super.dispose();
  }

  Color get _accent => PlayColors.forModuleId(widget.level.moduleId);

  void _answer(QuizViewModel quiz, int index) {
    if (quiz.answered) return;

    final correct = quiz.currentQuestion.isCorrect(index);
    AppSound.play(correct ? Sfx.quizCorrect : Sfx.quizWrong);
    quiz.selectAnswer(index);
    setState(() => _celebratingIndex = correct ? index : null);

    // Answering moves the quiz on by itself. A wrong answer gets longer,
    // because the correct card is lighting up and that is the teaching moment.
    _advanceTimer?.cancel();
    _advanceTimer = Timer(
      Duration(milliseconds: correct ? 1150 : 1900),
      () {
        if (!mounted) return;
        setState(() => _celebratingIndex = null);
        if (quiz.isLastQuestion) {
          _finishQuiz(context, quiz);
        } else {
          quiz.nextQuestion();
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final quiz = context.watch<QuizViewModel>();
    final question = quiz.currentQuestion;
    final textDirection = LearningTextDirection.forLevel(widget.level);
    final accent = _accent;

    return Scaffold(
      body: PlayGround(
        color: accent,
        safeArea: false,
        child: SafeArea(
          child: Stack(
            children: [
              ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                children: [
                  _QuizHeader(
                    quiz: quiz,
                    accent: accent,
                    parentMark: widget.parentMark,
                    onClose: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(height: 14),
                  ContextualKoalaGuide(
                    trigger: KoalaGuideTrigger.quizStart,
                    audience: KoalaGuideAudience.child,
                    moduleId: widget.level.moduleId,
                    levelId: widget.level.id,
                    stage: widget.level.stage,
                    fallbackMessage: 'Quick check. Think first, then choose.',
                    textDirection: textDirection,
                  ),
                  const SizedBox(height: 14),
                  _QuestionCard(
                    key: ValueKey('q${quiz.questionIndex}'),
                    question: question,
                    accent: accent,
                    textDirection: textDirection,
                  ),
                  const SizedBox(height: 16),
                  _AnswerGrid(
                    key: ValueKey('a${quiz.questionIndex}'),
                    quiz: quiz,
                    accent: accent,
                    onAnswer: (index) => _answer(quiz, index),
                  ),
                ],
              ),
              if (_celebratingIndex != null)
                ConfettiBurst(
                  key: ValueKey('burst${quiz.questionIndex}'),
                  pieces: 22,
                  duration: const Duration(milliseconds: 1300),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _finishQuiz(BuildContext context, QuizViewModel quiz) async {
    final child = context.read<ActiveChildSession>().activeChild;
    if (child == null) return;

    final score = QuizViewModel.combineWithParentMark(
      quizPercent: quiz.scorePercent,
      parentMark: widget.parentMark,
    );
    if (score < widget.level.passingScore) {
      await _showTryAgain(context, score);
      if (context.mounted) {
        context.read<QuizViewModel>().restart();
      }
      return;
    }

    final progress = await context.read<LearningViewModel>().completeLevel(
          child.id,
          widget.level,
          score: score,
        );
    if (!context.mounted) return;

    Navigator.of(context).pushReplacementNamed(
      RouteNames.celebration,
      arguments: CelebrationArgs(
        moduleId: widget.level.moduleId,
        levelTitle: widget.level.title,
        starsEarned: progress.starsEarned,
        score: score,
      ),
    );
  }

  /// Not passing is framed as another go, never as a failure. No red, no
  /// percentage in the headline — at this age a hard "you failed" teaches
  /// avoidance of the subject, not the subject.
  Future<void> _showTryAgain(BuildContext context, int score) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: PlayColors.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(PlayMotion.radius),
          ),
          icon: Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: PlayColors.sunshine.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.refresh_rounded,
              size: 46,
              color: PlayColors.sunshine,
            ),
          ),
          title: const Text(
            'Let us try again!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Fredoka',
              fontSize: 26,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Text(
            'You got $score%. A little more practice and this one is yours.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: PlayColors.ink.withValues(alpha: 0.7),
            ),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            Squishy(
              onTap: () => Navigator.of(dialogContext).pop(),
              child: Container(
                height: PlayMotion.minTouchTarget,
                padding: const EdgeInsets.symmetric(horizontal: 30),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: PlayColors.sunshine,
                  borderRadius: BorderRadius.circular(PlayMotion.radius),
                ),
                child: const Text(
                  'Try again',
                  style: TextStyle(
                    fontFamily: 'Fredoka',
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: PlayColors.ink,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Progress as chunky dots rather than a hairline bar, plus the way out.
class _QuizHeader extends StatelessWidget {
  const _QuizHeader({
    required this.quiz,
    required this.accent,
    required this.parentMark,
    required this.onClose,
  });

  final QuizViewModel quiz;
  final Color accent;
  final int? parentMark;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Squishy(
          semanticLabel: 'Go back',
          onTap: onClose,
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: PlayColors.card,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
            ),
            child: Icon(Icons.arrow_back_rounded, color: accent, size: 30),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Row(
            children: List.generate(quiz.totalQuestions, (index) {
              final done = index < quiz.questionIndex;
              final current = index == quiz.questionIndex;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: AnimatedContainer(
                    duration: PlayMotion.pressDown,
                    height: current ? 16 : 12,
                    decoration: BoxDecoration(
                      color: done || current
                          ? PlayColors.sunshine
                          : Colors.white.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(999),
                      border: current
                          ? Border.all(color: Colors.white, width: 2)
                          : null,
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        if (parentMark != null) ...[
          const SizedBox(width: 10),
          _ParentMarkChip(mark: parentMark!),
        ],
      ],
    );
  }
}

/// The parent's own mark, when a grown-up has already scored this level.
class _ParentMarkChip extends StatelessWidget {
  const _ParentMarkChip({required this.mark});

  final int mark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: PlayColors.grass.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: PlayColors.grass.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.how_to_reg_rounded,
              size: 16, color: PlayColors.grass),
          const SizedBox(width: 4),
          Text(
            '$mark%',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: PlayColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    super.key,
    required this.question,
    required this.accent,
    required this.textDirection,
  });

  final QuizQuestion question;
  final Color accent;
  final TextDirection textDirection;

  @override
  Widget build(BuildContext context) {
    return PopIn(
      child: JellyCard(
        color: Colors.white,
        filled: true,
        borderWidth: 4,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
        child: Column(
          children: [
            Directionality(
              textDirection: textDirection,
              child: Text(
                question.prompt,
                textAlign: TextAlign.center,
                style: LearningTextDirection.styleFor(
                  const TextStyle(
                    fontFamily: 'Fredoka',
                    fontSize: 30,
                    height: 1.25,
                    fontWeight: FontWeight.w600,
                    color: PlayColors.ink,
                  ),
                  textDirection,
                ),
              ),
            ),
            if (question.visualLabel != null) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 22),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(PlayMotion.radius),
                ),
                child: Directionality(
                  textDirection:
                      LearningTextDirection.forText(question.visualLabel!),
                  child: Text(
                    question.visualLabel!,
                    textAlign: TextAlign.center,
                    style: LearningTextDirection.styleForText(
                      const TextStyle(
                        fontSize: 44,
                        fontWeight: FontWeight.w700,
                        color: PlayColors.ink,
                      ),
                      question.visualLabel!,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AnswerGrid extends StatelessWidget {
  const _AnswerGrid({
    super.key,
    required this.quiz,
    required this.accent,
    required this.onAnswer,
  });

  final QuizViewModel quiz;
  final Color accent;
  final ValueChanged<int> onAnswer;

  @override
  Widget build(BuildContext context) {
    final question = quiz.currentQuestion;
    final options = question.options;

    // Two columns keeps every card big enough for an imprecise finger. A
    // single long option gets the full width rather than being squeezed.
    final columns = options.length <= 2 ? 1 : 2;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: options.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: columns == 1 ? 3.4 : 1.25,
      ),
      itemBuilder: (context, index) {
        return _AnswerCard(
          index: index,
          label: options[index],
          quiz: quiz,
          accent: accent,
          onAnswer: onAnswer,
        );
      },
    );
  }
}

class _AnswerCard extends StatelessWidget {
  const _AnswerCard({
    required this.index,
    required this.label,
    required this.quiz,
    required this.accent,
    required this.onAnswer,
  });

  final int index;
  final String label;
  final QuizViewModel quiz;
  final Color accent;
  final ValueChanged<int> onAnswer;

  @override
  Widget build(BuildContext context) {
    final answered = quiz.answered;
    final isCorrect = index == quiz.currentQuestion.correctIndex;
    final isChosen = quiz.selectedIndex == index;

    // After answering, the correct card always lights up — including when the
    // child picked something else. Seeing the right answer is the point.
    final revealed = answered && isCorrect;
    final wrongChoice = answered && isChosen && !isCorrect;

    final color = revealed
        ? PlayColors.grass
        : wrongChoice
            ? PlayColors.sunshine
            : accent;

    Widget card = Squishy(
      semanticLabel: label,
      // No tap chirp: the answer replies with its own sound a moment later,
      // and the two on top of each other is mud.
      sound: null,
      onTap: answered ? null : () => onAnswer(index),
      child: Opacity(
        // Untouched wrong options recede rather than being marked wrong.
        opacity: answered && !isCorrect && !isChosen ? 0.45 : 1,
        child: JellyCard(
          color: color,
          filled: true,
          borderWidth: 4,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (revealed) ...[
                  const Icon(
                    Icons.check_circle_rounded,
                    color: Colors.white,
                    size: 38,
                  ),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Directionality(
                    textDirection: LearningTextDirection.forText(label),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        maxLines: 3,
                        style: LearningTextDirection.styleForText(
                          TextStyle(
                            fontFamily: 'Fredoka',
                            fontSize: 32,
                            height: 1.2,
                            fontWeight: FontWeight.w600,
                            color: revealed || wrongChoice
                                ? Colors.white
                                : PlayColors.ink,
                          ),
                          label,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (PlayMotion.reduced(context)) return card;

    if (revealed) {
      card = card.animate().scaleXY(
            begin: 1,
            end: 1.06,
            duration: PlayMotion.pop,
            curve: PlayMotion.springCurve,
          );
    } else if (wrongChoice) {
      // A gentle wobble, not a buzz and not red. It says "not that one",
      // which is all a two-year-old needs from it.
      card = card.animate().shakeX(duration: 500.ms, hz: 4, amount: 5);
    }

    return card;
  }
}
