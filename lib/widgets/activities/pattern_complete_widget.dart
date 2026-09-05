import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/age2_skin.dart';
import '../../models/activity_data.dart';
import 'activity_asset_image.dart';
import 'activity_audio.dart';
import 'activity_feedback_controller.dart';
import 'activity_stage.dart';
import 'playful_tap_target.dart';

/// Show a run of pictures with a gap at the end, and ask what comes next.
///
/// The sequence is laid out with an empty slot rather than trailing off, so
/// the question is visible without a word of explanation — which matters when
/// the child cannot read the prompt.
class PatternCompleteWidget extends StatefulWidget {
  const PatternCompleteWidget({
    required this.data,
    required this.audio,
    super.key,
    this.onCompleted,
  });

  final PatternCompleteData data;
  final ActivityAudio audio;
  final VoidCallback? onCompleted;

  @override
  State<PatternCompleteWidget> createState() => _PatternCompleteWidgetState();
}

class _PatternCompleteWidgetState extends State<PatternCompleteWidget> {
  late final ActivityFeedbackController _feedback =
      ActivityFeedbackController(audio: widget.audio);

  int _index = 0;
  int? _tapped;
  bool _locked = false;
  bool _finished = false;
  Timer? _advanceTimer;

  @override
  void dispose() {
    _advanceTimer?.cancel();
    _feedback.dispose();
    super.dispose();
  }

  PatternItem get _item => widget.data.items[_index];

  Future<void> _onTapped(int optionIndex) async {
    if (_locked) return;
    final option = _item.options[optionIndex];

    setState(() {
      _tapped = optionIndex;
      _locked = true;
    });

    if (option.isCorrect) {
      await _feedback.celebrate();
      _advanceTimer = Timer(const Duration(milliseconds: 1400), _advance);
    } else {
      await _feedback.tryAgain();
      _advanceTimer = Timer(const Duration(milliseconds: 900), () {
        if (!mounted) return;
        setState(() {
          _tapped = null;
          _locked = false;
        });
      });
    }
  }

  void _advance() {
    if (!mounted) return;
    if (_index >= widget.data.items.length - 1) {
      setState(() => _finished = true);
      return;
    }
    setState(() {
      _index++;
      _tapped = null;
      _locked = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.data.isEmpty) {
      return ActivityStage(
        title: widget.data.title,
        isRtl: widget.data.isRtl,
        child: const ActivityEmptyNotice(
          message: 'This level has no patterns yet.',
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
          headline: 'Pattern finished!',
        ),
      );
    }

    final palette = Age2Skin.of(context);
    final item = _item;

    return ActivityStage(
      title: widget.data.title,
      isRtl: widget.data.isRtl,
      roundIndex: _index,
      roundCount: widget.data.items.length,
      feedback: _feedback,
      child: SingleChildScrollView(
        child: Column(
          children: [
            const Text('What comes next?', style: Age2Text.prompt),
            const SizedBox(height: 26),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final path in item.sequence)
                  _SequenceCell(child: ActivityAssetImage(path: path, size: 66)),
                _SequenceCell(
                  dashed: true,
                  child: Text(
                    '?',
                    style: Age2Text.glyph.copyWith(
                      fontSize: 46,
                      color: palette.accent,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 34),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 22,
              runSpacing: 22,
              children: [
                for (var i = 0; i < item.options.length; i++)
                  SizedBox(
                    width: 156,
                    child: PlayfulTapTarget(
                      onTap: _locked ? null : () => _onTapped(i),
                      semanticLabel: 'Option ${i + 1}',
                      minSize: 150,
                      padding: const EdgeInsets.all(22),
                      background: _tapped == i
                          ? (item.options[i].isCorrect
                              ? AppColors.mint
                              : AppColors.lemon)
                          : Colors.white,
                      borderColor: _tapped == i
                          ? (item.options[i].isCorrect
                              ? AppColors.leaf
                              : AppColors.honey)
                          : palette.accent.withValues(alpha: 0.35),
                      borderWidth: _tapped == i ? 6 : 3,
                      child: ActivityAssetImage(
                        path: item.options[i].image,
                        size: 96,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// One box in the run — a picture, or the empty slot to fill.
class _SequenceCell extends StatelessWidget {
  const _SequenceCell({required this.child, this.dashed = false});

  final Widget child;
  final bool dashed;

  @override
  Widget build(BuildContext context) {
    final palette = Age2Skin.of(context);

    return Container(
      width: 92,
      height: 92,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: dashed ? palette.background : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: palette.accent.withValues(alpha: dashed ? 0.6 : 0.25),
          width: dashed ? 4 : 3,
        ),
        boxShadow: dashed ? null : Age2Surfaces.lift(tint: palette.accent),
      ),
      child: child,
    );
  }
}
