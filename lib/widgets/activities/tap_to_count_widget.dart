import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/age2_skin.dart';
import '../../models/activity_data.dart';
import '../../services/audio/glyph_speech.dart';
import '../../services/content/asset_availability.dart';
import 'activity_asset_image.dart';
import 'activity_audio.dart';
import 'activity_feedback_controller.dart';
import 'activity_stage.dart';
import 'playful_tap_target.dart';

/// Objects appear and the child taps each one in turn, hearing the count.
///
/// The counting is the point, so a tap is only ever additive: tapping the same
/// object twice does nothing rather than un-counting it, and there is no wrong
/// answer to get. The number heard is the running total, which is what makes
/// the audio fall out of `count_audio_folder` as `1.mp3` … `5.mp3`.
///
/// Those recordings run out long before the counting does. The age-4 level is
/// called "Counting 1 to 20" and asks for fifteen stars and twenty apples, and
/// the pack ships five number clips: every tap from the sixth on played a file
/// that is not there, which is silence — on the one screen where hearing the
/// number *is* the lesson. So a missing clip is spoken instead, the same way a
/// tracing level speaks a letter nobody recorded.
class TapToCountWidget extends StatefulWidget {
  const TapToCountWidget({
    required this.data,
    required this.audio,
    super.key,
    this.onCompleted,
    this.speech,
  });

  final TapToCountData data;
  final ActivityAudio audio;
  final VoidCallback? onCompleted;

  /// Injected by the tests; a real one is built when this is null.
  final GlyphSpeech? speech;

  @override
  State<TapToCountWidget> createState() => _TapToCountWidgetState();
}

class _TapToCountWidgetState extends State<TapToCountWidget> {
  late final ActivityFeedbackController _feedback =
      ActivityFeedbackController(audio: widget.audio);
  late final GlyphSpeech _speech = widget.speech ?? GlyphSpeech();

  int _itemIndex = 0;
  Set<int> _tapped = {};
  bool _finished = false;
  Timer? _advanceTimer;

  @override
  void dispose() {
    _advanceTimer?.cancel();
    _speech.stop();
    _feedback.dispose();
    super.dispose();
  }

  TapToCountItem get _item => widget.data.items[_itemIndex];

  /// The item's own `audio_numbers` list first, then the level's shared
  /// `count_audio_folder`.
  String? _numberAsset(int number) =>
      _item.audioForCount(number, folder: widget.data.countAudioFolder);

  /// Says the running total: the recorded number where the pack has one, the
  /// device voice where it does not.
  ///
  /// What decides this is whether the file exists, not whether the level named
  /// a folder to look in — a named-but-absent clip is the case that leaves a
  /// child counting in silence.
  Future<void> _sayCount(int number) async {
    final clip = _numberAsset(number);
    if (clip != null && AssetAvailability.instance.has(clip)) {
      await widget.audio.playPrompt(clip);
      return;
    }
    await _speech.speak('$number');
  }

  Future<void> _onObjectTapped(int index) async {
    if (_tapped.contains(index) || _finished) return;

    final next = _tapped.length + 1;
    setState(() => _tapped = {..._tapped, index});

    await _sayCount(next);

    if (next < _item.targetCount) return;

    // Whole set counted — celebrate, then move to the next set.
    _advanceTimer = Timer(const Duration(milliseconds: 700), () async {
      if (!mounted) return;
      await _feedback.celebrate();
      _advanceTimer = Timer(const Duration(milliseconds: 1300), _advance);
    });
  }

  void _advance() {
    if (!mounted) return;
    if (_itemIndex >= widget.data.items.length - 1) {
      setState(() => _finished = true);
      return;
    }
    setState(() {
      _itemIndex++;
      _tapped = {};
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.data.items.isEmpty) {
      return ActivityStage(
        title: widget.data.title,
        isRtl: widget.data.isRtl,
        child: const ActivityEmptyNotice(
          message: 'This level has nothing to count yet.',
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
          headline: 'Great counting!',
        ),
      );
    }

    final item = _item;
    final count = item.targetCount;

    return ActivityStage(
      title: widget.data.title,
      isRtl: widget.data.isRtl,
      roundIndex: _itemIndex,
      roundCount: widget.data.items.length,
      feedback: _feedback,
      child: Column(
        children: [
          const Text('Tap each one and count', style: Age2Text.prompt),
          const SizedBox(height: 20),
          _CountBadge(counted: _tapped.length, target: count),
          const SizedBox(height: 20),
          Expanded(
            child: SingleChildScrollView(
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 20,
                runSpacing: 20,
                children: [
                  for (var i = 0; i < count; i++)
                    _CountableObject(
                      image: item.objectImage,
                      counted: _tapped.contains(i),
                      order: _orderOf(i),
                      onTap: () => _onObjectTapped(i),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The number this object was given when it was tapped, so the child can see
  /// the count they built rather than just a tick.
  int? _orderOf(int index) {
    if (!_tapped.contains(index)) return null;
    // Sets keep insertion order in Dart, so position in the set is the order
    // the objects were tapped in.
    return _tapped.toList().indexOf(index) + 1;
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.counted, required this.target});

  final int counted;
  final int target;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.lavender,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: AppColors.lilac, width: 2),
      ),
      child: Text('$counted / $target', style: Age2Text.cardTitle),
    );
  }
}

class _CountableObject extends StatelessWidget {
  const _CountableObject({
    required this.image,
    required this.counted,
    required this.order,
    required this.onTap,
  });

  final String? image;
  final bool counted;
  final int? order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = Age2Skin.of(context);

    return PlayfulTapTarget(
      onTap: onTap,
      background: counted ? AppColors.mint : Colors.white,
      borderColor: counted ? AppColors.leaf : palette.accent.withValues(alpha: 0.35),
      borderWidth: counted ? 5 : 3,
      minSize: 116,
      padding: const EdgeInsets.all(12),
      child: SizedBox(
        width: 92,
        height: 92,
        child: Stack(
            children: [
              Center(child: ActivityAssetImage(path: image, size: 78)),
              if (order != null)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: AppColors.leaf,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$order',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
            ],
        ),
      ),
    );
  }
}
