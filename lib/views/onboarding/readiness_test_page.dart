import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/routing/route_names.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/onboarding_viewmodel.dart';
import '../../widgets/app_primary_button.dart';

class ReadinessTestPage extends StatelessWidget {
  const ReadinessTestPage({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();
    final onboarding = context.watch<OnboardingViewModel>();
    final parent = auth.parent;

    if (parent == null) {
      return const Scaffold(body: Center(child: Text('Parent not signed in.')));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Readiness Test')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Score ${OnboardingViewModel.passingScore}% or more to continue.',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 14),
            for (final question in onboarding.questions)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          question.prompt,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                        ),
                        const SizedBox(height: 8),
                        RadioGroup<int>(
                          groupValue: onboarding.selectedAnswerFor(
                            question.id,
                          ),
                          onChanged: (value) {
                            if (value == null) return;
                            context.read<OnboardingViewModel>().selectAnswer(
                                  question.id,
                                  value,
                                );
                          },
                          child: Column(
                            children: [
                              for (var i = 0; i < question.options.length; i++)
                                RadioListTile<int>(
                                  contentPadding: EdgeInsets.zero,
                                  value: i,
                                  title: Text(question.options[i]),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (onboarding.latestPassed == false) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Score: ${onboarding.latestScore}%',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                      ),
                      const SizedBox(height: 8),
                      const Text('Review these tips, then try again.'),
                      const SizedBox(height: 8),
                      for (final question in onboarding.questions)
                        if (onboarding.selectedAnswerFor(question.id) !=
                            question.correctIndex)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text('- ${question.tip}'),
                          ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {
                  context.read<OnboardingViewModel>().resetReadinessAttempt();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Retake test'),
              ),
              const SizedBox(height: 12),
            ],
            AppPrimaryButton(
              icon: Icons.check_circle,
              label: 'Submit test',
              onPressed: onboarding.allQuestionsAnswered
                  ? () => _submit(context, parent.id)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit(BuildContext context, String parentId) async {
    final passed =
        await context.read<OnboardingViewModel>().submitReadinessTest(parentId);
    if (!context.mounted) return;

    if (passed) {
      Navigator.of(context).pushReplacementNamed(RouteNames.profiles);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Readiness score needs another try.')),
    );
  }
}
