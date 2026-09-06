import 'package:flutter/material.dart';

import '../../models/activity_data.dart';
import 'activity_audio.dart';
import 'choice_rounds_activity.dart';

/// Plays a spoken prompt and offers two things to tap.
///
/// The pack decides what the two things are — letters in English, Urdu glyph
/// shapes, or a big and a small ball for the maths size round — so the same
/// widget carries "Where is A?", "Nuqta pehchano" and "Tap the big one".
class TwoChoiceTapWidget extends StatelessWidget {
  const TwoChoiceTapWidget({
    required this.data,
    required this.audio,
    super.key,
    this.onCompleted,
  });

  final TwoChoiceTapData data;
  final ActivityAudio audio;
  final VoidCallback? onCompleted;

  @override
  Widget build(BuildContext context) {
    return ChoiceRoundsActivity(
      title: data.title,
      isRtl: data.isRtl,
      audio: audio,
      onCompleted: onCompleted,
      promptLabel: 'Listen, then tap',
      rounds: [
        for (final item in data.items)
          ChoiceRound(
            options: item.options,
            audioPrompt: item.audioPrompt,
            promptText: item.promptText,
          ),
      ],
    );
  }
}
