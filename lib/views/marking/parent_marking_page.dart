import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/routing/app_router.dart';
import '../../core/utils/module_visuals.dart';
import '../../models/canvas_work.dart';
import '../../models/parent_mark.dart';
import '../../services/tracing/trace_scorer.dart';
import '../../viewmodels/active_child_session.dart';
import '../../widgets/drawing/canvas_work_preview.dart';
import '../../widgets/play/play.dart';

/// Where a grown-up grades the drawing or tracing a child has just finished.
///
/// Reached only through the parental lock, and pops the chosen [ParentMark]
/// back to the level player, which is where the consequences of the grade are
/// decided.
class ParentMarkingPage extends StatefulWidget {
  const ParentMarkingPage({
    required this.args,
    super.key,
  });

  final ParentMarkingArgs args;

  @override
  State<ParentMarkingPage> createState() => _ParentMarkingPageState();
}

class _ParentMarkingPageState extends State<ParentMarkingPage> {
  ParentMark? _selected;
  int? _accuracy;

  @override
  void initState() {
    super.initState();
    _measureTracing();
  }

  /// Runs the tracing scorer over the finished pages so the parent has a number
  /// to lean on. It is only ever a hint: the grade they pick is the mark that
  /// counts, and free drawing has nothing to measure against at all.
  Future<void> _measureTracing() async {
    final scores = <int>[];
    for (final work in widget.args.work) {
      final guide = work.guide;
      if (guide == null) return;

      final score = await TraceScorer.evaluate(
        layout: guide,
        canvasSize: work.canvasSize,
        strokes: work.strokes,
      );
      if (score.hasInk) scores.add(score.score);
    }
    if (!mounted || scores.isEmpty) return;

    setState(() {
      _accuracy = (scores.reduce((a, b) => a + b) / scores.length).round();
    });
  }

  @override
  Widget build(BuildContext context) {
    final level = widget.args.level;
    final accent = ModuleVisuals.colorForModuleId(level.moduleId);
    final childName = context.watch<ActiveChildSession>().activeChild?.name;
    final accuracy = _accuracy;

    return Scaffold(
      backgroundColor: PlayColors.cream,
      appBar: AppBar(
        toolbarHeight: 68,
        backgroundColor: PlayColors.mint,
        foregroundColor: Colors.white,
        titleTextStyle: const TextStyle(
          fontFamily: 'Fredoka',
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        title: const Text('Mark the work'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            _MarkingHeader(
              levelTitle: level.title,
              childName: childName,
              accent: accent,
            ),
            const SizedBox(height: 16),
            _WorkGallery(work: widget.args.work, accent: accent),
            if (accuracy != null) ...[
              const SizedBox(height: 12),
              _AccuracyHint(accuracy: accuracy),
            ],
            const SizedBox(height: 20),
            Text(
              'How did they do?',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 10),
            for (final mark in ParentMark.values)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _MarkOption(
                  mark: mark,
                  accent: accent,
                  selected: _selected == mark,
                  passes: mark.passes(level.passingScore),
                  onTap: () => setState(() => _selected = mark),
                ),
              ),
            const SizedBox(height: 6),
            Text(
              'A mark below ${level.passingScore}% sends this level back for '
              'more practice. Everything else unlocks what comes next.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.ink.withValues(alpha: 0.68),
                  ),
            ),
            const SizedBox(height: 18),
            PlayButton(
              icon: Icons.check_circle,
              label: 'Save this mark',
              onPressed: _selected == null
                  ? null
                  : () => Navigator.of(context).pop(_selected),
            ),
          ],
        ),
      ),
    );
  }
}

class _MarkingHeader extends StatelessWidget {
  const _MarkingHeader({
    required this.levelTitle,
    required this.childName,
    required this.accent,
  });

  final String levelTitle;
  final String? childName;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final who = childName == null ? 'Your child' : childName!;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.lavender,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.lilac.withValues(alpha: 0.58)),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.24),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(Icons.rate_review_rounded, size: 30),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$who finished $levelTitle',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Look at the page together, then choose a mark.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.ink.withValues(alpha: 0.68),
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One big page for free drawing, a row of them for a tracing level where every
/// letter was its own page.
class _WorkGallery extends StatelessWidget {
  const _WorkGallery({required this.work, required this.accent});

  final List<CanvasWork> work;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    if (work.isEmpty) {
      return const SizedBox.shrink();
    }

    if (work.length == 1) {
      return SizedBox(
        height: 280,
        child: CanvasWorkPreview(work: work.single, accent: accent),
      );
    }

    return SizedBox(
      height: 210,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: work.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final page = work[index];
          return SizedBox(
            width: 150,
            child: Column(
              children: [
                Expanded(
                  child: CanvasWorkPreview(work: page, accent: accent),
                ),
                const SizedBox(height: 6),
                Text(
                  page.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _AccuracyHint extends StatelessWidget {
  const _AccuracyHint({required this.accuracy});

  final int accuracy;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          const Icon(Icons.straighten_rounded, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$accuracy% of the line landed on the dots. This is only a '
              'measurement to help you decide — your mark is what counts.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _MarkOption extends StatelessWidget {
  const _MarkOption({
    required this.mark,
    required this.accent,
    required this.selected,
    required this.passes,
    required this.onTap,
  });

  final ParentMark mark;
  final Color accent;
  final bool selected;
  final bool passes;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? Color.alphaBlend(accent.withValues(alpha: 0.14), AppColors.panel)
          : AppColors.panel,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? accent : AppColors.line,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(mark.icon, color: passes ? accent : AppColors.coral),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mark.label,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      mark.description,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.ink.withValues(alpha: 0.68),
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${mark.score}%',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: passes ? accent : AppColors.coral,
                        ),
                  ),
                  Text(
                    mark.stars == 0
                        ? 'no stars'
                        : '${mark.stars} star${mark.stars == 1 ? '' : 's'}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
