import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/routing/app_router.dart';
import '../../core/routing/route_names.dart';
import '../../core/utils/age_stage_helper.dart';
import '../../models/koala_guide_message.dart';
import '../../viewmodels/active_child_session.dart';
import '../../viewmodels/learning_viewmodel.dart';
import '../../widgets/koala_guide.dart';
import '../../widgets/locked_overlay.dart';
import '../../widgets/star_rating.dart';

class VideoLearningPage extends StatefulWidget {
  const VideoLearningPage({
    required this.moduleId,
    super.key,
  });

  final String moduleId;

  @override
  State<VideoLearningPage> createState() => _VideoLearningPageState();
}

class _VideoLearningPageState extends State<VideoLearningPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LearningViewModel>().loadLevelsForModule(widget.moduleId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final learning = context.watch<LearningViewModel>();
    final child = context.watch<ActiveChildSession>().activeChild;
    final module = learning.moduleById(widget.moduleId);
    final levels = learning.levelsFor(widget.moduleId);

    return Scaffold(
      appBar: AppBar(title: Text(module?.title ?? 'Video Learning')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ContextualKoalaGuide(
              trigger: KoalaGuideTrigger.moduleIntro,
              audience: KoalaGuideAudience.child,
              moduleId: widget.moduleId,
              stage:
                  child == null ? null : AgeStageHelper.stageForAge(child.age),
              fallbackMessage:
                  'Watch one short lesson at a time, then answer a tiny '
                  'quiz to earn stars.',
            ),
            const SizedBox(height: 16),
            for (final level in levels)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Stack(
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  child: Text(level.levelNumber.toString()),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        level.title,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w800,
                                            ),
                                      ),
                                      Text(level.subtitle),
                                    ],
                                  ),
                                ),
                                StarRating(count: learning.starsFor(level.id)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            for (final lesson in level.videoLessons)
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.play_circle_fill),
                                title: Text(lesson.title),
                                subtitle: Text(
                                  '${lesson.durationLabel} - '
                                  '${lesson.description}',
                                ),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () {
                                  if (!learning.canOpenLevel(level)) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          learning.lockReasonFor(level),
                                        ),
                                      ),
                                    );
                                    return;
                                  }
                                  Navigator.of(context).pushNamed(
                                    RouteNames.videoPlayer,
                                    arguments: VideoPlayerArgs(
                                      levelId: level.id,
                                      lesson: lesson,
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                    if (!learning.canOpenLevel(level))
                      LockedOverlay(reason: learning.lockReasonFor(level)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
