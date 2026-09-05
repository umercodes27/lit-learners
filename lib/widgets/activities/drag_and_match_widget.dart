import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/localization/urdu_letters.dart';
import '../../core/theme/age2_skin.dart';
import '../../models/activity_data.dart';
import 'activity_asset_image.dart';
import 'activity_audio.dart';
import 'activity_feedback_controller.dart';
import 'activity_stage.dart';

/// Drag each letter onto the picture that starts with it.
///
/// Matching is by the pack's `id_pair`, not by comparing image paths, so two
/// pictures could share artwork and still be distinct answers.
///
/// A wrong drop bounces back with the gentle cue and nothing is lost — the
/// letter returns to the tray and can be tried anywhere else.
class DragAndMatchWidget extends StatefulWidget {
  const DragAndMatchWidget({
    required this.data,
    required this.audio,
    super.key,
    this.onCompleted,
  });

  final DragAndMatchData data;
  final ActivityAudio audio;
  final VoidCallback? onCompleted;

  @override
  State<DragAndMatchWidget> createState() => _DragAndMatchWidgetState();
}

class _DragAndMatchWidgetState extends State<DragAndMatchWidget> {
  late final ActivityFeedbackController _feedback =
      ActivityFeedbackController(audio: widget.audio);

  final Set<String> _matched = {};
  bool _finished = false;
  Timer? _finishTimer;

  @override
  void dispose() {
    _finishTimer?.cancel();
    _feedback.dispose();
    super.dispose();
  }

  /// Pictures keep the pack's order; the letters are reversed so the answer is
  /// never simply the one opposite.
  List<DragMatchPair> get _tray =>
      widget.data.pairs.reversed.where((p) => !_matched.contains(p.id)).toList();

  Future<void> _onDropped(DragMatchPair target, String droppedId) async {
    if (droppedId != target.id) {
      await _feedback.tryAgain();
      return;
    }

    setState(() => _matched.add(target.id));
    await _feedback.celebrate();

    if (_matched.length == widget.data.pairs.length) {
      _finishTimer = Timer(const Duration(milliseconds: 1500), () {
        if (mounted) setState(() => _finished = true);
      });
    }
  }

  String _display(String letter) => UrduLetters.display(letter);

  TextStyle _letterStyle(String letter) =>
      UrduLetters.isUrduScript(_display(letter))
          ? Age2Text.urduGlyph.copyWith(fontSize: 40)
          : Age2Text.glyph.copyWith(fontSize: 44);

  @override
  Widget build(BuildContext context) {
    if (widget.data.isEmpty) {
      return ActivityStage(
        title: widget.data.title,
        isRtl: widget.data.isRtl,
        child: const ActivityEmptyNotice(
          message: 'This level has nothing to match yet.',
        ),
      );
    }

    if (_finished) {
      return ActivityStage(
        title: widget.data.title,
        isRtl: widget.data.isRtl,
        child: ActivityFinishedNotice(
          correct: widget.data.pairs.length,
          total: widget.data.pairs.length,
          onDone: widget.onCompleted,
          headline: 'All matched!',
        ),
      );
    }

    final palette = Age2Skin.of(context);
    final tray = _tray;

    return ActivityStage(
      title: widget.data.title,
      isRtl: widget.data.isRtl,
      roundIndex: _matched.length.clamp(0, widget.data.pairs.length - 1),
      roundCount: widget.data.pairs.length,
      feedback: _feedback,
      child: Column(
        children: [
          const Text('Drag each letter to its picture', style: Age2Text.prompt),
          const SizedBox(height: 20),
          Expanded(
            child: SingleChildScrollView(
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 20,
                runSpacing: 20,
                children: [
                  for (final pair in widget.data.pairs)
                    _PictureTarget(
                      pair: pair,
                      matched: _matched.contains(pair.id),
                      letterStyle: _letterStyle(pair.letter),
                      display: _display(pair.letter),
                      onAccept: (id) => _onDropped(pair, id),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Container(
            height: 128,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.75),
              borderRadius: Age2Surfaces.radius,
              border: Border.all(
                color: palette.accent.withValues(alpha: 0.25),
                width: 3,
              ),
            ),
            child: tray.isEmpty
                ? const Center(
                    child: Text('All done!', style: Age2Text.label),
                  )
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: tray.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 14),
                    itemBuilder: (context, i) {
                      final pair = tray[i];
                      final tile = _LetterTile(
                        text: _display(pair.letter),
                        style: _letterStyle(pair.letter),
                        accent: palette.accent,
                      );
                      return Draggable<String>(
                        data: pair.id,
                        feedback: Material(
                          color: Colors.transparent,
                          child: Opacity(opacity: 0.9, child: tile),
                        ),
                        childWhenDragging:
                            Opacity(opacity: 0.3, child: tile),
                        child: tile,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _LetterTile extends StatelessWidget {
  const _LetterTile({
    required this.text,
    required this.style,
    required this.accent,
  });

  final String text;
  final TextStyle style;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 96,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.lemon,
        borderRadius: Age2Surfaces.radius,
        border: Border.all(color: AppColors.honey, width: 3),
        boxShadow: Age2Surfaces.lift(tint: AppColors.honey),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(text, style: style),
      ),
    );
  }
}

class _PictureTarget extends StatelessWidget {
  const _PictureTarget({
    required this.pair,
    required this.matched,
    required this.letterStyle,
    required this.display,
    required this.onAccept,
  });

  final DragMatchPair pair;
  final bool matched;
  final TextStyle letterStyle;
  final String display;
  final ValueChanged<String> onAccept;

  @override
  Widget build(BuildContext context) {
    final palette = Age2Skin.of(context);

    return DragTarget<String>(
      onAcceptWithDetails: (details) => onAccept(details.data),
      builder: (context, candidate, rejected) {
        final hovering = candidate.isNotEmpty;
        return Container(
          width: 156,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: matched ? AppColors.mint : Colors.white,
            borderRadius: Age2Surfaces.radius,
            border: Border.all(
              color: matched
                  ? AppColors.leaf
                  : hovering
                      ? palette.accent
                      : palette.accent.withValues(alpha: 0.3),
              width: matched || hovering ? 5 : 3,
            ),
            boxShadow: Age2Surfaces.lift(tint: palette.accent),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ActivityAssetImage(path: pair.image, size: 92),
              const SizedBox(height: 10),
              SizedBox(
                height: 48,
                child: matched
                    ? FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(display, style: letterStyle),
                      )
                    : DecoratedBox(
                        decoration: BoxDecoration(
                          color: palette.background,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const SizedBox(width: 60, height: 48),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
