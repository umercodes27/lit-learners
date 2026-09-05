import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/learning_text_direction.dart';
import '../../core/utils/module_visuals.dart';
import '../../models/canvas_work.dart';
import '../../models/drawing_stroke.dart';
import '../../models/learning_level.dart';
import '../../services/tracing/trace_glyph.dart';
import '../../viewmodels/drawing_canvas_controller.dart';
import '../../viewmodels/level_activity_viewmodel.dart';
import '../../widgets/drawing/drawing_canvas.dart';
import '../../widgets/drawing/drawing_toolbar.dart';
import '../../widgets/tracing/trace_guide_painter.dart';
import 'widgets/activity_chrome.dart';
import '../../widgets/play/play.dart';

/// Hands the finished pages to whoever is hosting the activity, which passes
/// them on to a grown-up to mark.
typedef CanvasWorkSubmitted = void Function(List<CanvasWork> work);

/// Wording the child sees on the button that ends a canvas level. Canvas work
/// is marked by a parent, so the level does not finish here — it goes to them.
const _handOverLabel = 'Show a grown-up';

/// Free drawing: one page that the child keeps adding to as the prompts move
/// on, because drawing levels are written as steps that build a single picture
/// ("draw the sky", then "draw a house under the sky").
class DrawingLevelView extends StatefulWidget {
  const DrawingLevelView({
    required this.level,
    required this.onFinish,
    super.key,
  });

  final LearningLevel level;
  final CanvasWorkSubmitted? onFinish;

  @override
  State<DrawingLevelView> createState() => _DrawingLevelViewState();
}

class _DrawingLevelViewState extends State<DrawingLevelView> {
  final DrawingCanvasController _controller = DrawingCanvasController();
  late final LevelActivityViewModel _activity;
  int _itemIndex = 0;
  int _attempt = 0;
  Size _canvasSize = Size.zero;

  /// Ink count when the current prompt started, so each step needs its own
  /// fresh marks rather than crediting what was already on the page.
  int _inkBaseline = 0;
  bool _hasNewInk = false;

  @override
  void initState() {
    super.initState();
    _activity = context.read<LevelActivityViewModel>();
    _itemIndex = _activity.itemIndex;
    _attempt = _activity.attempt;
    _activity.addListener(_onActivityChanged);
    _controller.addListener(_onCanvasChanged);
  }

  @override
  void dispose() {
    _activity.removeListener(_onActivityChanged);
    _controller
      ..removeListener(_onCanvasChanged)
      ..dispose();
    super.dispose();
  }

  void _onActivityChanged() {
    if (!mounted) return;

    if (_activity.attempt != _attempt) {
      // A parent sent the level back for more practice: a blank page again.
      _controller.clear();
      setState(() {
        _attempt = _activity.attempt;
        _itemIndex = _activity.itemIndex;
        _inkBaseline = 0;
        _hasNewInk = false;
      });
      return;
    }

    if (_activity.itemIndex == _itemIndex) return;

    setState(() {
      _itemIndex = _activity.itemIndex;
      _inkBaseline = _controller.inkStrokeCount;
      _hasNewInk = false;
    });
  }

  void _onCanvasChanged() {
    final hasNewInk = _controller.inkStrokeCount > _inkBaseline;
    if (hasNewInk == _hasNewInk || !mounted) return;

    setState(() => _hasNewInk = hasNewInk);
  }

  void _finish() {
    widget.onFinish?.call([
      CanvasWork(
        title: widget.level.title,
        prompt: widget.level.subtitle,
        canvasSize: _canvasSize,
        strokes: _controller.strokes.map((stroke) => stroke.copy()).toList(),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final activity = context.watch<LevelActivityViewModel>();
    final accent = ModuleVisuals.colorForModuleId(widget.level.moduleId);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        children: [
          CanvasLevelHeader(level: widget.level, accent: accent),
          const SizedBox(height: 10),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Remembered so the marking screen can replay the page at the
                // size it was actually drawn at.
                _canvasSize = Size(
                  constraints.maxWidth,
                  constraints.maxHeight,
                );
                return DrawingCanvas(controller: _controller);
              },
            ),
          ),
          const SizedBox(height: 10),
          DrawingToolbar(controller: _controller),
          const SizedBox(height: 10),
          _footer(activity),
        ],
      ),
    );
  }

  Widget _footer(LevelActivityViewModel activity) {
    if (!activity.currentItemComplete) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!_hasNewInk)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Draw on the page to finish this step.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          PlayButton(
            icon: Icons.check,
            label: 'I finished this step',
            onPressed: _hasNewInk ? activity.markCurrentLearned : null,
          ),
        ],
      );
    }

    if (!activity.isLastItem) {
      return PlayButton(
        icon: Icons.arrow_forward,
        label: 'Next step',
        onPressed: activity.nextItem,
      );
    }

    return PlayButton(
      icon: Icons.how_to_reg,
      label: _handOverLabel,
      onPressed: widget.onFinish == null ? null : _finish,
    );
  }
}

/// Letter and number tracing: a dotted glyph to follow, one page per letter.
///
/// Nothing here grades the child. Every page is kept as it was drawn and handed
/// to a grown-up at the end, who marks the level behind the parental lock.
class TracingLevelView extends StatefulWidget {
  const TracingLevelView({
    required this.level,
    required this.onFinish,
    super.key,
  });

  final LearningLevel level;
  final CanvasWorkSubmitted? onFinish;

  @override
  State<TracingLevelView> createState() => _TracingLevelViewState();
}

class _TracingLevelViewState extends State<TracingLevelView> {
  final DrawingCanvasController _controller = DrawingCanvasController(
    width: DrawingWidth.large,
    availableTools: const [
      DrawingTool.pen,
      DrawingTool.pencil,
      DrawingTool.brush,
      DrawingTool.eraser,
    ],
  );
  late final LevelActivityViewModel _activity;

  /// Finished pages by card index, kept so the parent sees every letter and not
  /// just the last one.
  final Map<int, CanvasWork> _captured = <int, CanvasWork>{};

  TraceGlyphLayout? _layout;
  Size _canvasSize = Size.zero;
  Size? _requestedSize;
  String? _requestedGlyph;
  int _itemIndex = 0;
  int _attempt = 0;
  bool _hasInk = false;

  @override
  void initState() {
    super.initState();
    _activity = context.read<LevelActivityViewModel>();
    _itemIndex = _activity.itemIndex;
    _attempt = _activity.attempt;
    _activity.addListener(_onActivityChanged);
    _controller.addListener(_onCanvasChanged);
  }

  @override
  void dispose() {
    _activity.removeListener(_onActivityChanged);
    _controller
      ..removeListener(_onCanvasChanged)
      ..dispose();
    super.dispose();
  }

  void _onActivityChanged() {
    if (!mounted) return;

    if (_activity.attempt != _attempt) {
      // A parent sent the level back for more practice: every page goes.
      _attempt = _activity.attempt;
      _captured.clear();
      _resetPage(_activity.itemIndex);
      return;
    }

    if (_activity.itemIndex == _itemIndex) return;

    // Keep the page that was just finished before wiping the canvas for the
    // next letter.
    final finished = _captureCurrent();
    if (finished != null) _captured[_itemIndex] = finished;
    _resetPage(_activity.itemIndex);
  }

  void _resetPage(int itemIndex) {
    _controller.clear();
    setState(() {
      _itemIndex = itemIndex;
      _hasInk = false;
      _layout = null;
      _requestedGlyph = null;
      _requestedSize = null;
    });
  }

  void _onCanvasChanged() {
    if (!mounted || _controller.hasInk == _hasInk) return;

    setState(() => _hasInk = _controller.hasInk);
  }

  CanvasWork? _captureCurrent() {
    final layout = _layout;
    if (layout == null || _canvasSize.isEmpty) return null;

    final item = widget.level.contentItems[_itemIndex];
    return CanvasWork(
      title: item.title,
      prompt: item.prompt,
      canvasSize: _canvasSize,
      strokes: _controller.strokes.map((stroke) => stroke.copy()).toList(),
      guide: layout,
    );
  }

  void _finish() {
    final work = <CanvasWork>[];
    for (var index = 0; index < widget.level.contentItems.length; index++) {
      final page = index == _itemIndex ? _captureCurrent() : _captured[index];
      if (page != null) work.add(page);
    }
    widget.onFinish?.call(work);
  }

  void _startOver() {
    _controller.clear();
    setState(() => _hasInk = false);
  }

  @override
  Widget build(BuildContext context) {
    final activity = context.watch<LevelActivityViewModel>();
    final glyph = activity.currentItem.displayText;
    final accent = ModuleVisuals.colorForModuleId(widget.level.moduleId);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        children: [
          CanvasLevelHeader(level: widget.level, accent: accent),
          const SizedBox(height: 10),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                _scheduleLayout(
                  Size(constraints.maxWidth, constraints.maxHeight),
                  glyph,
                );

                return Stack(
                  fit: StackFit.expand,
                  children: [
                    DrawingCanvas(
                      controller: _controller,
                      background: TraceGuidePainter(
                        layout: _layout,
                        accent: accent,
                      ),
                    ),
                    if (_layout == null)
                      const Center(child: CircularProgressIndicator()),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          DrawingToolbar(controller: _controller),
          const SizedBox(height: 10),
          _footer(activity),
        ],
      ),
    );
  }

  void _scheduleLayout(Size size, String glyph) {
    if (size.isEmpty) return;
    if (_requestedSize == size && _requestedGlyph == glyph) return;

    _requestedSize = size;
    _requestedGlyph = glyph;
    // Fitting the glyph rasterises it once to find its true ink bounds, so it
    // cannot run inside build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _resolveLayout(size, glyph);
    });
  }

  Future<void> _resolveLayout(Size size, String glyph) async {
    final layout = await TraceGlyph.resolve(glyph: glyph, size: size);
    if (!mounted) return;
    if (_requestedSize != size || _requestedGlyph != glyph) return;

    setState(() {
      _layout = layout;
      _canvasSize = size;
    });
  }

  Widget _footer(LevelActivityViewModel activity) {
    if (!activity.currentItemComplete) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!_hasInk)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Trace along the dots, then tap done.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _hasInk ? _startOver : null,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Start over'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: PlayButton(
                  icon: Icons.check,
                  label: 'I finished this letter',
                  onPressed: _hasInk ? activity.markCurrentLearned : null,
                ),
              ),
            ],
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _startOver,
            icon: const Icon(Icons.gesture, size: 18),
            label: const Text('Trace again'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: activity.isLastItem
              ? PlayButton(
                  icon: Icons.how_to_reg,
                  label: _handOverLabel,
                  onPressed: widget.onFinish == null ? null : _finish,
                )
              : PlayButton(
                  icon: Icons.arrow_forward,
                  label: 'Next letter',
                  onPressed: activity.nextItem,
                ),
        ),
      ],
    );
  }
}

/// Compact card header for canvas activities: the glyph, the instruction, the
/// audio cue and how far through the level the child is.
class CanvasLevelHeader extends StatelessWidget {
  const CanvasLevelHeader({
    required this.level,
    required this.accent,
    super.key,
  });

  final LearningLevel level;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final activity = context.watch<LevelActivityViewModel>();
    final item = activity.currentItem;
    final textDirection = LearningTextDirection.forLevel(level);
    final total = level.contentItems.length;
    final progress =
        (activity.itemIndex + (activity.currentItemComplete ? 1 : 0)) / total;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                ActivityBadge(text: item.displayText, size: 56, accent: accent),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: textDirection == TextDirection.rtl
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                    children: [
                      Directionality(
                        textDirection: textDirection,
                        child: Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign:
                              LearningTextDirection.alignFor(textDirection),
                          style: LearningTextDirection.styleFor(
                            Theme.of(context).textTheme.titleMedium,
                            textDirection,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Directionality(
                        textDirection: textDirection,
                        child: Text(
                          item.prompt,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign:
                              LearningTextDirection.alignFor(textDirection),
                          style: LearningTextDirection.styleFor(
                            Theme.of(context).textTheme.bodySmall,
                            textDirection,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                ContentAudioButton(audioCueKey: item.audioCueKey),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${activity.itemIndex + 1}/$total',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w900,
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
