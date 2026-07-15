import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/routing/app_router.dart';
import '../../core/routing/route_names.dart';
import '../../core/utils/age_stage_helper.dart';
import '../../core/utils/learning_text_direction.dart';
import '../../models/koala_guide_message.dart';
import '../../models/learning_level.dart';
import '../../services/audio/koala_audio_player.dart';
import '../../viewmodels/active_child_session.dart';
import '../../viewmodels/learning_viewmodel.dart';
import '../../viewmodels/level_activity_viewmodel.dart';
import '../../widgets/app_primary_button.dart';
import '../../widgets/koala_guide.dart';

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

        return Scaffold(
          appBar: AppBar(
            title: Directionality(
              textDirection: textDirection,
              child: Text(
                level?.title ?? 'Level',
                style: LearningTextDirection.styleFor(null, textDirection),
              ),
            ),
          ),
          body: SafeArea(
            child: snapshot.connectionState != ConnectionState.done
                ? const Center(child: CircularProgressIndicator())
                : level == null
                    ? const Center(child: Text('Level not found.'))
                    : ChangeNotifierProvider(
                        create: (_) => LevelActivityViewModel(level),
                        child: _LevelBody(level: level),
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
        LinearProgressIndicator(
          value: (activity.itemIndex + (activity.currentItemComplete ? 1 : 0)) /
              level.contentItems.length,
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    _ActivityBadge(text: item.displayText),
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
                                Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w900),
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
                    _ContentAudioButton(audioCueKey: item.audioCueKey),
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
        ),
        const SizedBox(height: 12),
        if (activity.currentItemComplete && !activity.isLastItem)
          AppPrimaryButton(
            icon: Icons.arrow_forward,
            label: 'Next card',
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
        AppPrimaryButton(
          icon: Icons.check_circle,
          label: level.quizQuestions.isEmpty ? 'Earn reward' : 'Start quiz',
          onPressed: child == null || !activity.isActivityComplete
              ? null
              : () => _complete(context, child.id),
        ),
      ],
    );
  }

  Future<void> _complete(BuildContext context, String childId) async {
    if (level.quizQuestions.isNotEmpty) {
      final child = context.read<ActiveChildSession>().activeChild;
      if (child != null && AgeStageHelper.shouldShowQuiz(child.age)) {
        Navigator.of(context).pushReplacementNamed(
          RouteNames.quiz,
          arguments: level.id,
        );
        return;
      }
    }

    final progress = await context.read<LearningViewModel>().completeLevel(
          childId,
          level,
        );
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

class _ContentAudioButton extends StatefulWidget {
  const _ContentAudioButton({required this.audioCueKey});

  static const learningAssetBasePath = 'audio/learning';

  final String? audioCueKey;

  @override
  State<_ContentAudioButton> createState() => _ContentAudioButtonState();
}

class _ContentAudioButtonState extends State<_ContentAudioButton> {
  bool _isPlaying = false;

  @override
  Widget build(BuildContext context) {
    final cueKey = widget.audioCueKey?.trim();
    final player = _maybeAudioPlayer(context);
    if (cueKey == null || cueKey.isEmpty || player == null) {
      return const SizedBox.shrink();
    }

    return IconButton(
      tooltip: 'Play card audio',
      onPressed: _isPlaying ? null : () => _playCue(player, cueKey),
      iconSize: 20,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      icon: Icon(
        _isPlaying ? Icons.volume_up : Icons.volume_up_outlined,
      ),
    );
  }

  Future<void> _playCue(KoalaAudioPlayer player, String cueKey) async {
    setState(() => _isPlaying = true);
    try {
      await player.playCue(
        cueKey,
        assetBasePath: _ContentAudioButton.learningAssetBasePath,
      );
    } finally {
      if (mounted) {
        setState(() => _isPlaying = false);
      }
    }
  }

  KoalaAudioPlayer? _maybeAudioPlayer(BuildContext context) {
    try {
      return context.read<KoalaAudioPlayer>();
    } on ProviderNotFoundException {
      return null;
    }
  }
}

class _ActivityBadge extends StatelessWidget {
  const _ActivityBadge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final textDirection = LearningTextDirection.forText(text);
    final badgeStyle = LearningTextDirection.styleForText(
      Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w900,
          ),
      text,
    );

    return SizedBox(
      width: 82,
      height: 82,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Directionality(
            textDirection: textDirection,
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: badgeStyle,
            ),
          ),
        ),
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
      LevelType.drawing => const _DrawingInteraction(),
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
        FilledButton.icon(
          onPressed: done ? null : activity.tapCounter,
          icon: Icon(done ? Icons.check : Icons.touch_app),
          label: Text(done ? 'Good counting' : 'Tap object'),
        ),
        const SizedBox(height: 10),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 6,
          runSpacing: 6,
          children: List.generate(activity.tapCount, (index) {
            return const Icon(Icons.circle, size: 18);
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

    return FilledButton.icon(
      onPressed:
          activity.currentItemComplete ? null : activity.markCurrentLearned,
      icon: const Icon(Icons.auto_stories),
      label: Text(
        activity.currentItemComplete ? 'Page told' : 'I told this page',
      ),
    );
  }
}

class _DrawingInteraction extends StatelessWidget {
  const _DrawingInteraction();

  static const _colorMap = {
    'Red': Color(0xFFF16A5B),
    'Blue': Color(0xFF2D7DD2),
    'Yellow': Color(0xFFF2B84B),
    'Green': Color(0xFF1E9B72),
  };

  @override
  Widget build(BuildContext context) {
    final activity = context.watch<LevelActivityViewModel>();
    final selectedColor = _colorMap[activity.selectedDrawingColor] ??
        Theme.of(context).colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 112,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: selectedColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: selectedColor.withValues(alpha: 0.5),
              ),
            ),
            child: Center(
              child: Icon(
                Icons.brush,
                color: selectedColor,
                size: 44,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final colorName in activity.drawingColorOptions)
              ChoiceChip(
                avatar: CircleAvatar(
                  backgroundColor: _colorMap[colorName],
                ),
                label: Text(colorName),
                selected: activity.selectedDrawingColor == colorName,
                onSelected: activity.currentItemComplete
                    ? null
                    : (_) => activity.selectDrawingColor(colorName),
              ),
          ],
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed:
              activity.currentItemComplete ? null : activity.markCurrentLearned,
          icon: const Icon(Icons.palette),
          label: Text(
            activity.currentItemComplete ? 'Finished' : 'I finished it',
          ),
        ),
      ],
    );
  }
}

class _FlashcardInteraction extends StatelessWidget {
  const _FlashcardInteraction();

  @override
  Widget build(BuildContext context) {
    final activity = context.watch<LevelActivityViewModel>();

    return FilledButton.icon(
      onPressed:
          activity.currentItemComplete ? null : activity.markCurrentLearned,
      icon: const Icon(Icons.record_voice_over),
      label: Text(activity.currentItemComplete ? 'Learned' : 'I said it'),
    );
  }
}
