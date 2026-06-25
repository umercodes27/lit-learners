import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/routing/route_names.dart';
import '../../core/utils/age_stage_helper.dart';
import '../../core/utils/learning_text_direction.dart';
import '../../models/koala_guide_message.dart';
import '../../viewmodels/active_child_session.dart';
import '../../viewmodels/learning_viewmodel.dart';
import '../../widgets/koala_guide.dart';
import '../../widgets/locked_overlay.dart';
import '../../widgets/star_rating.dart';

class ModuleLevelsPage extends StatefulWidget {
  const ModuleLevelsPage({
    required this.moduleId,
    super.key,
  });

  final String moduleId;

  @override
  State<ModuleLevelsPage> createState() => _ModuleLevelsPageState();
}

class _ModuleLevelsPageState extends State<ModuleLevelsPage> {
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
    final textDirection = module == null
        ? TextDirection.ltr
        : LearningTextDirection.forModule(module);
    final learningTextStyle = LearningTextDirection.styleFor(
      null,
      textDirection,
    );

    return Scaffold(
      appBar: AppBar(
        title: Directionality(
          textDirection: textDirection,
          child: Text(
            module?.title ?? 'Levels',
            style: learningTextStyle,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: levels.length + 1,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            if (index == 0) {
              return ContextualKoalaGuide(
                trigger: KoalaGuideTrigger.moduleIntro,
                audience: KoalaGuideAudience.child,
                moduleId: widget.moduleId,
                stage: child == null
                    ? null
                    : AgeStageHelper.stageForAge(child.age),
                textDirection: textDirection,
                fallbackMessage: module?.description ??
                    'Choose a level and try one short activity.',
              );
            }

            final level = levels[index - 1];
            final canOpen = learning.canOpenLevel(level);
            final canDownload = learning.canDownloadLevel(level);
            final reason = learning.lockReasonFor(level);

            return Stack(
              children: [
                Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(12),
                    leading: CircleAvatar(
                      child: Text(level.levelNumber.toString()),
                    ),
                    title: Directionality(
                      textDirection: textDirection,
                      child: Text(
                        level.title,
                        textAlign:
                            LearningTextDirection.alignFor(textDirection),
                        style: LearningTextDirection.styleFor(
                          null,
                          textDirection,
                        ),
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: textDirection == TextDirection.rtl
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,
                      children: [
                        Directionality(
                          textDirection: textDirection,
                          child: Text(
                            level.subtitle,
                            textAlign:
                                LearningTextDirection.alignFor(textDirection),
                            style: LearningTextDirection.styleFor(
                              null,
                              textDirection,
                            ),
                          ),
                        ),
                        if (canDownload) ...[
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: () async {
                              await context
                                  .read<LearningViewModel>()
                                  .downloadLevel(level);
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('${level.title} downloaded.'),
                                ),
                              );
                            },
                            icon: const Icon(Icons.download),
                            label: const Text('Download'),
                          ),
                        ],
                      ],
                    ),
                    trailing: StarRating(count: learning.starsFor(level.id)),
                    onTap: () {
                      if (!canOpen) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(reason)),
                        );
                        return;
                      }
                      Navigator.of(context).pushNamed(
                        RouteNames.levelPlayer,
                        arguments: level.id,
                      );
                    },
                  ),
                ),
                if (!canOpen && !canDownload) LockedOverlay(reason: reason),
              ],
            );
          },
        ),
      ),
    );
  }
}
