import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/routing/app_router.dart';
import '../../core/routing/route_names.dart';
import '../../core/utils/learning_text_direction.dart';
import '../../models/koala_guide_message.dart';
import '../../models/learning_level.dart';
import '../../viewmodels/active_child_session.dart';
import '../../viewmodels/learning_viewmodel.dart';
import '../../viewmodels/quiz_viewmodel.dart';
import '../../widgets/app_primary_button.dart';
import '../../widgets/koala_guide.dart';

class QuizPage extends StatefulWidget {
  const QuizPage({
    required this.levelId,
    super.key,
  });

  final String levelId;

  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  late final Future<LearningLevel?> _levelFuture;

  @override
  void initState() {
    super.initState();
    _levelFuture = context.read<LearningViewModel>().levelById(widget.levelId);
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
          child: _QuizBody(level: level),
        );
      },
    );
  }
}

class _QuizBody extends StatelessWidget {
  const _QuizBody({required this.level});

  final LearningLevel level;

  @override
  Widget build(BuildContext context) {
    final quiz = context.watch<QuizViewModel>();
    final question = quiz.currentQuestion;
    final textDirection = LearningTextDirection.forLevel(level);

    return Scaffold(
      appBar: AppBar(title: const Text('Quick Check')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            LinearProgressIndicator(
              value: (quiz.questionIndex + 1) / quiz.totalQuestions,
            ),
            const SizedBox(height: 16),
            Text(
              'Question ${quiz.questionIndex + 1} of ${quiz.totalQuestions}',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            ContextualKoalaGuide(
              trigger: KoalaGuideTrigger.quizStart,
              audience: KoalaGuideAudience.child,
              moduleId: level.moduleId,
              levelId: level.id,
              stage: level.stage,
              fallbackMessage: 'Quick check. Think first, then choose.',
              textDirection: textDirection,
            ),
            const SizedBox(height: 8),
            Directionality(
              textDirection: textDirection,
              child: Text(
                question.prompt,
                textAlign: LearningTextDirection.alignFor(textDirection),
                style: LearningTextDirection.styleFor(
                  Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                  textDirection,
                ),
              ),
            ),
            if (question.visualLabel != null) ...[
              const SizedBox(height: 12),
              Card(
                child: SizedBox(
                  height: 120,
                  child: Center(
                    child: Directionality(
                      textDirection: LearningTextDirection.forText(
                        question.visualLabel!,
                      ),
                      child: Text(
                        question.visualLabel!,
                        style: LearningTextDirection.styleForText(
                          null,
                          question.visualLabel!,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            for (var i = 0; i < question.options.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: OutlinedButton(
                  onPressed: () =>
                      context.read<QuizViewModel>().selectAnswer(i),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: _optionColor(context, quiz, i),
                  ),
                  child: Align(
                    alignment: textDirection == TextDirection.rtl
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Directionality(
                      textDirection: LearningTextDirection.forText(
                        question.options[i],
                      ),
                      child: Text(
                        question.options[i],
                        style: LearningTextDirection.styleForText(
                          null,
                          question.options[i],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            if (quiz.answered && question.explanation != null) ...[
              const SizedBox(height: 8),
              Directionality(
                textDirection: LearningTextDirection.forText(
                  question.explanation!,
                ),
                child: Text(
                  question.explanation!,
                  textAlign: LearningTextDirection.alignFor(
                    LearningTextDirection.forText(question.explanation!),
                  ),
                  style: LearningTextDirection.styleForText(
                    null,
                    question.explanation!,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            AppPrimaryButton(
              icon: quiz.isLastQuestion ? Icons.flag : Icons.arrow_forward,
              label: quiz.isLastQuestion ? 'Finish quiz' : 'Next question',
              onPressed: !quiz.answered
                  ? null
                  : () {
                      if (quiz.isLastQuestion) {
                        _finishQuiz(context, quiz);
                      } else {
                        context.read<QuizViewModel>().nextQuestion();
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }

  Color? _optionColor(BuildContext context, QuizViewModel quiz, int index) {
    if (!quiz.answered) return null;

    final question = quiz.currentQuestion;
    if (index == question.correctIndex) {
      return Colors.green.withValues(alpha: 0.12);
    }
    if (quiz.selectedIndex == index) {
      return Colors.red.withValues(alpha: 0.12);
    }
    return null;
  }

  Future<void> _finishQuiz(BuildContext context, QuizViewModel quiz) async {
    final child = context.read<ActiveChildSession>().activeChild;
    if (child == null) return;

    if (!quiz.passed) {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Try again'),
            content: Text(
              'Score: ${quiz.scorePercent}%. You need ${level.passingScore}% '
              'to pass this level.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Keep practicing'),
              ),
            ],
          );
        },
      );
      if (context.mounted) {
        context.read<QuizViewModel>().restart();
      }
      return;
    }

    final progress = await context.read<LearningViewModel>().completeLevel(
          child.id,
          level,
          score: quiz.scorePercent,
        );
    if (!context.mounted) return;

    Navigator.of(context).pushReplacementNamed(
      RouteNames.celebration,
      arguments: CelebrationArgs(
        moduleId: level.moduleId,
        levelTitle: level.title,
        starsEarned: progress.starsEarned,
        score: quiz.scorePercent,
      ),
    );
  }
}
