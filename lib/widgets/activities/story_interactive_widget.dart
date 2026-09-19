import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/localization/urdu_letters.dart';
import '../../core/theme/age2_skin.dart';
import '../../models/activity_data.dart';
import '../../services/content/asset_availability.dart';
import 'activity_asset_image.dart';
import 'activity_audio.dart';
import 'activity_feedback_controller.dart';
import 'activity_stage.dart';
import 'playful_tap_target.dart';
import 'story_bubbles.dart';

/// Plays a narrated story, changing the picture in time with it, and pauses
/// once to ask the child a question.
///
/// Timing is driven by the narration's real playback position rather than a
/// wall clock, so a slow decode or a paused tab keeps picture and voice
/// together. When the narration is missing from the bundle the story still
/// plays — a timer stands in at the pack's declared pace — because a silent
/// story is better than a dead screen.
class StoryInteractiveWidget extends StatefulWidget {
  const StoryInteractiveWidget({
    required this.data,
    required this.audio,
    super.key,
    this.onCompleted,
  });

  final StoryInteractiveData data;
  final ActivityAudio audio;
  final VoidCallback? onCompleted;

  @override
  State<StoryInteractiveWidget> createState() => _StoryInteractiveWidgetState();
}

class _StoryInteractiveWidgetState extends State<StoryInteractiveWidget> {
  late final ActivityFeedbackController _feedback =
      ActivityFeedbackController(audio: widget.audio);

  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<void>? _completeSub;
  Timer? _fallbackTimer;
  Timer? _finishTimer;

  /// Runs the story on once the end screen has been seen.
  Timer? _advanceTimer;

  /// Guards the hand-off, so tapping Done and the timer firing cannot both
  /// pop the screen.
  bool _completed = false;

  int _frame = 0;
  bool _askingChoice = false;
  bool _finished = false;
  bool _choiceAnsweredCorrectly = false;
  int? _tappedChoice;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _completeSub?.cancel();
    _fallbackTimer?.cancel();
    _finishTimer?.cancel();
    _advanceTimer?.cancel();
    _feedback.dispose();
    widget.audio.stopPrompt();
    super.dispose();
  }

  List<StoryIllustration> get _frames => widget.data.illustrations;
  /// The question this story stops to ask, or null when it has none.
  ///
  /// A choice point with nothing to tap is treated as no choice point at all.
  /// The screen used to open the panel regardless, so a pack that named a
  /// prompt but no answers left the child looking at a question with no
  /// buttons and no way on — the story could not be finished or left except
  /// by backing out. Whatever a malformed pack says, the story has to end.
  StoryChoicePoint? get _choice {
    final choice = widget.data.choicePoint;
    if (choice == null || choice.options.isEmpty) return null;
    return choice;
  }

  Future<void> _start() async {
    final narration = widget.data.audioNarration;
    final hasNarration =
        narration != null && AssetAvailability.instance.has(narration);

    if (!hasNarration) {
      _startFallbackTimeline();
      return;
    }

    final player = widget.audio.narrationPlayer;
    _positionSub = player.onPositionChanged.listen(_onPosition);
    // If the file is shorter than the pack expected, the choice point would
    // never be reached by position alone.
    _completeSub = player.onPlayerComplete.listen((_) => _onNarrationDone());

    await widget.audio.playPrompt(narration);
  }

  /// Advances on a plain timer when there is no narration to follow, or when
  /// the narration stopped before the story did.
  void _startFallbackTimeline({Duration from = Duration.zero}) {
    const step = Duration(milliseconds: 250);
    final choice = _choice;
    // Long enough to reach the question if there is one, and otherwise to
    // leave the last picture up long enough to be looked at.
    final runUntil = choice != null && choice.atMs > 0
        ? choice.atMs + 500
        : [_lastPictureDue + 3000, 20000].reduce((a, b) => a > b ? a : b);

    var elapsed = from;
    _fallbackTimer = Timer.periodic(step, (timer) {
      elapsed += step;
      _onPosition(elapsed);
      if (elapsed.inMilliseconds > runUntil) {
        timer.cancel();
        _onNarrationDone();
      }
    });
  }

  /// When the last picture is due to be on screen.
  int get _lastPictureDue => _frames.isEmpty ? 0 : _frames.last.startMs;

  /// How far the narration actually got, so the story can carry on from there
  /// if the voice stops early.
  Duration _heard = Duration.zero;

  void _onPosition(Duration position) {
    if (!mounted || _askingChoice || _finished) return;

    _heard = position;
    final ms = position.inMilliseconds;

    var frame = 0;
    for (var i = 0; i < _frames.length; i++) {
      if (ms >= _frames[i].startMs) frame = i;
    }
    if (frame != _frame) setState(() => _frame = frame);

    final choice = _choice;
    if (choice != null && choice.atMs > 0 && ms >= choice.atMs) {
      _openChoice();
    }
  }

  void _onNarrationDone() {
    if (!mounted || _askingChoice || _finished) return;

    // A narration shorter than the story it narrates must not cut the story
    // short. Age 3's "My Day" shipped a 1.1-second clip — the title read
    // aloud rather than the story — against five pictures timed out to twenty
    // seconds, so the level ended on the first picture and the child never
    // saw the other four. A truncated file is still a valid file, so nothing
    // downstream could tell; the screen simply believed the story was over.
    //
    // Whatever the voice does, the pictures are seen: the rest of the story
    // plays on silently, exactly as it would if the narration were missing
    // altogether. The fallback timer is what tells us we are already doing
    // that, so this can only happen once.
    if (_fallbackTimer == null && _heard.inMilliseconds < _lastPictureDue) {
      _positionSub?.cancel();
      _completeSub?.cancel();
      _startFallbackTimeline(from: _heard);
      return;
    }

    if (_choice != null) {
      _openChoice();
      return;
    }
    setState(() => _finished = true);
  }

  void _complete() {
    if (!mounted || _completed) return;
    _completed = true;
    widget.onCompleted?.call();
  }

  Future<void> _openChoice() async {
    if (_askingChoice) return;
    await widget.audio.stopPrompt();
    if (!mounted) return;
    setState(() {
      _askingChoice = true;
      _frame = _frames.isEmpty ? 0 : _frames.length - 1;
    });
    final prompt = _choice?.audioPrompt;
    if (prompt != null) await widget.audio.playPrompt(prompt);
  }

  Future<void> _onChoiceTapped(int index) async {
    final choice = _choice;
    if (choice == null || _choiceAnsweredCorrectly) return;
    final option = choice.options[index];

    setState(() => _tappedChoice = index);

    if (option.isCorrect) {
      _choiceAnsweredCorrectly = true;
      await _feedback.celebrate();
      _finishTimer = Timer(const Duration(milliseconds: 1500), () {
        if (!mounted) return;
        setState(() => _finished = true);
        // Answering correctly is the end of the story, so it carries the child
        // on by itself rather than parking them on a Done button they have to
        // find. The end screen still shows first — the reward is worth seeing
        // — and a child who taps Done during it gets there sooner.
        _advanceTimer = Timer(const Duration(milliseconds: 2200), _complete);
      });
    } else {
      await _feedback.tryAgain();
      _finishTimer = Timer(const Duration(milliseconds: 900), () {
        if (mounted) setState(() => _tappedChoice = null);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_frames.isEmpty) {
      return ActivityStage(
        title: widget.data.title,
        isRtl: widget.data.isRtl,
        child: const ActivityEmptyNotice(
          message: 'This story has no pictures yet.',
        ),
      );
    }

    if (_finished) {
      return ActivityStage(
        title: widget.data.title,
        isRtl: widget.data.isRtl,
        child: ActivityFinishedNotice(
          correct: _choiceAnsweredCorrectly ? 1 : 0,
          total: _choice == null ? 0 : 1,
          onDone: _complete,
          headline: 'The end!',
        ),
      );
    }

    final frame = _frames[_frame];

    return ActivityStage(
      title: widget.data.title,
      isRtl: widget.data.isRtl,
      roundIndex: _frame,
      roundCount: _frames.length,
      feedback: _feedback,
      child: Stack(
        children: [
          // Behind the story, never in front of it.
          Positioned.fill(
            child: StoryBubbles(color: Age2Skin.of(context).accent),
          ),
          Column(
            children: [
              Expanded(
                // No key here on purpose: keying this would rebuild the
                // switcher inside it, and a switcher that is replaced never
                // gets to animate between two pages.
                child: Center(child: _StoryPage(image: frame.image)),
              ),
              if (frame.caption != null && !_askingChoice) ...[
                const SizedBox(height: 12),
                Text(
                  frame.caption!,
                  textAlign: TextAlign.center,
                  style: Age2Text.prompt,
                ),
              ],
              if (_askingChoice) ...[
                const SizedBox(height: 16),
                _ChoicePanel(
                  choice: _choice!,
                  tappedIndex: _tappedChoice,
                  onTap: _onChoiceTapped,
                ),
              ],
              const SizedBox(height: 12),
            ],
          ),
        ],
      ),
    );
  }
}

/// One illustration, turning in like a page of a board book.
///
/// The old cross-fade told the child nothing; a picture that slides and grows
/// into place says *the story moved on*, which is the sense of sequence the
/// storytelling module is teaching. Slow enough not to startle, and the
/// outgoing page leaves the same way it came.
class _StoryPage extends StatelessWidget {
  const _StoryPage({required this.image});

  final String image;

  @override
  Widget build(BuildContext context) {
    final accent = Age2Skin.of(context).accent;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 650),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.16, 0),
              end: Offset.zero,
            ).animate(animation),
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.9, end: 1).animate(animation),
              child: child,
            ),
          ),
        );
      },
      child: Container(
        key: ValueKey(image),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: Age2Surfaces.radius,
          border: Border.all(color: accent.withValues(alpha: 0.3), width: 3),
          boxShadow: Age2Surfaces.lift(tint: accent),
        ),
        child: ActivityAssetImage(path: image, size: 200),
      ),
    );
  }
}

class _ChoicePanel extends StatelessWidget {
  const _ChoicePanel({
    required this.choice,
    required this.tappedIndex,
    required this.onTap,
  });

  final StoryChoicePoint choice;
  final int? tappedIndex;
  final void Function(int index) onTap;

  @override
  Widget build(BuildContext context) {
    // Rises and settles as the narration hands over. The panel is only ever
    // built once the story pauses to ask, so this runs exactly when the child
    // needs their attention moved from watching to choosing.
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 550),
      curve: Curves.easeOutBack,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, (1 - t) * 26),
          child: child,
        ),
      ),
      child: _panel(context),
    );
  }

  Widget _panel(BuildContext context) {
    return Column(
      children: [
        Text(
          choice.promptText ?? 'What happens next?',
          textAlign: TextAlign.center,
          style: Age2Text.prompt,
        ),
        const SizedBox(height: 20),
        // Wrap, not Row: an answer can be a sentence — "Please and thank you"
        // — and a Row gives its children unbounded width, so a phrase at glyph
        // size ran straight off both sides of the phone. Here a long answer
        // takes a line of its own instead.
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 22,
          runSpacing: 16,
          children: [
            for (var i = 0; i < choice.options.length; i++)
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 280),
                child: PlayfulTapTarget(
                  onTap: () => onTap(i),
                  semanticLabel: choice.options[i].label,
                  minSize: 140,
                  padding: const EdgeInsets.all(16),
                  background: tappedIndex == i
                      ? (choice.options[i].isCorrect
                          ? AppColors.mint
                          : AppColors.lemon)
                      : Colors.white,
                  borderColor: tappedIndex == i
                      ? (choice.options[i].isCorrect
                          ? AppColors.leaf
                          // Amber, not red — see the option card in
                          // choice_rounds_activity.dart.
                          : AppColors.honey)
                      : Age2Skin.of(context).accent.withValues(alpha: 0.35),
                  borderWidth: tappedIndex == i ? 6 : 3,
                  child: choice.options[i].image != null
                      ? ActivityAssetImage(
                          path: choice.options[i].image, size: 96)
                      : _AnswerLabel(label: choice.options[i].label ?? '?'),
                ),
              ),
          ],
        ),
      ],
    );
  }
}


/// The text on an answer button, sized to what it actually says.
///
/// One glyph and one sentence are both legitimate answers here — the Urdu
/// rounds tap a letter, the manners story taps a phrase — and drawing a
/// sentence at glyph size is what pushed the button off the screen. Longer
/// answers step down in size and are allowed to wrap.
class _AnswerLabel extends StatelessWidget {
  const _AnswerLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final size = switch (label.characters.length) {
      <= 3 => 40.0,
      <= 12 => 28.0,
      _ => 22.0,
    };
    final urdu = UrduLetters.isUrduScript(label);

    return Text(
      label,
      textAlign: TextAlign.center,
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
      style: (urdu ? Age2Text.urduGlyph : Age2Text.glyph)
          .copyWith(fontSize: urdu ? size + 4 : size, height: 1.25),
    );
  }
}
