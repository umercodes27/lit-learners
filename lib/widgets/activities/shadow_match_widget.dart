import 'package:flutter/material.dart';

import '../../models/activity_data.dart';
import 'activity_audio.dart';
import 'choice_rounds_activity.dart';

/// Shows an object and two silhouettes, and asks which shadow is its own.
///
/// The options are drawn through [ChoiceOptionStyle.silhouette], so a pack can
/// point at ordinary artwork and still get a true shadow — the dedicated
/// `shadow_*.png` files work too, they simply come out already dark.
class ShadowMatchWidget extends StatelessWidget {
  const ShadowMatchWidget({
    required this.data,
    required this.audio,
    super.key,
    this.onCompleted,
  });

  final ShadowMatchData data;
  final ActivityAudio audio;
  final VoidCallback? onCompleted;

  @override
  Widget build(BuildContext context) {
    return ChoiceRoundsActivity(
      title: data.title,
      isRtl: data.isRtl,
      audio: audio,
      onCompleted: onCompleted,
      optionStyle: ChoiceOptionStyle.silhouette,
      promptLabel: 'Find its shadow',
      rounds: [
        for (final item in data.items)
          ChoiceRound(
            options: item.options,
            audioPrompt: item.audioPrompt,
            promptImage: item.objectImage,
          ),
      ],
    );
  }
}
