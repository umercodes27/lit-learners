import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/localization/urdu_letters.dart';
import '../../core/theme/age2_skin.dart';
import '../../models/activity_option.dart';
import 'activity_asset_image.dart';
import 'activity_audio.dart';
import 'activity_feedback_controller.dart';
import 'activity_stage.dart';
import 'playful_tap_target.dart';

/// One question inside a choice-based activity.
class ChoiceRound {
  const ChoiceRound({
    required this.options,
    this.audioPrompt,
    this.promptText,
    this.promptImage,
  });

  final List<ActivityOption> options;
  final String? audioPrompt;
  final String? promptText;
  final String? promptImage;
}

/// How the options should be drawn.
enum ChoiceOptionStyle {
  /// Picture or letter exactly as authored.
  plain,

  /// Flat dark shapes, for shadow matching.
  silhouette,
}

/// The engine behind every "listen, then tap the right one" round.
///
/// Two-choice tap, identify-and-tap, shadow match and odd-one-out differ only
/// in what sits above the options and how those options are drawn, so they all
/// delegate here. Scoring, the applause-and-bounce reward, the gentle retry,
/// prompt replay and round advancement live in one place — which is what makes
/// a new component cheap to add and keeps the feel identical across modules.
class ChoiceRoundsActivity extends StatefulWidget {
  const ChoiceRoundsActivity({
    required this.title,
    required this.rounds,
    required this.audio,
    required this.isRtl,
    super.key,
    this.optionStyle = ChoiceOptionStyle.plain,
    this.promptLabel,
    this.onCompleted,
  });

  final String title;
  final List<ChoiceRound> rounds;
  final ActivityAudio audio;
  final bool isRtl;
  final ChoiceOptionStyle optionStyle;

  /// Shown above the options when a round has no prompt text of its own.
  final String? promptLabel;

  final VoidCallback? onCompleted;

  @override
  State<ChoiceRoundsActivity> createState() => _ChoiceRoundsActivityState();
}

class _ChoiceRoundsActivityState extends State<ChoiceRoundsActivity>
    with SingleTickerProviderStateMixin {
  static const _rewardPause = Duration(milliseconds: 1400);

  late final AnimationController _reaction = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  );

  late final ActivityFeedbackController _feedback =
      ActivityFeedbackController(audio: widget.audio);

  int _roundIndex = 0;
  int _firstTryCorrect = 0;
  int? _tappedIndex;
  bool _wasCorrect = false;
  bool _retriedThisRound = false;
  bool _locked = false;
  bool _finished = false;
  Timer? _advanceTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _playPrompt());
  }

  @override
  void dispose() {
    _advanceTimer?.cancel();
    _reaction.dispose();
    _feedback.dispose();
    super.dispose();
  }

  ChoiceRound get _round => widget.rounds[_roundIndex];

  void _playPrompt() {
    if (!mounted) return;
    widget.audio.playPrompt(_round.audioPrompt);
  }

  Future<void> _onOptionTapped(int index) async {
    if (_locked || _finished) return;
    final option = _round.options[index];

    setState(() {
      _tappedIndex = index;
      _wasCorrect = option.isCorrect;
      _locked = true;
    });

    _reaction.forward(from: 0);

    if (option.isCorrect) {
      if (!_retriedThisRound) _firstTryCorrect++;
      await _feedback.celebrate();
      _advanceTimer = Timer(_rewardPause, _advance);
    } else {
      _retriedThisRound = true;
      await _feedback.tryAgain();
      // Let the child try again on the same round rather than moving on: at
      // this age the retry is the teaching moment.
      _advanceTimer = Timer(const Duration(milliseconds: 900), () {
        if (!mounted) return;
        setState(() {
          _tappedIndex = null;
          _locked = false;
        });
        _playPrompt();
      });
    }
  }

  void _advance() {
    if (!mounted) return;
    if (_roundIndex >= widget.rounds.length - 1) {
      setState(() => _finished = true);
      return;
    }
    setState(() {
      _roundIndex++;
      _tappedIndex = null;
      _locked = false;
      _retriedThisRound = false;
    });
    _playPrompt();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.rounds.isEmpty) {
      return ActivityStage(
        title: widget.title,
        isRtl: widget.isRtl,
        child: const ActivityEmptyNotice(
          message: 'This level has no rounds to play yet.',
        ),
      );
    }

    if (_finished) {
      return ActivityStage(
        title: widget.title,
        isRtl: widget.isRtl,
        child: ActivityFinishedNotice(
          correct: _firstTryCorrect,
          total: widget.rounds.length,
          onDone: widget.onCompleted,
        ),
      );
    }

    final round = _round;

    return ActivityStage(
      title: widget.title,
      isRtl: widget.isRtl,
      roundIndex: _roundIndex,
      roundCount: widget.rounds.length,
      onReplayPrompt: round.audioPrompt == null ? null : _playPrompt,
      feedback: _feedback,
      // The answers keep their full size and the page scrolls if the window
      // is too short for them. The previous Flexible let a short screen crush
      // the cards below their minimum, which clipped their contents away
      // entirely — a tall Urdu glyph simply vanished.
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tight = constraints.maxHeight < 460;
          final gap = tight ? 18.0 : 32.0;

          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (round.promptImage != null) ...[
                      _PromptCard(
                        image: round.promptImage!,
                        caption: round.promptText,
                        imageSize: tight ? 104 : 148,
                      ),
                      SizedBox(height: gap),
                    ] else if (round.promptText != null ||
                        widget.promptLabel != null) ...[
                      Text(
                        round.promptText ?? widget.promptLabel!,
                        textAlign: TextAlign.center,
                        style: Age2Text.prompt,
                      ),
                      SizedBox(height: gap),
                    ],
                    _buildOptions(round),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildOptions(ChoiceRound round) {
    final cards = [
      for (var i = 0; i < round.options.length; i++)
        _OptionCard(
          option: round.options[i],
          style: widget.optionStyle,
          isRtl: widget.isRtl,
          state: _stateFor(i),
          reaction: _reaction,
          wasCorrect: _wasCorrect,
          onTap: _locked ? null : () => _onOptionTapped(i),
        ),
    ];

    // Two options get the full width each; three or more wrap into a grid so
    // four items stay thumb-sized on a phone.
    if (cards.length <= 2) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (var i = 0; i < cards.length; i++) ...[
            if (i > 0) const SizedBox(width: 24),
            Expanded(child: cards[i]),
          ],
        ],
      );
    }

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 20,
      runSpacing: 20,
      children: [
        for (final card in cards) SizedBox(width: 156, child: card),
      ],
    );
  }

  _OptionState _stateFor(int index) {
    if (_tappedIndex != index) return _OptionState.idle;
    return _wasCorrect ? _OptionState.correct : _OptionState.wrong;
  }
}

enum _OptionState { idle, correct, wrong }

class _PromptCard extends StatelessWidget {
  const _PromptCard({
    required this.image,
    required this.imageSize,
    this.caption,
  });

  final String image;
  final double imageSize;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final palette = Age2Skin.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: Age2Surfaces.radius,
            border: Border.all(
              color: palette.accent.withValues(alpha: 0.3),
              width: 3,
            ),
            boxShadow: Age2Surfaces.lift(tint: palette.accent),
          ),
          child: ActivityAssetImage(path: image, size: imageSize),
        ),
        if (caption != null) ...[
          const SizedBox(height: 16),
          Text(caption!, style: Age2Text.cardTitle),
        ],
      ],
    );
  }
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.option,
    required this.style,
    required this.isRtl,
    required this.state,
    required this.reaction,
    required this.wasCorrect,
    this.onTap,
  });

  final ActivityOption option;
  final ChoiceOptionStyle style;
  final bool isRtl;
  final _OptionState state;
  final AnimationController reaction;
  final bool wasCorrect;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = Age2Skin.of(context);

    // Amber rather than coral for a wrong tap: at this age the retry should
    // read as "have another go", and a red edge reads as a mark against you.
    final border = switch (state) {
      _OptionState.idle => palette.accent.withValues(alpha: 0.35),
      _OptionState.correct => AppColors.leaf,
      _OptionState.wrong => AppColors.honey,
    };
    final fill = switch (state) {
      _OptionState.idle => Colors.white,
      _OptionState.correct => AppColors.mint,
      _OptionState.wrong => AppColors.lemon,
    };

    final card = PlayfulTapTarget(
      onTap: onTap,
      background: fill,
      borderColor: border,
      borderWidth: state == _OptionState.idle ? 3 : 6,
      minSize: 150,
      padding: const EdgeInsets.all(22),
      semanticLabel: option.label,
      child: _content(),
    );

    if (state == _OptionState.idle) return card;

    return AnimatedBuilder(
      animation: reaction,
      builder: (context, child) {
        if (wasCorrect) {
          // Bounce: overshoot then settle.
          final scale = 1 + Curves.elasticOut.transform(reaction.value) * 0.12;
          return Transform.scale(scale: scale, child: child);
        }
        // Shake: three passes left and right, decaying to rest.
        final shake =
            math.sin(reaction.value * math.pi * 6) * 12 * (1 - reaction.value);
        return Transform.translate(offset: Offset(shake, 0), child: child);
      },
      child: card,
    );
  }

  Widget _content() {
    if (option.image != null && option.count > 0) {
      // A plate: the same picture, that many times. Counting them is the
      // question, so they are laid out plainly rather than scaled to fit.
      final tile = (110 / option.count).clamp(22.0, 46.0).toDouble();
      return Wrap(
        alignment: WrapAlignment.center,
        spacing: 4,
        runSpacing: 4,
        children: [
          for (var i = 0; i < option.count; i++)
            ActivityAssetImage(path: option.image, size: tile),
        ],
      );
    }

    if (option.image != null) {
      return ActivityAssetImage(
        path: option.image,
        // The card stays the same size; only the picture inside it grows or
        // shrinks, so a big/small round cannot be won by aiming at the bigger
        // button.
        size: 108 * option.scale,
        silhouette: style == ChoiceOptionStyle.silhouette,
      );
    }

    final label = option.label ?? '?';

    // An Urdu round shows the letter, not its romanised name: recognising ا is
    // the skill, and "Alif" is only how the pack refers to it.
    if (isRtl) {
      final glyph = UrduLetters.glyphFor(label);
      if (glyph != null || UrduLetters.isUrduScript(label)) {
        return FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            glyph ?? label,
            textAlign: TextAlign.center,
            textDirection: TextDirection.rtl,
            style: Age2Text.urduGlyph,
          ),
        );
      }
    }

    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: Age2Text.glyph,
      ),
    );
  }
}
