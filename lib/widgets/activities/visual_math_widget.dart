import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/age2_skin.dart';
import '../../models/activity_data.dart';
import '../../services/audio/glyph_speech.dart';
import 'activity_asset_image.dart';
import 'activity_audio.dart';
import 'activity_feedback_controller.dart';
import 'activity_stage.dart';
import 'playful_tap_target.dart';

/// Add or take away, shown as two groups of things rather than as digits.
///
/// A four-year-old meeting arithmetic has no reason to read `3 - 1`. So the
/// sum is the pictures: three stars beside one star, with the sign between
/// them, and the answer chosen by counting what is on screen. The digits are
/// there too, under each group, because this is also where the written form
/// starts to attach to the quantity.
///
/// Subtraction draws the group being taken away faded and crossed rather than
/// absent — a child cannot subtract things that were never drawn.
class VisualMathWidget extends StatefulWidget {
  const VisualMathWidget({
    required this.data,
    required this.audio,
    super.key,
    this.onCompleted,
    this.speech,
  });

  final VisualMathData data;
  final ActivityAudio audio;
  final VoidCallback? onCompleted;
  final GlyphSpeech? speech;

  @override
  State<VisualMathWidget> createState() => _VisualMathWidgetState();
}

class _VisualMathWidgetState extends State<VisualMathWidget> {
  late final ActivityFeedbackController _feedback =
      ActivityFeedbackController(audio: widget.audio);
  late final GlyphSpeech _speech = widget.speech ?? GlyphSpeech();

  int _index = 0;
  int _correct = 0;
  int? _tapped;
  bool _locked = false;
  bool _finished = false;
  Timer? _advanceTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _announce());
  }

  @override
  void dispose() {
    _advanceTimer?.cancel();
    _speech.stop();
    _feedback.dispose();
    super.dispose();
  }

  VisualMathItem get _item => widget.data.items[_index];

  String get _prompt => _item.operation == VisualMathOperation.add
      ? 'How many altogether?'
      : 'How many are left?';

  Future<void> _announce() async {
    if (!mounted || _finished) return;
    await _speech.speak(_prompt);
  }

  Future<void> _onTapped(int optionIndex) async {
    if (_locked) return;
    final chosen = _item.options[optionIndex];

    setState(() {
      _tapped = optionIndex;
      _locked = true;
    });

    if (chosen == _item.answer) {
      _correct++;
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
    _announce();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.data.isEmpty) {
      return ActivityStage(
        title: widget.data.title,
        isRtl: widget.data.isRtl,
        child: const ActivityEmptyNotice(
          message: 'This level has no sums yet.',
        ),
      );
    }

    if (_finished) {
      return ActivityStage(
        title: widget.data.title,
        isRtl: widget.data.isRtl,
        child: ActivityFinishedNotice(
          correct: _correct,
          total: widget.data.items.length,
          onDone: widget.onCompleted,
          headline: 'Sums done!',
        ),
      );
    }

    final palette = Age2Skin.of(context);
    final item = _item;
    final subtracting = item.operation == VisualMathOperation.subtract;

    return ActivityStage(
      title: widget.data.title,
      isRtl: widget.data.isRtl,
      roundIndex: _index,
      roundCount: widget.data.items.length,
      feedback: _feedback,
      onReplayPrompt: _announce,
      child: SingleChildScrollView(
        child: Column(
          children: [
            Text(_prompt, style: Age2Text.prompt, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 14,
              runSpacing: 14,
              children: [
                _Group(operand: item.first),
                Text(
                  subtracting ? '−' : '+',
                  style: Age2Text.glyph.copyWith(
                    fontSize: 46,
                    color: palette.accent,
                  ),
                ),
                _Group(operand: item.second, struckThrough: subtracting),
              ],
            ),
            const SizedBox(height: 34),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 18,
              runSpacing: 18,
              children: [
                for (var i = 0; i < item.options.length; i++)
                  PlayfulTapTarget(
                    onTap: _locked ? null : () => _onTapped(i),
                    semanticLabel: 'Answer ${item.options[i]}',
                    minSize: 108,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 30,
                      vertical: 18,
                    ),
                    background: _tapped == i
                        ? (item.options[i] == item.answer
                            ? Age2Colors.mint
                            : Age2Colors.butter)
                        : Colors.white,
                    borderColor: _tapped == i
                        ? (item.options[i] == item.answer
                            ? Age2Colors.clover
                            : Age2Colors.sunflower)
                        : palette.accent.withValues(alpha: 0.35),
                    borderWidth: _tapped == i ? 6 : 3,
                    child: Text(
                      '${item.options[i]}',
                      style: Age2Text.glyph,
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

/// One side of the sum: the things, then how many of them.
class _Group extends StatelessWidget {
  const _Group({required this.operand, this.struckThrough = false});

  final VisualMathOperand operand;

  /// Drawn faded and crossed for the group being taken away.
  final bool struckThrough;

  @override
  Widget build(BuildContext context) {
    final palette = Age2Skin.of(context);
    // Enough to keep twenty apples on one screen without a scroll inside a
    // scroll; small groups still get a comfortable size.
    final size = operand.count > 12 ? 34.0 : (operand.count > 6 ? 44.0 : 56.0);

    return Container(
      constraints: const BoxConstraints(minWidth: 120, maxWidth: 300),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: palette.accent.withValues(alpha: 0.3),
          width: 3,
        ),
        boxShadow: Age2Surfaces.lift(tint: palette.accent),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Opacity(
            opacity: struckThrough ? 0.45 : 1,
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 6,
              runSpacing: 6,
              children: [
                for (var i = 0; i < operand.count; i++)
                  ActivityAssetImage(path: operand.image, size: size),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '${operand.count}',
            style: Age2Text.glyph.copyWith(
              fontSize: 34,
              color: struckThrough ? palette.accent : null,
              decoration: struckThrough ? TextDecoration.lineThrough : null,
              decorationThickness: 3,
            ),
          ),
        ],
      ),
    );
  }
}
