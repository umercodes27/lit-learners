import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../../core/routing/app_router.dart';
import '../../core/routing/route_names.dart';
import '../../core/utils/age_stage_helper.dart';
import '../../viewmodels/active_child_session.dart';
import '../../viewmodels/learning_viewmodel.dart';
import '../../widgets/app_primary_button.dart';

class VideoPlayerPage extends StatefulWidget {
  const VideoPlayerPage({
    required this.args,
    super.key,
  });

  final VideoPlayerArgs args;

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  late final VideoPlayerController _controller;
  late final Future<void> _initialize;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.args.lesson.videoUrl),
    );
    _initialize = _controller.initialize();
    _controller.setLooping(false);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.args.lesson.title)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: FutureBuilder<void>(
                  future: _initialize,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }

                    if (snapshot.hasError) {
                      return AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Center(
                          child: Text(
                            'Video could not load. Cached video playback will '
                            'be added with the sync module.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      );
                    }

                    return AspectRatio(
                      aspectRatio: _controller.value.aspectRatio,
                      child: VideoPlayer(_controller),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                IconButton.filled(
                  tooltip: _controller.value.isPlaying ? 'Pause' : 'Play',
                  onPressed: () {
                    setState(() {
                      if (_controller.value.isPlaying) {
                        _controller.pause();
                      } else {
                        _controller.play();
                      }
                    });
                  },
                  icon: Icon(
                    _controller.value.isPlaying
                        ? Icons.pause
                        : Icons.play_arrow,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(widget.args.lesson.description),
                ),
              ],
            ),
            const SizedBox(height: 20),
            AppPrimaryButton(
              icon: Icons.check_circle,
              label: 'Mark watched',
              onPressed: () => _markWatched(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _markWatched(BuildContext context) async {
    final child = context.read<ActiveChildSession>().activeChild;
    final learning = context.read<LearningViewModel>();
    final level = await learning.levelById(widget.args.levelId);

    if (!context.mounted || child == null || level == null) return;

    await learning.recordVideoWatched(
      childId: child.id,
      level: level,
      lessonId: widget.args.lesson.id,
    );
    if (!context.mounted) return;

    if (level.quizQuestions.isNotEmpty &&
        AgeStageHelper.shouldShowQuiz(child.age)) {
      Navigator.of(context).pushReplacementNamed(
        RouteNames.quiz,
        arguments: level.id,
      );
      return;
    }

    final progress = await learning.completeLevel(child.id, level);
    if (!context.mounted) return;

    Navigator.of(context).pushReplacementNamed(
      RouteNames.celebration,
      arguments: CelebrationArgs(
        moduleId: level.moduleId,
        levelTitle: level.title,
        starsEarned: progress.starsEarned,
      ),
    );
  }
}
