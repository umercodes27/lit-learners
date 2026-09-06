import 'package:flutter/material.dart';

import '../../core/theme/age2_skin.dart';
import '../../models/activity_data.dart';
import 'activity_asset_image.dart';
import 'activity_audio.dart';
import 'activity_feedback_controller.dart';
import 'activity_stage.dart';
import 'playful_tap_target.dart';

/// A sight-word card: the picture, the word, and the word spoken aloud.
///
/// There is nothing to answer here, so there is no scoring and no retry sound.
/// The child moves on when they are ready, and the word can be replayed as
/// many times as they like — which is the whole point of a sight-word pass.
class ListenAndSeeWidget extends StatefulWidget {
  const ListenAndSeeWidget({
    required this.data,
    required this.audio,
    super.key,
    this.onCompleted,
  });

  final ListenAndSeeData data;
  final ActivityAudio audio;
  final VoidCallback? onCompleted;

  @override
  State<ListenAndSeeWidget> createState() => _ListenAndSeeWidgetState();
}

class _ListenAndSeeWidgetState extends State<ListenAndSeeWidget> {
  late final ActivityFeedbackController _feedback =
      ActivityFeedbackController(audio: widget.audio);

  int _index = 0;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _play());
  }

  void _play() {
    if (!mounted || _finished) return;
    widget.audio.playPrompt(widget.data.items[_index].audio);
  }

  void _next() {
    if (_index >= widget.data.items.length - 1) {
      _feedback.celebrate();
      setState(() => _finished = true);
      return;
    }
    setState(() => _index++);
    _play();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.data.items.isEmpty) {
      return ActivityStage(
        title: widget.data.title,
        isRtl: widget.data.isRtl,
        child: const ActivityEmptyNotice(
          message: 'This level has no words yet.',
        ),
      );
    }

    if (_finished) {
      return ActivityStage(
        title: widget.data.title,
        isRtl: widget.data.isRtl,
        child: ActivityFinishedNotice(
          correct: widget.data.items.length,
          total: widget.data.items.length,
          onDone: widget.onCompleted,
          headline: 'Nice listening!',
        ),
      );
    }

    final item = widget.data.items[_index];

    return ActivityStage(
      title: widget.data.title,
      isRtl: widget.data.isRtl,
      roundIndex: _index,
      roundCount: widget.data.items.length,
      feedback: _feedback,
      onReplayPrompt: item.audio == null ? null : _play,
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: GestureDetector(
                onTap: _play,
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: Age2Surfaces.radius,
                    border: Border.all(
                      color: Age2Skin.of(context).accent.withValues(alpha: 0.3),
                      width: 3,
                    ),
                    boxShadow: Age2Surfaces.lift(
                      tint: Age2Skin.of(context).accent,
                    ),
                  ),
                  child: ActivityAssetImage(path: item.image, size: 190),
                ),
              ),
            ),
          ),
          if (item.word != null) ...[
            const SizedBox(height: 14),
            Text(
              item.word!,
              style: Age2Text.glyph.copyWith(fontSize: 48, letterSpacing: 6),
            ),
          ],
          const SizedBox(height: 20),
          PlayfulTapTarget(
            onTap: _next,
            semanticLabel: 'Next word',
            borderColor: Age2Skin.of(context).accent,
            padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _index >= widget.data.items.length - 1 ? 'Finish' : 'Next',
                  style: Age2Text.cardTitle,
                ),
                const SizedBox(width: 10),
                Icon(
                  Icons.arrow_forward_rounded,
                  size: 34,
                  color: Age2Skin.of(context).accent,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
