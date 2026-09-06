import 'package:flutter/material.dart';

import '../../models/activity_data.dart';
import 'activity_audio.dart';
import 'choice_rounds_activity.dart';

/// Shows a row of items and asks which one does not belong.
///
/// Mechanically this is the same tap-and-score round as the others; what makes
/// it odd-one-out is only that the correct option is the exception rather than
/// the match, which the pack expresses by marking it `"correct": true`.
class OddOneOutWidget extends StatelessWidget {
  const OddOneOutWidget({
    required this.data,
    required this.audio,
    super.key,
    this.onCompleted,
  });

  final OddOneOutData data;
  final ActivityAudio audio;
  final VoidCallback? onCompleted;

  @override
  Widget build(BuildContext context) {
    return ChoiceRoundsActivity(
      title: data.title,
      isRtl: data.isRtl,
      audio: audio,
      onCompleted: onCompleted,
      promptLabel: 'Which one is different?',
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
