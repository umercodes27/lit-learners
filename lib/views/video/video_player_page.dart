import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../../core/routing/app_router.dart';
import '../../core/routing/route_names.dart';
import '../../viewmodels/active_child_session.dart';
import '../../viewmodels/learning_viewmodel.dart';
import '../../widgets/play/play.dart';
import '../../services/audio/sound_controller.dart';

/// One video lesson, in a frame built for a four-year-old.
///
/// The screen used to be a Material scaffold with an app bar, a card and a
/// small filled icon button — the only child-facing screen in the app that
/// looked like a form. It is now the play kit like everywhere else: a painted
/// ground, the film in a rounded frame, one large round play control, and a
/// scrub bar thick enough to actually hit.
///
/// The films are shot portrait, so the frame is capped at just over half the
/// screen. Left to fill the width, a 9:16 video is taller than the phone and
/// pushes the controls below the fold.
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
    // The bed drops to a whisper rather than stopping: a lesson that ends
    // into silence feels like the app died.
    AppSound.instance.duck();
    // A lesson either names a file bundled with the app or a remote URL. The
    // bundled ones are what ships today, and they are the only ones that play
    // with no connection; the network branch stays for lessons an admin
    // publishes through Firestore.
    final source = widget.args.lesson.videoUrl;
    _controller = source.startsWith('assets/')
        ? VideoPlayerController.asset(source)
        : VideoPlayerController.networkUrl(Uri.parse(source));
    _initialize = _controller.initialize().then((_) {
      if (mounted) setState(() {});
    });
    _controller.setLooping(false);
    // Redraws the play control and the scrub bar as the film runs.
    _controller.addListener(_onTick);
  }

  void _onTick() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    AppSound.instance.unduck();
    _controller.removeListener(_onTick);
    _controller.dispose();
    super.dispose();
  }

  void _togglePlay() {
    if (!_controller.value.isInitialized) return;
    setState(() {
      if (_controller.value.isPlaying) {
        _controller.pause();
      } else {
        // Watching it again from the top is the usual reason a child taps
        // play on a finished film.
        if (_controller.value.position >= _controller.value.duration) {
          _controller.seekTo(Duration.zero);
        }
        _controller.play();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final lesson = widget.args.lesson;
    final ground = PlayColors.forModuleId('video');

    return Scaffold(
      body: PlayGround(
        color: ground,
        safeArea: false,
        child: SafeArea(
          child: Column(
            children: [
              PlayHeader(
                title: lesson.title,
                subtitle: lesson.durationLabel,
                onBack: () => Navigator.of(context).maybePop(),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                  child: Column(
                    children: [
                      _Frame(
                        controller: _controller,
                        initialize: _initialize,
                        onTapVideo: _togglePlay,
                      ),
                      const SizedBox(height: 16),
                      if (_controller.value.isInitialized)
                        _Controls(
                          controller: _controller,
                          onTogglePlay: _togglePlay,
                        ),
                      const SizedBox(height: 14),
                      PlayPanel(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          lesson.description,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: 'Fredoka',
                            fontSize: 17,
                            height: 1.3,
                            fontWeight: FontWeight.w600,
                            color: PlayColors.ink,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      PlayButton(
                        label: 'I watched it!',
                        icon: Icons.check_circle_rounded,
                        color: PlayColors.grass,
                        big: true,
                        onPressed: () => _markWatched(context),
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

  Future<void> _markWatched(BuildContext context) async {
    final child = context.read<ActiveChildSession>().activeChild;
    final learning = context.read<LearningViewModel>();
    final level = await learning.levelById(widget.args.levelId);

    if (!context.mounted || child == null || level == null) return;

    await _controller.pause();
    await learning.recordVideoWatched(
      childId: child.id,
      level: level,
      lessonId: widget.args.lesson.id,
    );
    if (!context.mounted) return;

    // Video lessons carry no quiz: watching one is the whole activity, and a
    // quiz on a film a four-year-old just saw tests memory rather than
    // teaching anything.
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

/// The film itself, in a rounded frame with a tap-anywhere play overlay.
class _Frame extends StatelessWidget {
  const _Frame({
    required this.controller,
    required this.initialize,
    required this.onTapVideo,
  });

  final VideoPlayerController controller;
  final Future<void> initialize;
  final VoidCallback onTapVideo;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: Container(
        decoration: BoxDecoration(
          color: PlayColors.ink,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.white, width: 4),
        ),
        clipBehavior: Clip.antiAlias,
        child: FutureBuilder<void>(
          future: initialize,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const AspectRatio(
                aspectRatio: 3 / 4,
                child: Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              );
            }

            if (snapshot.hasError || !controller.value.isInitialized) {
              return AspectRatio(
                aspectRatio: 3 / 4,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'This lesson would not open.\nTry it again in a moment.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Fredoka',
                        fontSize: 17,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ),
                ),
              );
            }

            final playing = controller.value.isPlaying;

            return GestureDetector(
              onTap: onTapVideo,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.52,
                ),
                child: AspectRatio(
                  aspectRatio: controller.value.aspectRatio,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      VideoPlayer(controller),
                      // A resting film says so. Once it is running the badge
                      // gets out of the way.
                      AnimatedOpacity(
                        duration: const Duration(milliseconds: 220),
                        opacity: playing ? 0 : 1,
                        child: Container(
                          width: 84,
                          height: 84,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.92),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.play_arrow_rounded,
                            size: 54,
                            color: PlayColors.ink,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Play, and a scrub bar thick enough for a small finger.
class _Controls extends StatelessWidget {
  const _Controls({required this.controller, required this.onTogglePlay});

  final VideoPlayerController controller;
  final VoidCallback onTogglePlay;

  static String _clock(Duration d) {
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final value = controller.value;
    final playing = value.isPlaying;

    return Row(
      children: [
        Squishy(
          onTap: onTogglePlay,
          semanticLabel: playing ? 'Pause' : 'Play',
          child: Container(
            width: 68,
            height: 68,
            decoration: const BoxDecoration(
              color: PlayColors.sunshine,
              shape: BoxShape.circle,
            ),
            child: Icon(
              playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
              size: 42,
              color: PlayColors.ink,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: VideoProgressIndicator(
                  controller,
                  allowScrubbing: true,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  colors: VideoProgressColors(
                    playedColor: PlayColors.sunshine,
                    bufferedColor: Colors.white.withValues(alpha: 0.6),
                    backgroundColor: Colors.white.withValues(alpha: 0.35),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${_clock(value.position)} / ${_clock(value.duration)}',
                style: TextStyle(
                  fontFamily: 'Fredoka',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: PlayColors.ink.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
