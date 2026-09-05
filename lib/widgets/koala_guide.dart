import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/utils/learning_text_direction.dart';
import '../models/koala_guide_message.dart';
import '../repositories/koala_guide_repository.dart';
import '../services/audio/koala_audio_player.dart';
import 'play/play.dart';

class KoalaGuide extends StatelessWidget {
  const KoalaGuide({
    required this.message,
    this.textDirection,
    this.parentTip,
    this.audioCueKey,
    this.mood = KoalaGuideMood.neutral,
    super.key,
  });

  final String message;
  final TextDirection? textDirection;
  final String? parentTip;
  final String? audioCueKey;
  final KoalaGuideMood mood;

  @override
  Widget build(BuildContext context) {
    final resolvedDirection = textDirection ?? TextDirection.ltr;
    final icon = switch (mood) {
      KoalaGuideMood.celebrating => Icons.emoji_events,
      KoalaGuideMood.encouraging => Icons.favorite,
      KoalaGuideMood.thinking => Icons.psychology,
      KoalaGuideMood.parent => Icons.supervisor_account,
      KoalaGuideMood.neutral => Icons.child_care,
    };
    final accent = switch (mood) {
      KoalaGuideMood.celebrating => PlayColors.sunshine,
      KoalaGuideMood.encouraging => PlayColors.bubblegum,
      KoalaGuideMood.thinking => PlayColors.grape,
      KoalaGuideMood.parent => PlayColors.sky,
      KoalaGuideMood.neutral => PlayColors.grass,
    };

    return Container(
      decoration: BoxDecoration(
        color: PlayColors.card,
        borderRadius: BorderRadius.circular(PlayMotion.radiusLarge),
        border: Border.all(color: Colors.white, width: 4),
        boxShadow: [
          BoxShadow(
            color: PlayColors.ink.withValues(alpha: 0.20),
            offset: const Offset(0, 6),
            blurRadius: 0,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    color: PlayColors.sunshine,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 4),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.asset(
                    'assets/images/koala/koala_guide_portrait.png',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.child_care,
                      color: Theme.of(context).colorScheme.primary,
                      size: 32,
                    ),
                  ),
                ),
                Positioned(
                  right: -3,
                  bottom: -3,
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: accent,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Icon(icon, color: Colors.white, size: 18),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: resolvedDirection == TextDirection.rtl
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  Directionality(
                    textDirection: resolvedDirection,
                    child: Text(
                      message,
                      textAlign: LearningTextDirection.alignFor(
                        resolvedDirection,
                      ),
                      style: LearningTextDirection.styleFor(
                        const TextStyle(
                          fontFamily: 'Fredoka',
                          fontSize: 19,
                          height: 1.3,
                          fontWeight: FontWeight.w500,
                          color: PlayColors.ink,
                        ),
                        resolvedDirection,
                      ),
                    ),
                  ),
                  if (parentTip != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      parentTip!,
                      textAlign: LearningTextDirection.alignFor(
                        resolvedDirection,
                      ),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.72),
                          ),
                    ),
                  ],
                  if (audioCueKey != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: resolvedDirection == TextDirection.rtl
                          ? MainAxisAlignment.end
                          : MainAxisAlignment.start,
                      children: [
                        PlayIconButton(
                          icon: Icons.volume_up,
                          semanticLabel: 'Play Koala guide audio',
                          onPressed: () => _playAudioCue(context),
                          color: accent,
                          iconColor: Colors.white,
                          size: 52,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _playAudioCue(BuildContext context) async {
    final player = _maybeAudioPlayer(context);
    if (player == null) return;

    await player.playCue(audioCueKey);
  }

  KoalaAudioPlayer? _maybeAudioPlayer(BuildContext context) {
    try {
      return context.read<KoalaAudioPlayer>();
    } on ProviderNotFoundException {
      return null;
    }
  }
}

class ContextualKoalaGuide extends StatelessWidget {
  const ContextualKoalaGuide({
    required this.trigger,
    required this.audience,
    this.moduleId,
    this.levelId,
    this.stage,
    this.fallbackMessage,
    this.fallbackParentTip,
    this.textDirection,
    super.key,
  });

  final KoalaGuideTrigger trigger;
  final KoalaGuideAudience audience;
  final String? moduleId;
  final String? levelId;
  final int? stage;
  final String? fallbackMessage;
  final String? fallbackParentTip;
  final TextDirection? textDirection;

  @override
  Widget build(BuildContext context) {
    final request = KoalaGuideRequest(
      trigger: trigger,
      audience: audience,
      moduleId: moduleId,
      levelId: levelId,
      stage: stage,
      fallbackMessage: fallbackMessage,
      fallbackParentTip: fallbackParentTip,
    );
    final repository = _maybeRepository(context);

    if (repository == null) {
      return KoalaGuide(
        message: fallbackMessage ?? 'Let us try this one step at a time.',
        parentTip: fallbackParentTip,
        textDirection: textDirection,
        mood: audience == KoalaGuideAudience.parent
            ? KoalaGuideMood.parent
            : KoalaGuideMood.encouraging,
      );
    }

    return FutureBuilder<KoalaGuideMessage>(
      future: repository.getMessage(request),
      builder: (context, snapshot) {
        final message = snapshot.data;
        return KoalaGuide(
          message: message?.message ??
              fallbackMessage ??
              'Let us try this one step at a time.',
          parentTip: message?.parentTip ?? fallbackParentTip,
          audioCueKey: message?.audioCueKey,
          mood: message?.mood ??
              (audience == KoalaGuideAudience.parent
                  ? KoalaGuideMood.parent
                  : KoalaGuideMood.encouraging),
          textDirection: textDirection ??
              LearningTextDirection.forText(
                message?.message ?? fallbackMessage ?? '',
              ),
        );
      },
    );
  }

  KoalaGuideRepository? _maybeRepository(BuildContext context) {
    try {
      return context.read<KoalaGuideRepository>();
    } on ProviderNotFoundException {
      return null;
    }
  }
}
