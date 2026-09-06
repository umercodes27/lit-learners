import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/theme/age2_skin.dart';
import '../../models/activity_data.dart';
import 'activity_asset_image.dart';
import 'activity_audio.dart';
import 'activity_feedback_controller.dart';
import 'activity_stage.dart';

/// Turn two cards at a time and remember where the pictures were.
///
/// Every face is a picture the app already ships, so a board costs no new
/// artwork — the pack just names which pictures to deal.
///
/// Two decisions make this playable at four rather than merely possible. A
/// matched pair stays face up and dimmed instead of vanishing: a board that
/// empties as you go removes the very landmarks a child is using to remember
/// where things were. And a wrong pair stays visible for a beat before turning
/// back, because the whole skill being practised is looking at two cards long
/// enough to hold them.
class MemoryMatchWidget extends StatefulWidget {
  const MemoryMatchWidget({
    required this.data,
    required this.audio,
    super.key,
    this.onCompleted,
  });

  final MemoryMatchData data;
  final ActivityAudio audio;
  final VoidCallback? onCompleted;

  @override
  State<MemoryMatchWidget> createState() => _MemoryMatchWidgetState();
}

class _MemoryMatchWidgetState extends State<MemoryMatchWidget> {
  late final ActivityFeedbackController _feedback =
      ActivityFeedbackController(audio: widget.audio);

  int _index = 0;
  bool _finished = false;
  bool _locked = false;
  Timer? _flipBackTimer;
  Timer? _advanceTimer;

  late List<_Card> _cards;
  int? _firstUp;
  int? _secondUp;

  @override
  void initState() {
    super.initState();
    _deal();
  }

  @override
  void dispose() {
    _flipBackTimer?.cancel();
    _advanceTimer?.cancel();
    _feedback.dispose();
    super.dispose();
  }

  MemoryMatchItem get _item => widget.data.items[_index];

  void _deal() {
    final dealt = <_Card>[
      for (final face in _item.faces) ...[
        _Card(face: face),
        _Card(face: face),
      ],
    ];
    // Seeded by the round so a board is the same one if the child comes back
    // to it, and so the layout can be tested.
    dealt.shuffle(Random(4021 + _index * 131));
    _cards = dealt;
    _firstUp = null;
    _secondUp = null;
    _locked = false;
  }

  Future<void> _onTapped(int index) async {
    if (_locked) return;
    final card = _cards[index];
    if (card.matched || index == _firstUp) return;

    if (_firstUp == null) {
      setState(() => _firstUp = index);
      return;
    }

    setState(() {
      _secondUp = index;
      _locked = true;
    });

    final first = _cards[_firstUp!];
    if (first.face == card.face) {
      setState(() {
        first.matched = true;
        card.matched = true;
      });
      await _feedback.celebrate();
      if (!mounted) return;
      setState(() {
        _firstUp = null;
        _secondUp = null;
        _locked = false;
      });
      if (_cards.every((entry) => entry.matched)) {
        _advanceTimer = Timer(const Duration(milliseconds: 1200), _advance);
      }
      return;
    }

    await _feedback.tryAgain();
    _flipBackTimer = Timer(const Duration(milliseconds: 1100), () {
      if (!mounted) return;
      setState(() {
        _firstUp = null;
        _secondUp = null;
        _locked = false;
      });
    });
  }

  void _advance() {
    if (!mounted) return;
    if (_index >= widget.data.items.length - 1) {
      setState(() => _finished = true);
      return;
    }
    setState(() {
      _index++;
      _deal();
    });
  }

  bool _isFaceUp(int index) =>
      _cards[index].matched || index == _firstUp || index == _secondUp;

  @override
  Widget build(BuildContext context) {
    if (widget.data.isEmpty) {
      return ActivityStage(
        title: widget.data.title,
        isRtl: widget.data.isRtl,
        child: const ActivityEmptyNotice(
          message: 'This level has no cards yet.',
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
          headline: 'All pairs found!',
        ),
      );
    }

    final pairsFound = _cards.where((card) => card.matched).length ~/ 2;

    return ActivityStage(
      title: widget.data.title,
      isRtl: widget.data.isRtl,
      roundIndex: pairsFound,
      roundCount: _item.faces.length,
      feedback: _feedback,
      child: Column(
        children: [
          const Text(
            'Find the matching pairs',
            style: Age2Text.prompt,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Expanded(
            child: Center(
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: _item.columns,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                ),
                itemCount: _cards.length,
                itemBuilder: (context, index) => _CardFace(
                  card: _cards[index],
                  faceUp: _isFaceUp(index),
                  onTap: _locked ? null : () => _onTapped(index),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One dealt card. Mutable because matching flips it for the rest of the round.
class _Card {
  _Card({required this.face});

  final String face;
  bool matched = false;
}

/// A card that turns between its back and its picture.
class _CardFace extends StatelessWidget {
  const _CardFace({
    required this.card,
    required this.faceUp,
    required this.onTap,
  });

  final _Card card;
  final bool faceUp;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = Age2Skin.of(context);

    return Semantics(
      button: true,
      label: faceUp ? 'Card, face up' : 'Card, face down',
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: faceUp ? Colors.white : palette.backgroundDeep,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: card.matched
                  ? Age2Colors.clover
                  : palette.accent.withValues(alpha: faceUp ? 0.5 : 0.8),
              width: card.matched ? 5 : 3,
            ),
            boxShadow: Age2Surfaces.lift(tint: palette.accent),
          ),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 180),
            opacity: card.matched ? 0.55 : 1,
            child: faceUp
                ? Padding(
                    padding: const EdgeInsets.all(10),
                    child: ActivityAssetImage(path: card.face, size: 64),
                  )
                : Icon(
                    Icons.help_outline_rounded,
                    size: 34,
                    color: palette.accent.withValues(alpha: 0.7),
                  ),
          ),
        ),
      ),
    );
  }
}
