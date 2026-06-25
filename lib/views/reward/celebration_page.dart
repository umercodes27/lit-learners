import 'package:flutter/material.dart';

import '../../core/routing/app_router.dart';
import '../../core/routing/route_names.dart';
import '../../models/koala_guide_message.dart';
import '../../widgets/app_primary_button.dart';
import '../../widgets/koala_guide.dart';
import '../../widgets/star_rating.dart';

class CelebrationPage extends StatelessWidget {
  const CelebrationPage({
    required this.args,
    super.key,
  });

  final CelebrationArgs args;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reward')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ContextualKoalaGuide(
              trigger: KoalaGuideTrigger.levelComplete,
              audience: KoalaGuideAudience.child,
              moduleId: args.moduleId,
              fallbackMessage: 'Great work. Your reward is saved.',
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Icon(Icons.emoji_events, size: 72),
                    const SizedBox(height: 12),
                    Text(
                      args.levelTitle,
                      textAlign: TextAlign.center,
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                    ),
                    const SizedBox(height: 10),
                    StarRating(count: args.starsEarned),
                    if (args.score != null) ...[
                      const SizedBox(height: 8),
                      Text('Quiz score: ${args.score}%'),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            AppPrimaryButton(
              icon: Icons.map,
              label: 'Back to levels',
              onPressed: () {
                final route = args.moduleId == 'video'
                    ? RouteNames.videoLearning
                    : RouteNames.moduleLevels;
                Navigator.of(context).pushReplacementNamed(
                  route,
                  arguments: args.moduleId,
                );
              },
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).pushNamedAndRemoveUntil(
                  RouteNames.childHome,
                  (route) => false,
                );
              },
              icon: const Icon(Icons.home),
              label: const Text('Home'),
            ),
          ],
        ),
      ),
    );
  }
}
