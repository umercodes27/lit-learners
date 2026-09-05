import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../core/utils/learning_text_direction.dart';
import '../../../models/learning_level.dart';
import '../../../services/audio/app_sounds.dart';
import '../../../widgets/locked_overlay.dart';
import '../../../widgets/play/play.dart';

/// Everything the map needs to know about one level.
class LevelStopData {
  const LevelStopData({
    required this.level,
    required this.stars,
    required this.completed,
    required this.canOpen,
    required this.canDownload,
    required this.lockReason,
  });

  final LearningLevel level;
  final int stars;
  final bool completed;
  final bool canOpen;
  final bool canDownload;
  final String lockReason;

  bool get locked => !canOpen;
}

/// The shape of one module's road.
///
/// Every subject gets its own map: the bends, how far they swing and which
/// way the first one turns are all derived from the module's id, so English
/// and Maths are visibly different places rather than the same list in two
/// colours. Derived rather than hand-authored, so a module added later gets a
/// map of its own without anyone drawing one.
class MapShape {
  const MapShape({
    required this.amplitude,
    required this.frequency,
    required this.phase,
    required this.spacing,
  });

  /// How far the road swings from the centre, as a fraction of the space it
  /// is allowed.
  final double amplitude;

  /// How quickly it swings. A low value is a long lazy curve, a high one is a
  /// tight zigzag.
  final double frequency;

  /// Which way the first bend goes.
  final double phase;

  /// Distance between one stop and the next.
  final double spacing;

  static MapShape forModule(String moduleId) {
    // A stable hash, so a module's map is the same road every time a child
    // opens it. Recognising the shape is half of what makes it a place.
    var hash = 7;
    for (final unit in moduleId.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }

    return MapShape(
      amplitude: 0.62 + (hash % 5) * 0.095,
      frequency: 0.72 + ((hash >> 3) % 4) * 0.22,
      phase: (hash >> 5).isEven ? 0 : math.pi,
      spacing: 178 + ((hash >> 7) % 3) * 14,
    );
  }

  /// Where each stop sits, in a box [width] wide.
  ///
  /// [inset] keeps a whole stop card inside the box however far the road
  /// swings, so the map never overflows sideways.
  List<Offset> pointsFor({
    required int count,
    required double width,
    required double inset,
    required double topPadding,
    required bool mirror,
  }) {
    final centre = width / 2;
    final swing = math.max(0.0, (width - inset) / 2) * amplitude;

    return List<Offset>.generate(count, (index) {
      final wave = math.sin(phase + index * frequency);
      final x = centre + swing * wave;
      return Offset(
        // Urdu reads right to left, so its road runs the other way too.
        mirror ? width - x : x,
        topPadding + index * spacing,
      );
    });
  }
}

/// Joins the stops into one winding road.
///
/// The curve is a cubic through each pair of points with the control handles
/// pushed halfway down the gap, which is what turns a column of dots into a
/// road that bends.
Path buildRoad(List<Offset> points, int upTo) {
  final path = Path();
  if (points.isEmpty || upTo < 0) return path;

  path.moveTo(points.first.dx, points.first.dy);
  for (var i = 1; i <= upTo && i < points.length; i++) {
    final previous = points[i - 1];
    final current = points[i];
    final midY = previous.dy + (current.dy - previous.dy) / 2;
    path.cubicTo(
      previous.dx,
      midY,
      current.dx,
      midY,
      current.dx,
      current.dy,
    );
  }
  return path;
}

/// Paints the road, the dashed centre line, and the progress trail on top.
///
/// Three layers, in order: the whole road in pale white so a child can see
/// where the subject is going, dashes down the middle so it reads as a road
/// rather than a pipe, and the trail in sunshine over the part already
/// walked. The trail is the progress bar — it stops exactly at the stop the
/// child has reached.
class _RoadPainter extends CustomPainter {
  const _RoadPainter({
    required this.points,
    required this.reached,
  });

  final List<Offset> points;

  /// Index of the furthest stop the trail runs to.
  final int reached;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    final road = buildRoad(points, points.length - 1);

    canvas.drawPath(
      road,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 26
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = Colors.white.withValues(alpha: 0.24),
    );

    _drawDashes(canvas, road);

    if (reached > 0) {
      canvas.drawPath(
        buildRoad(points, reached),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 26
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = PlayColors.sunshine,
      );
    }
  }

  void _drawDashes(Canvas canvas, Path road) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.5);

    for (final ui.PathMetric metric in road.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = math.min(distance + 12, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance = end + 14;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RoadPainter oldDelegate) {
    return oldDelegate.reached != reached ||
        !listEquals(oldDelegate.points, points);
  }
}

bool listEquals(List<Offset> a, List<Offset> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// A module's levels as a road a child walks, one stop at a time.
///
/// Replaces the column of rows this screen used to be. A list says "here are
/// four things"; a map says "you are here, and that is where you are going",
/// which is the thing a three-year-old can read without reading.
class LevelMap extends StatelessWidget {
  const LevelMap({
    super.key,
    required this.stops,
    required this.moduleId,
    required this.accent,
    required this.textDirection,
    required this.onOpen,
    required this.onDownload,
    required this.onLocked,
    this.badgeFor,
  });

  final List<LevelStopData> stops;
  final String moduleId;

  /// The module's colour, which the finished stops fill with.
  final Color accent;

  final TextDirection textDirection;

  /// An optional count to pin on a stop's disc — how many lessons are inside
  /// it, for subjects where one stop holds several things.
  final String? Function(LevelStopData stop)? badgeFor;

  final ValueChanged<LearningLevel> onOpen;
  final ValueChanged<LearningLevel> onDownload;
  final ValueChanged<String> onLocked;

  static const _discBox = 96.0;
  static const _cardAllowance = 132.0;
  static const _topPadding = 62.0;
  static const _goalGap = 128.0;

  @override
  Widget build(BuildContext context) {
    if (stops.isEmpty) return const SizedBox.shrink();

    final shape = MapShape.forModule(moduleId);
    final completed = stops.where((stop) => stop.completed).length;
    // The trail runs to the stop the child has actually reached, which is one
    // past the last finished one.
    final reached = completed.clamp(0, stops.length - 1);
    final current = _currentIndex();

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final stopWidth = math.min(196.0, width * 0.58);
        final points = shape.pointsFor(
          count: stops.length,
          width: width,
          inset: stopWidth,
          topPadding: _topPadding,
          mirror: textDirection == TextDirection.rtl,
        );
        final height = _topPadding +
            (stops.length - 1) * shape.spacing +
            _cardAllowance +
            _goalGap;

        return SizedBox(
          width: width,
          height: height,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: _RoadPainter(points: points, reached: reached),
                  ),
                ),
              ),
              for (var index = 0; index < stops.length; index++)
                Positioned(
                  left: points[index].dx - stopWidth / 2,
                  top: points[index].dy - _discBox / 2,
                  width: stopWidth,
                  child: PopIn(
                    index: index,
                    child: _MapStop(
                      stop: stops[index],
                      accent: accent,
                      isCurrent: index == current,
                      badge: badgeFor?.call(stops[index]),
                      textDirection: textDirection,
                      onOpen: () => onOpen(stops[index].level),
                      onDownload: () => onDownload(stops[index].level),
                      onLocked: () => onLocked(stops[index].lockReason),
                    ),
                  ),
                ),
              Positioned(
                left: 0,
                right: 0,
                top: points.last.dy + shape.spacing * 0.62,
                child: Center(
                  child: _GoalMarker(
                    reached: completed >= stops.length,
                    accent: accent,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// The stop a child should tap next: the first unfinished one they are
  /// allowed into.
  int _currentIndex() {
    for (var index = 0; index < stops.length; index++) {
      final stop = stops[index];
      if (!stop.completed && stop.canOpen) return index;
    }
    return -1;
  }
}

/// One stop on the road: the disc a child taps, and the card naming what is
/// inside it.
class _MapStop extends StatelessWidget {
  const _MapStop({
    required this.stop,
    required this.accent,
    required this.isCurrent,
    required this.textDirection,
    required this.onOpen,
    required this.onDownload,
    required this.onLocked,
    this.badge,
  });

  final LevelStopData stop;
  final Color accent;
  final bool isCurrent;
  final String? badge;
  final TextDirection textDirection;
  final VoidCallback onOpen;
  final VoidCallback onDownload;
  final VoidCallback onLocked;

  @override
  Widget build(BuildContext context) {
    final level = stop.level;
    final steps = level.contentItems.length == 1
        ? '1 step'
        : '${level.contentItems.length} steps';
    // Modules that are not a sequence (Story, Drawing) carry no portion, so
    // this falls back to how much there is to work through.
    final portion =
        level.portionLabel == null ? steps : '${level.portionLabel}  ·  $steps';

    final column = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: LevelMap._discBox,
          child: Center(
            child: _StopDisc(
              number: level.levelNumber,
              accent: accent,
              completed: stop.completed,
              locked: stop.locked,
              isCurrent: isCurrent,
              badge: badge,
            ),
          ),
        ),
        const SizedBox(height: 8),
        _StopCard(
          title: level.title,
          portion: portion,
          stars: stop.stars,
          textDirection: textDirection,
          canDownload: stop.canDownload,
          onDownload: onDownload,
        ),
      ],
    );

    final blocked = stop.locked && !stop.canDownload;

    return Squishy(
      semanticLabel:
          stop.locked ? '${level.title}, locked' : 'Play ${level.title}',
      onTap: blocked ? onLocked : onOpen,
      // A stop that will not open says so, rather than chirping like one that
      // will.
      sound: blocked ? Sfx.locked : Sfx.tap,
      scale: 0.96,
      child: Stack(
        // The current stop's pointer sits above the disc's own box.
        clipBehavior: Clip.none,
        children: [
          column,
          // Kept from the list this replaced: a locked stop has to say *why*
          // it is locked, and the tooltip is the only place that reason
          // appears without tapping.
          if (blocked) LockedOverlay(reason: stop.lockReason),
        ],
      ),
    );
  }
}

/// The node itself.
///
/// Its state is carried by fill, not by a badge: finished stops are solid in
/// the module's colour, the stop you are on is sunshine and a size larger with
/// a pointer over it, and the ones ahead are pale.
class _StopDisc extends StatelessWidget {
  const _StopDisc({
    required this.number,
    required this.accent,
    required this.completed,
    required this.locked,
    required this.isCurrent,
    this.badge,
  });

  final int number;
  final Color accent;
  final bool completed;
  final bool locked;
  final bool isCurrent;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final size = isCurrent ? 88.0 : 74.0;
    final fill = completed
        ? accent
        : isCurrent
            ? PlayColors.sunshine
            : Colors.white;
    final foreground = locked
        ? PlayColors.ink.withValues(alpha: 0.4)
        : PlayColors.onGround(fill);

    final disc = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: locked ? Colors.white.withValues(alpha: 0.72) : fill,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: isCurrent ? 6 : 5),
        boxShadow: [
          BoxShadow(
            color: PlayColors.ink.withValues(alpha: 0.26),
            offset: const Offset(0, 6),
            blurRadius: 0,
          ),
        ],
      ),
      child: completed
          ? Icon(Icons.star_rounded, size: size * 0.5, color: foreground)
          : Text(
              '$number',
              style: TextStyle(
                fontFamily: 'Fredoka',
                fontSize: size * 0.42,
                height: 1,
                fontWeight: FontWeight.w700,
                color: foreground,
              ),
            ),
    );

    final withBadge = badge == null
        ? disc
        : SizedBox(
            width: size,
            height: size,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                disc,
                Positioned(
                  right: -6,
                  top: -2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    constraints: const BoxConstraints(minWidth: 28),
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: PlayColors.bubblegum,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.white, width: 3),
                    ),
                    child: Text(
                      badge!,
                      style: const TextStyle(
                        fontFamily: 'Fredoka',
                        fontSize: 14,
                        height: 1,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );

    if (!isCurrent) return withBadge;

    // A pointer over the one stop a child should touch next. Overlaid rather
    // than stacked above in a Column, so the disc's centre stays exactly on
    // the road — the trail is drawn through these points, and nudging the
    // disc down would leave the line missing it.
    //
    // Static on purpose: a map where something moves forever is a map a
    // toddler stops seeing, and it would hang every widget test on this
    // screen.
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          withBadge,
          Positioned(
            top: -28,
            child: Icon(
              Icons.arrow_drop_down_rounded,
              size: 36,
              color: Colors.white.withValues(alpha: 0.95),
            ),
          ),
        ],
      ),
    );
  }
}

/// What a child is walking towards.
///
/// A road with nothing at the end of it is a queue. This is the reason the
/// last stop is worth reaching.
class _GoalMarker extends StatelessWidget {
  const _GoalMarker({required this.reached, required this.accent});

  final bool reached;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: reached ? 'Module finished' : 'The end of this map',
      child: ExcludeSemantics(
        child: Container(
          width: 92,
          height: 92,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: reached ? PlayColors.sunshine : Colors.white.withValues(
              alpha: 0.34,
            ),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 5),
            boxShadow: [
              BoxShadow(
                color: PlayColors.ink.withValues(alpha: 0.22),
                offset: const Offset(0, 6),
                blurRadius: 0,
              ),
            ],
          ),
          child: Icon(
            Icons.emoji_events_rounded,
            size: 48,
            color: reached ? PlayColors.ink : Colors.white,
          ),
        ),
      ),
    );
  }
}

/// The label under a stop: what the level is called, and how much is in it.
class _StopCard extends StatelessWidget {
  const _StopCard({
    required this.title,
    required this.portion,
    required this.stars,
    required this.textDirection,
    required this.canDownload,
    required this.onDownload,
  });

  final String title;
  final String portion;
  final int stars;
  final TextDirection textDirection;
  final bool canDownload;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: PlayColors.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: PlayColors.ink.withValues(alpha: 0.18),
            offset: const Offset(0, 4),
            blurRadius: 0,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Directionality(
            textDirection: textDirection,
            child: Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: LearningTextDirection.styleFor(
                const TextStyle(
                  fontFamily: 'Fredoka',
                  fontSize: 17,
                  height: 1.15,
                  fontWeight: FontWeight.w600,
                  color: PlayColors.ink,
                ),
                textDirection,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            portion,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: PlayColors.ink.withValues(alpha: 0.55),
            ),
          ),
          if (stars > 0) ...[
            const SizedBox(height: 6),
            PoppingStars(count: stars, size: 20, animate: false),
          ],
          if (canDownload) ...[
            const SizedBox(height: 8),
            PlayButton(
              label: 'Download',
              icon: Icons.download_rounded,
              color: PlayColors.sky,
              onPressed: onDownload,
            ),
          ],
        ],
      ),
    );
  }
}

/// How far along the map the child is, shown above it rather than buried in
/// it.
///
/// Digits and a bar, no words: these screens run in Urdu too, and a count
/// reads the same in both.
class MapProgressBar extends StatelessWidget {
  const MapProgressBar({
    super.key,
    required this.done,
    required this.total,
  });

  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      child: Row(
        children: [
          const Icon(Icons.flag_rounded, color: Colors.white, size: 26),
          const SizedBox(width: 10),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: total == 0 ? 0.0 : done / total),
                duration: PlayMotion.enter,
                curve: PlayMotion.settleCurve,
                builder: (context, value, _) {
                  return LinearProgressIndicator(
                    value: value,
                    minHeight: 14,
                    color: PlayColors.sunshine,
                    backgroundColor: Colors.white.withValues(alpha: 0.28),
                  );
                },
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '$done/$total',
            style: const TextStyle(
              fontFamily: 'Fredoka',
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
