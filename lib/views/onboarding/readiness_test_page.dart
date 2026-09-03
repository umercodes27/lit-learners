import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/localization/onboarding_strings.dart';
import '../../core/routing/auth_flow_router.dart';
import '../../models/onboarding.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/onboarding_viewmodel.dart';
import '../../widgets/app_primary_button.dart';
import 'widgets/onboarding_language_toggle.dart';

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

    return Scaffold(
      appBar: AppBar(
        title: Directionality(
          textDirection: language.textDirection,
          child: Text(
            strings.testTitle,
            style: language.styleFor(null),
          ),
        ),
        actions: const [
          OnboardingLanguageToggle(),
          SizedBox(width: 12),
        ],
      ),
      body: SafeArea(
        child: Directionality(
          textDirection: language.textDirection,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.grape, AppColors.violet],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.honey,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.fact_check_rounded,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        strings.passingBannerFor(
                          OnboardingViewModel.passingScore,
                        ),
                        textAlign: language.textAlign,
                        style: language.styleFor(
                          Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                height: language.bodyLineHeight,
                              ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              for (var index = 0; index < onboarding.questions.length; index++)
                _ReadinessQuestionCard(
                  questionNumber: index + 1,
                  question: onboarding.questions[index],
                  language: language,
                  optionOrder:
                      _optionOrderByQuestionId[onboarding.questions[index].id] ??
                          const [],
                  selectedAnswer: onboarding
                      .selectedAnswerFor(onboarding.questions[index].id),
                  onChanged: (value) {
                    context.read<OnboardingViewModel>().selectAnswer(
                          onboarding.questions[index].id,
                          value,
                        );
                  },
                ),
              if (onboarding.latestPassed == false) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.lemon.withValues(alpha: 0.82),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: AppColors.honey.withValues(alpha: 0.62),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        strings.scoreLabelFor(onboarding.latestScore ?? 0),
                        textAlign: language.textAlign,
                        style: language.styleFor(
                          Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        strings.reviewTips,
                        textAlign: language.textAlign,
                        style: language.styleFor(null),
                      ),
                      const SizedBox(height: 8),
                      for (final question in onboarding.questions)
                        if (onboarding.selectedAnswerFor(question.id) !=
                            question.correctIndex)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text(
                              '- ${question.tip}',
                              textAlign: language.textAlign,
                              style: language.styleFor(
                                TextStyle(height: language.bodyLineHeight),
                              ),
                            ),
                          ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () {
                    context.read<OnboardingViewModel>().resetReadinessAttempt();
                  },
                  icon: const Icon(Icons.refresh),
                  label: Text(
                    strings.retakeTest,
                    style: language.styleFor(null),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              AppPrimaryButton(
                icon: Icons.check_circle,
                label: strings.submitTest,
                labelStyle: language.styleFor(null),
                onPressed: onboarding.allQuestionsAnswered
                    ? () => _submit(context, parent.id, strings)
                    : null,
              ),
            ],
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

class _ReadinessQuestionCard extends StatelessWidget {
  const _ReadinessQuestionCard({
    required this.questionNumber,
    required this.question,
    required this.language,
    required this.optionOrder,
    required this.selectedAnswer,
    required this.onChanged,
  });

  final int questionNumber;
  final ReadinessQuestion question;
  final OnboardingLanguage language;
  final List<int> optionOrder;
  final int? selectedAnswer;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.lilac.withValues(alpha: 0.52)),
        boxShadow: [
          BoxShadow(
            color: AppColors.grape.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.coral.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$questionNumber',
                  style: const TextStyle(
                    color: AppColors.coral,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  question.prompt,
                  textAlign: language.textAlign,
                  style: language.styleFor(
                    Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          height: language.bodyLineHeight,
                        ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          RadioGroup<int>(
            groupValue: selectedAnswer,
            onChanged: (value) {
              if (value == null) return;
              onChanged(value);
            },
            child: Column(
              children: [
                for (final optionIndex in optionOrder)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _ReadinessOptionTile(
                      value: optionIndex,
                      label: question.options[optionIndex],
                      language: language,
                      selected: selectedAnswer == optionIndex,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReadinessOptionTile extends StatelessWidget {
  const _ReadinessOptionTile({
    required this.value,
    required this.label,
    required this.language,
    required this.selected,
  });

  final int value;
  final String label;
  final OnboardingLanguage language;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    // A Material rather than a DecoratedBox: RadioListTile paints its ink
    // splash on the nearest Material ancestor, so a plain decorated box would
    // sit on top of the splash and hide it.
    return Material(
      color: selected ? AppColors.lavender : AppColors.cloud,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: selected ? AppColors.plum : AppColors.line,
        ),
      ),
      child: RadioListTile<int>(
        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
        value: value,
        activeColor: AppColors.plum,
        title: Text(
          label,
          textAlign: language.textAlign,
          style: language.styleFor(
            TextStyle(
              fontWeight: FontWeight.w700,
              height: language.bodyLineHeight,
            ),
          ),
        ),
      ),
    );
  }
}
