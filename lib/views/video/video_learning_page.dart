import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/routing/app_router.dart';
import '../../core/routing/route_names.dart';
import '../../core/utils/age_stage_helper.dart';
import '../../models/koala_guide_message.dart';
import '../../models/learning_level.dart';
import '../../models/video_lesson.dart';
import '../../viewmodels/active_child_session.dart';
import '../../viewmodels/learning_viewmodel.dart';
import '../../services/audio/app_sounds.dart';
import '../../services/audio/sound_controller.dart';
import '../../widgets/koala_guide.dart';
import '../../widgets/play/play.dart';
import '../child_dashboard/widgets/level_map.dart';

/// Video lessons, on the same road every other subject now uses.
///
/// This screen kept its own layout — a column of cards, each unrolling its
/// lessons underneath — which made Video the one subject that did not look
/// like a place a child walks through. It now shares [LevelMap], so its map
/// shape comes from the module id like everywhere else.
///
/// The one thing video does differently: a stop holds several lessons rather
/// than one activity, so tapping a stop asks which lesson to watch.
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
    AppSound.instance.playMusic(MusicTrack.home);
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

    final stops = [
      for (final level in levels)
        LevelStopData(
          level: level,
          stars: learning.starsFor(level.id),
          completed: learning.isLevelCompleted(level.id),
          canOpen: learning.canOpenLevel(level),
          canDownload: learning.canDownloadLevel(level),
          lockReason: learning.lockReasonFor(level),
        ),
    ];
    final done = stops.where((stop) => stop.completed).length;

    return Scaffold(
      body: PlayGround(
        color: PlayColors.bubblegum,
        safeArea: false,
        child: SafeArea(
          child: Column(
            children: [
              PlayHeader(
                title: module?.title ?? 'Video Learning',
                onBack: () => Navigator.of(context).maybePop(),
              ),
              if (stops.isNotEmpty)
                MapProgressBar(done: done, total: stops.length),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                  child: Column(
                    children: [
                      ContextualKoalaGuide(
                        trigger: KoalaGuideTrigger.moduleIntro,
                        audience: KoalaGuideAudience.child,
                        moduleId: widget.moduleId,
                        stage: child == null
                            ? null
                            : AgeStageHelper.stageForAge(child.age),
                        fallbackMessage:
                            'Watch one short lesson at a time, then answer a '
                            'tiny quiz to earn stars.',
                      ),
                      const SizedBox(height: 12),
                      LevelMap(
                        stops: stops,
                        moduleId: widget.moduleId,
                        accent: PlayColors.sunshine,
                        textDirection: TextDirection.ltr,
                        // A video stop is a shelf of lessons, so how many are
                        // inside is worth showing on the map itself.
                        badgeFor: (stop) {
                          final count = stop.level.videoLessons.length;
                          return count <= 1 ? null : '$count';
                        },
                        onOpen: (level) => _openLevel(context, level),
                        onDownload: (level) => _download(context, level),
                        onLocked: (reason) => _showLocked(context, reason),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openLevel(BuildContext context, LearningLevel level) {
    final lessons = level.videoLessons;
    if (lessons.isEmpty) return;
    if (lessons.length == 1) {
      _playLesson(context, level, lessons.first);
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Material(
              color: Colors.transparent,
              child: PlayPanel(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      level.title,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Fredoka',
                        fontSize: 23,
                        height: 1.15,
                        fontWeight: FontWeight.w600,
                        color: PlayColors.ink,
                      ),
                    ),
                    const SizedBox(height: 14),
                    for (final lesson in lessons)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _LessonRow(
                          lesson: lesson,
                          onTap: () {
                            Navigator.of(sheetContext).pop();
                            _playLesson(context, level, lesson);
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _playLesson(
    BuildContext context,
    LearningLevel level,
    VideoLesson lesson,
  ) {
    Navigator.of(context).pushNamed(
      RouteNames.videoPlayer,
      arguments: VideoPlayerArgs(levelId: level.id, lesson: lesson),
    );
  }

  void _showLocked(BuildContext context, String reason) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(reason)));
  }

  Future<void> _download(BuildContext context, LearningLevel level) async {
    await context.read<LearningViewModel>().downloadLevel(level);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${level.title} downloaded.')),
    );
  }
}

/// One lesson to pick from, with a play disc a small finger can hit.
class _LessonRow extends StatelessWidget {
  const _LessonRow({required this.lesson, required this.onTap});

  final VideoLesson lesson;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Squishy(
      semanticLabel: 'Play ${lesson.title}',
      onTap: onTap,
      scale: 0.97,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: PlayColors.cream,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: Colors.white, width: 3),
        ),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: const BoxDecoration(
                color: PlayColors.bubblegum,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 36,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lesson.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Fredoka',
                      fontSize: 19,
                      height: 1.15,
                      fontWeight: FontWeight.w600,
                      color: PlayColors.ink,
                    ),
                  ),
                  Text(
                    '${lesson.durationLabel} · ${lesson.description}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.3,
                      fontWeight: FontWeight.w600,
                      color: PlayColors.ink.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
