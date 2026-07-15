import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/routing/route_names.dart';
import '../../core/utils/age_stage_helper.dart';
import '../../models/koala_guide_message.dart';
import '../../models/learning_module.dart';
import '../../viewmodels/active_child_session.dart';
import '../../viewmodels/learning_viewmodel.dart';
import '../../widgets/koala_guide.dart';
import '../../widgets/module_card.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<ActiveChildSession>();
    final learning = context.watch<LearningViewModel>();
    final child = session.activeChild;

    if (child == null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircleAvatar(
                  radius: 34,
                  backgroundColor: AppColors.mint,
                  child: Icon(
                    Icons.child_care,
                    size: 36,
                    color: AppColors.forest,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Choose a learner profile first',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => Navigator.of(context)
                      .pushReplacementNamed(RouteNames.profiles),
                  icon: const Icon(Icons.switch_account),
                  label: const Text('Choose profile'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Hi, ${child.name}!'),
            Text(
              'Ready for a learning adventure?',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.ink.withValues(alpha: 0.62),
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton.filledTonal(
              tooltip: 'Switch profile',
              onPressed: () {
                session.clear();
                Navigator.of(context).pushReplacementNamed(RouteNames.profiles);
              },
              icon: const Icon(Icons.switch_account),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ContextualKoalaGuide(
              trigger: KoalaGuideTrigger.dashboardWelcome,
              audience: KoalaGuideAudience.child,
              stage: AgeStageHelper.stageForAge(child.age),
              fallbackMessage:
                  'Choose a module. Short lessons work best for age '
                  '${child.age}.',
            ),
            const SizedBox(height: 22),
            const _ModuleSectionHeading(),
            const SizedBox(height: 12),
            if (learning.isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(child: CircularProgressIndicator()),
              )
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final columnCount = constraints.maxWidth >= 720
                      ? 4
                      : constraints.maxWidth >= 500
                          ? 3
                          : 2;

                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: learning.modules.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columnCount,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: columnCount == 2 ? 0.86 : 0.9,
                    ),
                    itemBuilder: (context, index) {
                      final module = learning.modules[index];
                      return ModuleCard(
                        module: module,
                        onTap: () {
                          final route = module.category == ModuleCategory.video
                              ? RouteNames.videoLearning
                              : RouteNames.moduleLevels;
                          Navigator.of(context).pushNamed(
                            route,
                            arguments: module.id,
                          );
                        },
                      );
                    },
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _ModuleSectionHeading extends StatelessWidget {
  const _ModuleSectionHeading();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.honey,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.explore_rounded, color: AppColors.ink),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Pick an adventure',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        const Icon(Icons.auto_awesome, color: AppColors.rose),
      ],
    );
  }
}
