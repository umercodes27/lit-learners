import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/utils/learning_text_direction.dart';
import '../../../services/audio/koala_audio_player.dart';
import '../../../services/content/asset_availability.dart';
import '../../../widgets/play/play.dart';

/// Plays the audio cue attached to a content card, if the level ships one.
///
/// "If it ships one" is the whole job. Every seeded level names a cue —
/// `trace_letter_a`, `drawing_circle`, `logic_big` — but
/// `assets/audio/learning/` is empty, so the button was drawn on the Tracing,
/// Drawing and Logic levels and did nothing at all when pressed. A speaker a
/// child taps and taps with no sound is worse than no speaker: it teaches them
/// the app ignores them.
///
/// So the button appears only when the recording is actually in the bundle. It
/// comes back on its own for any cue that gets recorded later, with no change
/// here.
class ContentAudioButton extends StatefulWidget {
  const ContentAudioButton({required this.audioCueKey, super.key});

  static const learningAssetBasePath = 'audio/learning';

  final String? audioCueKey;

  @override
  State<ContentAudioButton> createState() => _ContentAudioButtonState();
}

class _ContentAudioButtonState extends State<ContentAudioButton> {
  bool _isPlaying = false;

  /// The asset registry answers optimistically until the manifest is read, so
  /// the button waits one frame rather than appearing and then vanishing.
  bool _manifestRead = false;

  @override
  void initState() {
    super.initState();
    _readManifest();
  }

  Future<void> _readManifest() async {
    await AssetAvailability.instance.populate();
    if (mounted) setState(() => _manifestRead = true);
  }

  /// Whether this cue has a file behind it. A remote cue is taken on trust —
  /// only the bundle can be checked here.
  bool _hasRecording(String cueKey) {
    final source = KoalaAudioCueSource.resolve(
      cueKey,
      assetBasePath: ContentAudioButton.learningAssetBasePath,
    );
    if (source == null) return false;
    if (source.source != KoalaAudioPlaybackSource.asset) return true;
    return AssetAvailability.instance.has('assets/${source.path}');
  }

  @override
  Widget build(BuildContext context) {
    final cueKey = widget.audioCueKey?.trim();
    final player = _maybeAudioPlayer(context);
    if (cueKey == null || cueKey.isEmpty || player == null) {
      return const SizedBox.shrink();
    }
    if (!_manifestRead || !_hasRecording(cueKey)) {
      return const SizedBox.shrink();
    }

    return PlayIconButton(
      icon: Icons.volume_up,
      semanticLabel: 'Play card audio',
      onPressed: _isPlaying ? null : () => _playCue(player, cueKey),
      color: _isPlaying ? PlayColors.sunshine : PlayColors.sky,
      iconColor: Colors.white,
      size: 56,
    );
  }

  Future<void> _playCue(KoalaAudioPlayer player, String cueKey) async {
    setState(() => _isPlaying = true);
    try {
      await player.playCue(
        cueKey,
        assetBasePath: ContentAudioButton.learningAssetBasePath,
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

/// The tinted square showing the letter, number or word a card is about.
class ActivityBadge extends StatelessWidget {
  const ActivityBadge({
    required this.text,
    this.size = 82,
    this.accent,
    super.key,
  });

  final String text;
  final double size;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final textDirection = LearningTextDirection.forText(text);
    final color = accent ?? PlayColors.blueberry;
    final badgeStyle = LearningTextDirection.styleForText(
      const TextStyle(
        fontSize: 56,
        fontWeight: FontWeight.w800,
        color: Colors.white,
      ),
      text,
    );

    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(PlayMotion.radius),
          border: Border.all(color: Colors.white, width: 4),
          boxShadow: [
            BoxShadow(
              color: PlayColors.ink.withValues(alpha: 0.2),
              offset: const Offset(0, 5),
              blurRadius: 0,
            ),
          ],
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: FittedBox(
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
        ),
      ),
    );
  }
}
