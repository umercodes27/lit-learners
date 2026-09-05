import 'package:flutter/material.dart';

import '../../models/activity_data.dart';
import 'activity_audio.dart';
import 'choice_rounds_activity.dart';

/// Shows a picture and asks the child to tap the option that matches it.
///
/// The match can run either way round — picture to letter ("what does *cat*
/// start with?") or word to picture ("tap the cat") — because the prompt image
/// is optional and the options can be letters or pictures themselves.
class IdentifyAndTapWidget extends StatelessWidget {
  const IdentifyAndTapWidget({
    required this.data,
    required this.audio,
    super.key,
    this.onCompleted,
  });

  final IdentifyAndTapData data;
  final ActivityAudio audio;
  final VoidCallback? onCompleted;

  @override
  Widget build(BuildContext context) {
    return ChoiceRoundsActivity(
      title: data.title,
      isRtl: data.isRtl,
      audio: audio,
      onCompleted: onCompleted,
      promptLabel: 'Which one?',
      rounds: [
        for (final item in data.items)
          ChoiceRound(
            options: item.options,
            audioPrompt: item.audioPrompt,
            promptText: item.promptText,
            promptImage: item.promptImage,
          ),
      ],
    );
  }
}
