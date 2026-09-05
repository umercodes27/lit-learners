import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/routing/app_router.dart';
import '../../core/routing/route_names.dart';
import '../../core/utils/age_stage_helper.dart';
import '../../core/utils/learning_text_direction.dart';
import '../../models/canvas_work.dart';
import '../../models/koala_guide_message.dart';
import '../../models/learning_level.dart';
import '../../models/parent_mark.dart';
import '../../viewmodels/active_child_session.dart';
import '../../viewmodels/learning_viewmodel.dart';
import '../../viewmodels/level_activity_viewmodel.dart';
import '../../widgets/koala_guide.dart';
import '../../widgets/play/play.dart';
import 'canvas_level_view.dart';
import 'widgets/activity_chrome.dart';

class LevelPlayerPage extends StatefulWidget {
  const LevelPlayerPage({
    required this.levelId,
    super.key,
  });

  final String levelId;

  @override
  State<LevelPlayerPage> createState() => _LevelPlayerPageState();
}

class _LevelPlayerPageState extends State<LevelPlayerPage> {
  late final Future<LearningLevel?> _levelFuture;

  @override
  void initState() {
    super.initState();
    _levelFuture = context.read<LearningViewModel>().levelById(widget.levelId);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<LearningLevel?>(
      future: _levelFuture,
      builder: (context, snapshot) {
        final level = snapshot.data;
        final textDirection = level == null
            ? TextDirection.ltr
            : LearningTextDirection.forLevel(level);

        final ground = level == null
            ? PlayColors.blueberry
            : PlayColors.forModuleId(level.moduleId);

        return Scaffold(
          body: PlayGround(
            color: ground,
            safeArea: false,
            child: SafeArea(
              child: Column(
                children: [
                  _PlayerHeader(
                    title: level?.title ?? 'Level',
                    textDirection: textDirection,
                    onBack: () => Navigator.of(context).maybePop(),
                  ),
                  Expanded(
                    child: snapshot.connectionState != ConnectionState.done
                        ? const Center(child: CircularProgressIndicator())
                        : level == null
                            ? const Center(child: Text('Level not found.'))
                            : ChangeNotifierProvider(
                                create: (_) => LevelActivityViewModel(level),
                                child: _LevelBody(level: level),
                              ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _LevelBody extends StatelessWidget {
  const _LevelBody({required this.level});

  final LearningLevel level;

  @override
  Widget build(BuildContext context) {
    final child = context.watch<ActiveChildSession>().activeChild;
    final activity = context.watch<LevelActivityViewModel>();
    final canFinish = child != null && activity.isActivityComplete;

    // Canvas activities take over the whole body: they need the height, and a
    // drawing surface inside a scrolling list would fight the scroll gesture.
    // Both hand their finished pages to a grown-up to mark rather than
    // finishing the level themselves.
    if (level.type == LevelType.drawing) {
      return DrawingLevelView(
        level: level,
        onFinish: canFinish
            ? (work) => _markCanvasWork(context, child.id, work, activity)
            : null,
      );
    }
    if (level.type == LevelType.tracing) {
      return TracingLevelView(
        level: level,
        onFinish: canFinish
            ? (work) => _markCanvasWork(context, child.id, work, activity)
            : null,
      );
    }

    final item = activity.currentItem;
    final textDirection = LearningTextDirection.forLevel(level);
    final learningTextStyle = LearningTextDirection.styleFor(
      null,
      textDirection,
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ContextualKoalaGuide(
          trigger: KoalaGuideTrigger.activityStart,
          audience: KoalaGuideAudience.child,
          moduleId: level.moduleId,
          levelId: level.id,
          stage: level.stage,
          fallbackMessage: level.subtitle,
          textDirection: textDirection,
        ),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            minHeight: 16,
            value:
                (activity.itemIndex + (activity.currentItemComplete ? 1 : 0)) /
                    level.contentItems.length,
            color: PlayColors.sunshine,
            backgroundColor: Colors.white.withValues(alpha: 0.4),
          ),
        ),
        const SizedBox(height: 12),
        JellyCard(
          color: Colors.white,
          filled: true,
          borderWidth: 4,
          padding: const EdgeInsets.all(18),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    ActivityBadge(
                      text: item.displayText,
                      size: 104,
                      accent: PlayColors.forModuleId(level.moduleId),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: textDirection == TextDirection.rtl
                            ? CrossAxisAlignment.end
                            : CrossAxisAlignment.start,
                        children: [
                          Directionality(
                            textDirection: textDirection,
                            child: Text(
                              item.title,
                              textAlign:
                                  LearningTextDirection.alignFor(textDirection),
                              style: LearningTextDirection.styleFor(
                                const TextStyle(
                                  fontFamily: 'Fredoka',
                                  fontSize: 26,
                                  fontWeight: FontWeight.w600,
                                  color: PlayColors.ink,
                                ),
                                textDirection,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Card ${activity.itemIndex + 1} of '
                            '${level.contentItems.length}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    ContentAudioButton(audioCueKey: item.audioCueKey),
                  ],
                ),
                const SizedBox(height: 16),
                Directionality(
                  textDirection: textDirection,
                  child: Text(
                    item.prompt,
                    textAlign: LearningTextDirection.alignFor(textDirection),
                    style: learningTextStyle,
                  ),
                ),
                const SizedBox(height: 8),
                Directionality(
                  textDirection: textDirection,
                  child: Text(
                    item.visualLabel,
                    textAlign: LearningTextDirection.alignFor(textDirection),
                    style: LearningTextDirection.styleFor(
                      Theme.of(context).textTheme.bodySmall,
                      textDirection,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                _ActivityInteraction(level: level),
            ],
        ),
        ),
        const SizedBox(height: 12),
        if (activity.currentItemComplete && !activity.isLastItem)
          PlayButton(
            icon: Icons.arrow_forward_rounded,
            label: 'Next card',
            color: PlayColors.sunshine,
            onPressed: activity.nextItem,
          ),
        if (activity.currentItemComplete && activity.isLastItem)
          ContextualKoalaGuide(
            trigger: KoalaGuideTrigger.activityComplete,
            audience: KoalaGuideAudience.child,
            moduleId: level.moduleId,
            levelId: level.id,
            stage: level.stage,
            fallbackMessage: 'Activity complete. Ready for the check.',
            textDirection: textDirection,
          ),
        const SizedBox(height: 8),
        PlayButton(
          icon: Icons.check_circle_rounded,
          label: level.quizQuestions.isEmpty ? 'Earn reward' : 'Start quiz',
          color: PlayColors.grass,
          big: true,
          onPressed: canFinish ? () => _complete(context, child.id) : null,
        ),
      ],
    );
  }

  /// Hands a finished drawing or tracing page to a grown-up.
  ///
  /// Nothing here judges the work: the parental lock proves an adult is holding
  /// the device, and the mark they choose becomes the level's score.
  Future<void> _markCanvasWork(
    BuildContext context,
    String childId,
    List<CanvasWork> work,
    LevelActivityViewModel activity,
  ) async {
    final navigator = Navigator.of(context);
    final unlocked = await navigator.pushNamed<bool>(
      RouteNames.parentalLock,
      arguments: const ParentalLockArgs(),
    );
    if (unlocked != true || !context.mounted) return;

    final mark = await navigator.pushNamed<ParentMark>(
      RouteNames.parentMarking,
      arguments: ParentMarkingArgs(level: level, work: work),
    );
    // Backing out without choosing leaves the page exactly as it was, so the
    // child's work survives a parent who wants another look.
    if (mark == null || !context.mounted) return;

    if (!mark.passes(level.passingScore)) {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('More practice'),
            content: Text(
              'This level needs ${level.passingScore}% to pass, so it starts '
              'again with a fresh page.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Start again'),
              ),
            ],
          );
        },
      );
      if (context.mounted) activity.restart();
      return;
    }

    await _complete(context, childId, score: mark.score);
  }

  Future<void> _complete(
    BuildContext context,
    String childId, {
    int? score,
  }) async {
    if (level.quizQuestions.isNotEmpty) {
      final child = context.read<ActiveChildSession>().activeChild;
      if (child != null && AgeStageHelper.shouldShowQuiz(child.age)) {
        Navigator.of(context).pushReplacementNamed(
          RouteNames.quiz,
          // Any mark a parent has already given rides along, so the quiz can
          // average the two rather than replacing it.
          arguments: QuizArgs(levelId: level.id, parentMark: score),
        );
        return;
      }
    }

    final progress = await context.read<LearningViewModel>().completeLevel(
          childId,
          level,
          score: score,
        );
    if (!context.mounted) return;
    Navigator.of(context).pushReplacementNamed(
      RouteNames.celebration,
      arguments: CelebrationArgs(
        moduleId: level.moduleId,
        levelTitle: level.title,
        starsEarned: progress.starsEarned,
        score: score,
      ),
    );
  }
}

/// Big round back button and the level name, replacing the plain AppBar.
class _PlayerHeader extends StatelessWidget {
  const _PlayerHeader({
    required this.title,
    required this.textDirection,
    required this.onBack,
  });

  final String title;
  final TextDirection textDirection;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Row(
        children: [
          PlayIconButton(
            icon: Icons.arrow_back_rounded,
            semanticLabel: 'Go back',
            onPressed: onBack,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Directionality(
              textDirection: textDirection,
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: LearningTextDirection.alignFor(textDirection),
                style: LearningTextDirection.styleFor(
                  const TextStyle(
                    fontFamily: 'Fredoka',
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                  textDirection,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityInteraction extends StatelessWidget {
  const _ActivityInteraction({required this.level});

  final LearningLevel level;

  @override
  Widget build(BuildContext context) {
    return switch (level.type) {
      LevelType.counting => const _CountingInteraction(),
      LevelType.matching => const _MatchingInteraction(),
      LevelType.story => const _StoryInteraction(),
      _ => const _FlashcardInteraction(),
    };
  }
}

class _CountingInteraction extends StatelessWidget {
  const _CountingInteraction();

  @override
  Widget build(BuildContext context) {
    final activity = context.watch<LevelActivityViewModel>();
    final done = activity.currentItemComplete;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Taps: ${activity.tapCount} / ${activity.targetCount}',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 10),
        PlayButton(
          onPressed: done ? null : activity.tapCounter,
          icon: done ? Icons.check_rounded : Icons.touch_app_rounded,
          label: done ? 'Good counting' : 'Tap to count',
          color: done ? PlayColors.grass : PlayColors.sunshine,
          big: true,
        ),
        const SizedBox(height: 14),
        // Each tap leaves a big coloured dot, so a child can see the count
        // they have made rather than only reading a number.
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 10,
          runSpacing: 10,
          children: List.generate(activity.tapCount, (index) {
            return Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: PlayColors.byIndex(index),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _MatchingInteraction extends StatelessWidget {
  const _MatchingInteraction();

  @override
  Widget build(BuildContext context) {
    final activity = context.watch<LevelActivityViewModel>();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final option in activity.matchOptions)
          Directionality(
            textDirection: LearningTextDirection.forText(option),
            child: ChoiceChip(
              label: Text(
                option,
                style: LearningTextDirection.styleForText(null, option),
              ),
              selected: activity.selectedMatch == option,
              onSelected: activity.currentItemComplete
                  ? null
                  : (_) => activity.selectMatch(option),
            ),
          ),
      ],
    );
  }
}

class _StoryInteraction extends StatelessWidget {
  const _StoryInteraction();

  @override
  Widget build(BuildContext context) {
    final activity = context.watch<LevelActivityViewModel>();

    return PlayButton(
      onPressed:
          activity.currentItemComplete ? null : activity.markCurrentLearned,
      icon: Icons.auto_stories_rounded,
      label: activity.currentItemComplete ? 'Page told' : 'I told this page',
      color: activity.currentItemComplete
          ? PlayColors.grass
          : PlayColors.strawberry,
      big: true,
    );
  }
}

class _FlashcardInteraction extends StatelessWidget {
  const _FlashcardInteraction();

  @override
  Widget build(BuildContext context) {
    final activity = context.watch<LevelActivityViewModel>();

    return PlayButton(
      onPressed:
          activity.currentItemComplete ? null : activity.markCurrentLearned,
      icon: Icons.record_voice_over_rounded,
      label: activity.currentItemComplete ? 'Learned' : 'I said it',
      color: activity.currentItemComplete
          ? PlayColors.grass
          : PlayColors.bubblegum,
      big: true,
    );
  }
}
