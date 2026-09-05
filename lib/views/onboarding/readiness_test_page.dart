import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/localization/onboarding_strings.dart';
import '../../core/routing/auth_flow_router.dart';
import '../../models/onboarding.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/onboarding_viewmodel.dart';
import '../../widgets/play/play.dart';
import 'widgets/onboarding_language_toggle.dart';

/// The readiness test a parent takes before their child gets in.
///
/// This was an `AppBar`, a gradient banner and a stack of `RadioListTile`s in
/// grey boxes — a web form, on the screen that decides whether a family sees
/// the app at all. It was also throwing "ListTile background color or ink
/// splashes may be invisible" on every build, which is what four of the
/// onboarding widget tests had been failing on.
///
/// It is now built from the same parts as the child quiz: a colour ground,
/// white question cards, and answers that fill with colour when chosen. The
/// questions themselves are untouched — content belongs to someone else.
class ReadinessTestPage extends StatefulWidget {
  const ReadinessTestPage({super.key});

  @override
  State<ReadinessTestPage> createState() => _ReadinessTestPageState();
}

class _ReadinessTestPageState extends State<ReadinessTestPage> {
  final Map<String, List<int>> _optionOrderByQuestionId = {};

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();
    final onboarding = context.watch<OnboardingViewModel>();
    final parent = auth.parent;
    final language = onboarding.language;
    final strings = OnboardingStrings.of(language);

    if (parent == null) {
      return Scaffold(body: Center(child: Text(strings.notSignedIn)));
    }

    _ensureShuffledOptions(onboarding.questions);

    final questions = onboarding.questions;
    final answered = questions
        .where((q) => onboarding.selectedAnswerFor(q.id) != null)
        .length;

    return Scaffold(
      body: PlayGround(
        color: PlayColors.blueberry,
        safeArea: false,
        child: SafeArea(
          child: Directionality(
            textDirection: language.textDirection,
            child: Column(
              children: [
                PlayHeader(
                  title: strings.testTitle,
                  textDirection: language.textDirection,
                  titleStyle: language.styleFor(null),
                  onBack: Navigator.of(context).canPop()
                      ? () => Navigator.of(context).maybePop()
                      : null,
                  trailing: const OnboardingLanguageToggle(),
                ),
                _AnsweredBar(answered: answered, total: questions.length),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
                    children: [
                      _PassingBanner(
                        message: strings.passingBannerFor(
                          OnboardingViewModel.passingScore,
                        ),
                        language: language,
                      ),
                      const SizedBox(height: 16),
                      for (var index = 0; index < questions.length; index++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: PopIn(
                            index: index,
                            child: _QuestionCard(
                              questionNumber: index + 1,
                              question: questions[index],
                              color: PlayColors.byIndex(index),
                              language: language,
                              optionOrder: _optionOrderByQuestionId[
                                      questions[index].id] ??
                                  const [],
                              selectedAnswer: onboarding
                                  .selectedAnswerFor(questions[index].id),
                              onChanged: (value) {
                                context
                                    .read<OnboardingViewModel>()
                                    .selectAnswer(questions[index].id, value);
                              },
                            ),
                          ),
                        ),
                      if (onboarding.latestPassed == false) ...[
                        _RetryCard(
                          onboarding: onboarding,
                          language: language,
                          strings: strings,
                        ),
                        const SizedBox(height: 14),
                      ],
                      PlayButton(
                        icon: Icons.check_rounded,
                        label: strings.submitTest,
                        labelStyle: language.styleFor(null),
                        color: PlayColors.sunshine,
                        big: true,
                        onPressed: onboarding.allQuestionsAnswered
                            ? () => _submit(context, parent.id, strings)
                            : null,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit(
    BuildContext context,
    String parentId,
    OnboardingStrings strings,
  ) async {
    final passed =
        await context.read<OnboardingViewModel>().submitReadinessTest(parentId);
    if (!context.mounted) return;

    if (passed) {
      await AuthFlowRouter.routeToChildArea(
        context: context,
        parentId: parentId,
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(strings.tryAgainMessage)),
    );
  }

  void _ensureShuffledOptions(List<ReadinessQuestion> questions) {
    for (final question in questions) {
      _optionOrderByQuestionId.putIfAbsent(question.id, () {
        final order = List<int>.generate(question.options.length, (index) {
          return index;
        });
        final seed = question.id.codeUnits.fold<int>(
          question.options.length,
          (value, unit) => value + unit,
        );
        order.shuffle(Random(seed + DateTime.now().microsecond));
        return order;
      });
    }
  }
}

/// How far through the test the parent is, as a bar and a count.
///
/// Deliberately digits rather than words: this screen runs in English and in
/// Urdu, and "3 of 5" would need a string nobody has written. Numbers read the
/// same in both.
class _AnsweredBar extends StatelessWidget {
  const _AnsweredBar({required this.answered, required this.total});

  final int answered;
  final int total;

  @override
  Widget build(BuildContext context) {
    final progress = total == 0 ? 0.0 : answered / total;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: progress),
                duration: PlayMotion.enter,
                curve: PlayMotion.settleCurve,
                builder: (context, value, _) {
                  return LinearProgressIndicator(
                    value: value,
                    minHeight: 14,
                    color: PlayColors.sunshine,
                    backgroundColor: Colors.white.withValues(alpha: 0.28),
                  );
                },
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '$answered/$total',
            style: const TextStyle(
              fontFamily: 'Fredoka',
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

/// The pass mark, on the koala's card rather than in a gradient banner.
class _PassingBanner extends StatelessWidget {
  const _PassingBanner({required this.message, required this.language});

  final String message;
  final OnboardingLanguage language;

  @override
  Widget build(BuildContext context) {
    return PlayPanel(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: const BoxDecoration(
              color: PlayColors.sunshine,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.fact_check_rounded,
              size: 32,
              color: PlayColors.ink,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              textAlign: language.textAlign,
              style: language.styleFor(
                TextStyle(
                  fontFamily: 'Fredoka',
                  fontSize: 17,
                  height: language.bodyLineHeight,
                  fontWeight: FontWeight.w600,
                  color: PlayColors.ink,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One question: a numbered disc, the prompt, and its answers.
class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    required this.questionNumber,
    required this.question,
    required this.color,
    required this.language,
    required this.optionOrder,
    required this.selectedAnswer,
    required this.onChanged,
  });

  final int questionNumber;
  final ReadinessQuestion question;
  final Color color;
  final OnboardingLanguage language;
  final List<int> optionOrder;
  final int? selectedAnswer;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return PlayPanel(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                child: Text(
                  '$questionNumber',
                  style: TextStyle(
                    fontFamily: 'Fredoka',
                    fontSize: 26,
                    height: 1,
                    fontWeight: FontWeight.w700,
                    color: PlayColors.onGround(color),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  question.prompt,
                  textAlign: language.textAlign,
                  style: language.styleFor(
                    TextStyle(
                      fontFamily: 'Fredoka',
                      fontSize: 20,
                      height: language.bodyLineHeight,
                      fontWeight: FontWeight.w600,
                      color: PlayColors.ink,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          for (final optionIndex in optionOrder)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: PlayChoice(
                label: question.options[optionIndex],
                selected: selectedAnswer == optionIndex,
                color: color,
                textDirection: language.textDirection,
                labelStyle: language.styleFor(null),
                onTap: () => onChanged(optionIndex),
              ),
            ),
        ],
      ),
    );
  }
}

/// Shown after a failed attempt: the score, the tips for the questions that
/// went wrong, and the way to try again.
class _RetryCard extends StatelessWidget {
  const _RetryCard({
    required this.onboarding,
    required this.language,
    required this.strings,
  });

  final OnboardingViewModel onboarding;
  final OnboardingLanguage language;
  final OnboardingStrings strings;

  @override
  Widget build(BuildContext context) {
    final missed = onboarding.questions
        .where((q) => onboarding.selectedAnswerFor(q.id) != q.correctIndex)
        .toList();

    return PlayPanel(
      color: PlayColors.cream,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(
                  color: PlayColors.tangerine,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.replay_rounded,
                  size: 30,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  strings.scoreLabelFor(onboarding.latestScore ?? 0),
                  textAlign: language.textAlign,
                  style: language.styleFor(
                    const TextStyle(
                      fontFamily: 'Fredoka',
                      fontSize: 21,
                      fontWeight: FontWeight.w600,
                      color: PlayColors.ink,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            strings.reviewTips,
            textAlign: language.textAlign,
            style: language.styleFor(
              TextStyle(
                fontSize: 15,
                height: language.bodyLineHeight,
                fontWeight: FontWeight.w700,
                color: PlayColors.ink.withValues(alpha: 0.7),
              ),
            ),
          ),
          const SizedBox(height: 10),
          for (final question in missed)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    margin: const EdgeInsets.only(top: 6),
                    decoration: const BoxDecoration(
                      color: PlayColors.tangerine,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      question.tip,
                      textAlign: language.textAlign,
                      style: language.styleFor(
                        TextStyle(
                          fontSize: 15,
                          height: language.bodyLineHeight,
                          fontWeight: FontWeight.w600,
                          color: PlayColors.ink,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 6),
          PlayButton(
            icon: Icons.refresh_rounded,
            label: strings.retakeTest,
            labelStyle: language.styleFor(null),
            color: PlayColors.tangerine,
            onPressed: () {
              context.read<OnboardingViewModel>().resetReadinessAttempt();
            },
          ),
        ],
      ),
    );
  }
}
