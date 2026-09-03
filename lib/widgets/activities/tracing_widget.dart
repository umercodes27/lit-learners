import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show PointMode;

import 'package:flutter/material.dart';

import '../../core/localization/urdu_letters.dart';
import '../../core/theme/age2_skin.dart';
import '../../models/activity_data.dart';
import '../../services/audio/glyph_speech.dart';
import '../../services/tracing/trace_glyph.dart';
import '../tracing/trace_guide_painter.dart';
import 'activity_audio.dart';
import 'activity_feedback_controller.dart';
import 'activity_stage.dart';
import 'playful_tap_target.dart';

/// Trace a letter or numeral with a finger.
///
/// The shape comes from [TraceGlyph], which lays a glyph out from the app's
/// own fonts — so one level covers A to Z, and the Urdu levels get Nastaliq,
/// with no artwork at all. The pack names Urdu letters in Latin ("Alif"), so
/// those are mapped to script before tracing: a child should be drawing ا, not
/// the word.
///
/// Nothing here can be failed. The child draws, hears the letter, and moves on
/// when they are ready — the reward is for having a go, which is the whole
/// point at this age.
class TracingWidget extends StatefulWidget {
  const TracingWidget({
    required this.data,
    required this.audio,
    super.key,
    this.onCompleted,
    this.speech,
  });

  final TracingData data;
  final ActivityAudio audio;
  final VoidCallback? onCompleted;

  /// Injectable so tests do not reach for a platform speech engine.
  final GlyphSpeech? speech;

  @override
  State<TracingWidget> createState() => _TracingWidgetState();
}

class _TracingWidgetState extends State<TracingWidget>
    with SingleTickerProviderStateMixin {
  late final ActivityFeedbackController _feedback =
      ActivityFeedbackController(audio: widget.audio);
  late final GlyphSpeech _speech = widget.speech ?? GlyphSpeech();

  late final AnimationController _arrow = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  int _index = 0;
  bool _finished = false;
  TraceGlyphLayout? _layout;
  Size _canvasSize = Size.zero;

  /// Finished strokes plus the one in progress.
  final List<List<Offset>> _strokes = [];
  List<Offset>? _current;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _announce());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduceMotion) {
      if (_arrow.isAnimating) _arrow.stop();
    } else if (!_arrow.isAnimating) {
      _arrow.repeat();
    }
  }

  @override
  void dispose() {
    _arrow.dispose();
    _feedback.dispose();
    _speech.stop();
    super.dispose();
  }

  TracingItem get _item => widget.data.items[_index];

  /// The Urdu packs name their letters in Latin; trace the script instead.
  String get _glyph => UrduLetters.glyphFor(_item.glyph) ?? _item.glyph;

  bool get _isUrdu =>
      UrduLetters.glyphFor(_item.glyph) != null ||
      UrduLetters.isUrduScript(_item.glyph);

  /// A recorded clip when the pack has one, otherwise the device's voice.
  Future<void> _announce() async {
    if (!mounted || _finished) return;
    final clip = _item.audio;
    if (clip != null) {
      await widget.audio.playPrompt(clip);
      return;
    }
    await _speech.speak(_item.glyph, urdu: _isUrdu);
  }

  Future<void> _resolveLayout(Size size) async {
    if (size.isEmpty) return;
    final layout = await TraceGlyph.resolve(glyph: _glyph, size: size);
    if (!mounted) return;
    setState(() {
      _canvasSize = size;
      _layout = layout;
    });
  }

  void _clear() => setState(() {
        _strokes.clear();
        _current = null;
      });

  Future<void> _next() async {
    await _feedback.celebrate();
    if (!mounted) return;
    if (_index >= widget.data.items.length - 1) {
      setState(() => _finished = true);
      return;
    }
    setState(() {
      _index++;
      _strokes.clear();
      _current = null;
      _layout = null;
    });
    unawaited(_resolveLayout(_canvasSize));
    await _announce();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.data.items.isEmpty) {
      return ActivityStage(
        title: widget.data.title,
        isRtl: widget.data.isRtl,
        child: const ActivityEmptyNotice(
          message: 'This level has nothing to trace yet.',
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
          headline: 'Great tracing!',
        ),
      );
    }

    final palette = Age2Skin.of(context);

    return ActivityStage(
      title: widget.data.title,
      isRtl: widget.data.isRtl,
      roundIndex: _index,
      roundCount: widget.data.items.length,
      onReplayPrompt: _announce,
      feedback: _feedback,
      child: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final side = math.min(constraints.maxWidth, constraints.maxHeight);
                final size = Size(side, side);
                if (size != _canvasSize || _layout == null) {
                  // Measuring the glyph renders it once, so it cannot happen
                  // during build.
                  WidgetsBinding.instance.addPostFrameCallback(
                    (_) => _resolveLayout(size),
                  );
                }
                return Center(
                  child: SizedBox(
                    width: side,
                    height: side,
                    child: _TraceSurface(
                      layout: _layout,
                      accent: palette.accent,
                      strokes: _strokes,
                      current: _current,
                      arrow: _arrow,
                      onStart: (point) => setState(() {
                        _current = [point];
                        _strokes.add(_current!);
                      }),
                      onMove: (point) => setState(() => _current?.add(point)),
                      onEnd: () => setState(() => _current = null),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              PlayfulTapTarget(
                onTap: _strokes.isEmpty ? null : _clear,
                semanticLabel: 'Rub it out and try again',
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                minSize: 88,
                child: Icon(Icons.refresh_rounded,
                    size: 34, color: palette.accent),
              ),
              const SizedBox(width: 18),
              PlayfulTapTarget(
                onTap: _next,
                semanticLabel: 'Next letter',
                borderColor: palette.accent,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _index >= widget.data.items.length - 1 ? 'Finish' : 'Next',
                      style: Age2Text.cardTitle,
                    ),
                    const SizedBox(width: 10),
                    Icon(Icons.arrow_forward_rounded,
                        size: 32, color: palette.accent),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The glyph guide, the child's ink, and a hint arrow, in one surface.
class _TraceSurface extends StatelessWidget {
  const _TraceSurface({
    required this.layout,
    required this.accent,
    required this.strokes,
    required this.current,
    required this.arrow,
    required this.onStart,
    required this.onMove,
    required this.onEnd,
  });

  final TraceGlyphLayout? layout;
  final Color accent;
  final List<List<Offset>> strokes;
  final List<Offset>? current;
  final Animation<double> arrow;
  final ValueChanged<Offset> onStart;
  final ValueChanged<Offset> onMove;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (details) => onStart(details.localPosition),
      onPanUpdate: (details) => onMove(details.localPosition),
      onPanEnd: (_) => onEnd(),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: Age2Surfaces.radius,
          border: Border.all(color: accent.withValues(alpha: 0.3), width: 3),
          boxShadow: Age2Surfaces.lift(tint: accent),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(
              painter: TraceGuidePainter(layout: layout, accent: accent),
            ),
            CustomPaint(
              painter: _InkPainter(strokes: strokes, colour: accent),
            ),
            if (strokes.isEmpty)
              AnimatedBuilder(
                animation: arrow,
                builder: (context, _) => CustomPaint(
                  painter: _StartArrowPainter(
                    layout: layout,
                    progress: arrow.value,
                    colour: accent,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// What the child has drawn.
class _InkPainter extends CustomPainter {
  const _InkPainter({required this.strokes, required this.colour});

  final List<List<Offset>> strokes;
  final Color colour;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = colour
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    for (final stroke in strokes) {
      if (stroke.isEmpty) continue;
      if (stroke.length == 1) {
        canvas.drawPoints(PointMode.points, stroke, paint);
        continue;
      }
      final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
      for (final point in stroke.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_InkPainter oldDelegate) => true;
}

/// A pulsing arrow showing where to begin.
///
/// Sits at the glyph's starting corner — top-left for Latin, top-right for
/// Urdu — and slides a short way in the writing direction, which is the one
/// thing a child needs to know before the first stroke.
class _StartArrowPainter extends CustomPainter {
  const _StartArrowPainter({
    required this.layout,
    required this.progress,
    required this.colour,
  });

  final TraceGlyphLayout? layout;
  final double progress;
  final Color colour;

  @override
  void paint(Canvas canvas, Size size) {
    final resolved = layout;
    if (resolved == null) return;

    final rect = resolved.inkRect;
    final rtl = resolved.textDirection == TextDirection.rtl;
    final travel = rect.width * 0.18;
    final slide = math.sin(progress * math.pi * 2) * 0.5 + 0.5;

    final start = Offset(
      rtl ? rect.right : rect.left,
      rect.top,
    );
    final tip = start.translate((rtl ? -1 : 1) * travel * slide, 0);

    final paint = Paint()
      ..color = colour.withValues(alpha: 0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(start, tip, paint);

    // Arrowhead.
    final dir = rtl ? -1.0 : 1.0;
    final head = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(tip.dx - dir * 12, tip.dy - 9)
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(tip.dx - dir * 12, tip.dy + 9);
    canvas.drawPath(head, paint);
  }

  @override
  bool shouldRepaint(_StartArrowPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.layout != layout;
}
