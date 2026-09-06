import 'package:flutter/material.dart';

import '../../models/activity_data.dart';
import 'activity_audio.dart';
import 'activity_stage.dart';
import 'drag_and_match_widget.dart';
import 'identify_and_tap_widget.dart';
import 'listen_and_see_widget.dart';
import 'maze_widget.dart';
import 'memory_match_widget.dart';
import 'odd_one_out_widget.dart';
import 'puzzle_widget.dart';
import 'pattern_complete_widget.dart';
import 'shadow_match_widget.dart';
import 'sort_into_zones_widget.dart';
import 'story_interactive_widget.dart';
import 'tap_to_count_widget.dart';
import 'tracing_widget.dart';
import 'two_choice_tap_widget.dart';
import 'visual_math_widget.dart';
import 'word_builder_widget.dart';

/// Picks the component for a level's data.
///
/// [ActivityData] is sealed, so this switch is checked at compile time: adding
/// a component to the model without giving it a widget here will not build,
/// which is the point — a pack should never reach a child as a blank screen.
class ActivityPlayer extends StatelessWidget {
  const ActivityPlayer({
    required this.data,
    required this.audio,
    super.key,
    this.onCompleted,
  });

  final ActivityData data;
  final ActivityAudio audio;
  final VoidCallback? onCompleted;

  @override
  Widget build(BuildContext context) {
    return switch (data) {
      TwoChoiceTapData d => TwoChoiceTapWidget(
          data: d,
          audio: audio,
          onCompleted: onCompleted,
        ),
      IdentifyAndTapData d => IdentifyAndTapWidget(
          data: d,
          audio: audio,
          onCompleted: onCompleted,
        ),
      TapToCountData d => TapToCountWidget(
          data: d,
          audio: audio,
          onCompleted: onCompleted,
        ),
      ShadowMatchData d => ShadowMatchWidget(
          data: d,
          audio: audio,
          onCompleted: onCompleted,
        ),
      PuzzleData d => PuzzleWidget(
          data: d,
          audio: audio,
          onCompleted: onCompleted,
        ),
      OddOneOutData d => OddOneOutWidget(
          data: d,
          audio: audio,
          onCompleted: onCompleted,
        ),
      StoryInteractiveData d => StoryInteractiveWidget(
          data: d,
          audio: audio,
          onCompleted: onCompleted,
        ),
      ListenAndSeeData d => ListenAndSeeWidget(
          data: d,
          audio: audio,
          onCompleted: onCompleted,
        ),
      TracingData d => TracingWidget(
          data: d,
          audio: audio,
          onCompleted: onCompleted,
        ),
      DragAndMatchData d => DragAndMatchWidget(
          data: d,
          audio: audio,
          onCompleted: onCompleted,
        ),
      SortIntoZonesData d => SortIntoZonesWidget(
          data: d,
          audio: audio,
          onCompleted: onCompleted,
        ),
      PatternCompleteData d => PatternCompleteWidget(
          data: d,
          audio: audio,
          onCompleted: onCompleted,
        ),
      WordBuilderData d => WordBuilderWidget(
          data: d,
          audio: audio,
          onCompleted: onCompleted,
        ),
      VisualMathData d => VisualMathWidget(
          data: d,
          audio: audio,
          onCompleted: onCompleted,
        ),
      MazeData d => MazeWidget(
          data: d,
          audio: audio,
          onCompleted: onCompleted,
        ),
      MemoryMatchData d => MemoryMatchWidget(
          data: d,
          audio: audio,
          onCompleted: onCompleted,
        ),
      UnsupportedActivityData(:final rawComponent) => ActivityStage(
          title: data.title,
          isRtl: data.isRtl,
          child: ActivityEmptyNotice(
            message:
                'This level asks for a "$rawComponent" activity, which this '
                'version of the app does not have yet.',
          ),
        ),
    };
  }
}
