import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
      return const Scaffold(
        body: Center(child: Text('No active learner selected.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Hello, ${child.name}'),
        actions: [
          IconButton(
            tooltip: 'Switch profile',
            onPressed: () {
              session.clear();
              Navigator.of(context).pushReplacementNamed(RouteNames.profiles);
            },
            icon: const Icon(Icons.switch_account),
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
            const SizedBox(height: 16),
            if (learning.isLoading)
              const Center(child: CircularProgressIndicator())
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: learning.modules.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.92,
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
              ),
          ],
        ),
      ),
    );
  }
}
