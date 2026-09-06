import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/theme/age2_skin.dart';
import '../../models/activity_data.dart';
import 'activity_asset_image.dart';
import 'activity_audio.dart';
import 'activity_feedback_controller.dart';
import 'activity_stage.dart';

/// A maze carved in code, walked by dragging a character to the goal.
///
/// The grid is generated rather than drawn, so a maze costs no artwork and a
/// new one is a different seed. Generation is a depth-first carve on an odd
/// grid — walls live between cells, which is why the size is always odd — and
/// the seed is fixed per level so a child who leaves and comes back finds the
/// maze they were solving.
///
/// The drag is deliberately forgiving. A four-year-old cannot hold a line
/// through a corridor, so the finger position is snapped to the nearest cell
/// and the move is accepted when that cell is a neighbour of where the
/// character already is and no wall sits between them. Dragging into a wall
/// does not fail the level or reset anything; the character simply stays put,
/// which is what a wall means.
class MazeWidget extends StatefulWidget {
  const MazeWidget({
    required this.data,
    required this.audio,
    super.key,
    this.onCompleted,
  });

  final MazeData data;
  final ActivityAudio audio;
  final VoidCallback? onCompleted;

  @override
  State<MazeWidget> createState() => _MazeWidgetState();
}

class _MazeWidgetState extends State<MazeWidget> {
  late final ActivityFeedbackController _feedback =
      ActivityFeedbackController(audio: widget.audio);

  int _index = 0;
  bool _finished = false;
  bool _solved = false;
  Timer? _advanceTimer;

  late _Maze _maze;
  late Point<int> _at;

  @override
  void initState() {
    super.initState();
    _loadRound();
  }

  @override
  void dispose() {
    _advanceTimer?.cancel();
    _feedback.dispose();
    super.dispose();
  }

  MazeItem get _item => widget.data.items[_index];

  void _loadRound() {
    _maze = _Maze.generate(size: _item.difficulty.size, seed: _item.seed);
    _at = _maze.start;
    _solved = false;
  }

  Future<void> _moveTo(Point<int> cell) async {
    if (_solved) return;
    if (cell == _at) return;
    if (!_maze.contains(cell)) return;
    // One step at a time, and only where there is no wall. Anything else is
    // the finger having wandered, not a move.
    if (!_maze.isOpenBetween(_at, cell)) return;

    setState(() => _at = cell);

    if (cell == _maze.goal) {
      setState(() => _solved = true);
      await _feedback.celebrate();
      _advanceTimer = Timer(const Duration(milliseconds: 1600), _advance);
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
      _loadRound();
    });
  }

  void _restart() => setState(() {
        _at = _maze.start;
        _solved = false;
      });

  @override
  Widget build(BuildContext context) {
    if (widget.data.isEmpty) {
      return ActivityStage(
        title: widget.data.title,
        isRtl: widget.data.isRtl,
        child: const ActivityEmptyNotice(
          message: 'This level has no mazes yet.',
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
          headline: 'Maze solved!',
        ),
      );
    }

    return ActivityStage(
      title: widget.data.title,
      isRtl: widget.data.isRtl,
      roundIndex: _index,
      roundCount: widget.data.items.length,
      feedback: _feedback,
      onReplayPrompt: _restart,
      child: Column(
        children: [
          const Text(
            'Find the way to the star',
            style: Age2Text.prompt,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 1,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return _MazeBoard(
                      maze: _maze,
                      at: _at,
                      character: _item.character,
                      side: constraints.biggest.shortestSide,
                      onDragToCell: _moveTo,
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The drawn board, and the drag that moves the character across it.
class _MazeBoard extends StatelessWidget {
  const _MazeBoard({
    required this.maze,
    required this.at,
    required this.character,
    required this.side,
    required this.onDragToCell,
  });

  final _Maze maze;
  final Point<int> at;
  final String character;
  final double side;
  final ValueChanged<Point<int>> onDragToCell;

  @override
  Widget build(BuildContext context) {
    final palette = Age2Skin.of(context);
    final cell = side / maze.size;

    void handle(Offset local) {
      final column = (local.dx / cell).floor();
      final row = (local.dy / cell).floor();
      onDragToCell(Point(column, row));
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanUpdate: (details) => handle(details.localPosition),
      onPanStart: (details) => handle(details.localPosition),
      // A tap on a neighbouring cell moves too: some children tap their way
      // along rather than dragging, and refusing that would be refusing a
      // correct answer.
      onTapUp: (details) => handle(details.localPosition),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: palette.accent.withValues(alpha: 0.35),
            width: 3,
          ),
          boxShadow: Age2Surfaces.lift(tint: palette.accent),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _MazePainter(
                  maze: maze,
                  wall: palette.accent,
                  goalGlow: Age2Colors.butter,
                ),
              ),
            ),
            Positioned(
              left: maze.goal.x * cell,
              top: maze.goal.y * cell,
              width: cell,
              height: cell,
              child: Center(
                child: Icon(
                  Icons.star_rounded,
                  size: cell * 0.62,
                  color: Age2Colors.sunflower,
                ),
              ),
            ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 130),
              curve: Curves.easeOut,
              left: at.x * cell,
              top: at.y * cell,
              width: cell,
              height: cell,
              child: Padding(
                padding: EdgeInsets.all(cell * 0.12),
                child: ActivityAssetImage(path: character, size: cell * 0.76),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Draws the walls, and washes the cells so the corridors read as a path.
class _MazePainter extends CustomPainter {
  const _MazePainter({
    required this.maze,
    required this.wall,
    required this.goalGlow,
  });

  final _Maze maze;
  final Color wall;
  final Color goalGlow;

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.shortestSide / maze.size;
    final ground = Paint()..color = goalGlow.withValues(alpha: 0.35);
    final stroke = Paint()
      ..color = wall
      ..strokeWidth = cell * 0.18
      ..strokeCap = StrokeCap.round;

    for (var y = 0; y < maze.size; y++) {
      for (var x = 0; x < maze.size; x++) {
        if (maze.isWall(Point(x, y))) continue;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x * cell, y * cell, cell, cell),
            Radius.circular(cell * 0.18),
          ),
          ground,
        );
      }
    }

    // Walls are drawn as the blocked cells' outlines rather than as filled
    // squares: a filled grid at this scale reads as a checkerboard, not as a
    // route to follow.
    for (var y = 0; y < maze.size; y++) {
      for (var x = 0; x < maze.size; x++) {
        if (!maze.isWall(Point(x, y))) continue;
        final rect = Rect.fromLTWH(x * cell, y * cell, cell, cell);
        canvas.drawLine(rect.centerLeft, rect.centerRight, stroke);
        canvas.drawLine(rect.topCenter, rect.bottomCenter, stroke);
      }
    }
  }

  @override
  bool shouldRepaint(_MazePainter oldDelegate) => oldDelegate.maze != maze;
}

/// A maze as a grid of open cells and walls.
///
/// Odd-sized on purpose: cells sit on even coordinates and the walls between
/// them on odd ones, which is what makes "carve a wall out between two cells"
/// a single grid write.
class _Maze {
  const _Maze({required this.size, required this.open});

  factory _Maze.generate({required int size, required int seed}) {
    final open = List.generate(size, (_) => List.filled(size, false));
    final random = Random(seed);

    void carve(int x, int y) {
      open[y][x] = true;
      final directions = [
        const Point(0, -2),
        const Point(0, 2),
        const Point(-2, 0),
        const Point(2, 0),
      ]..shuffle(random);

      for (final step in directions) {
        final nx = x + step.x;
        final ny = y + step.y;
        if (nx <= 0 || ny <= 0 || nx >= size - 1 || ny >= size - 1) continue;
        if (open[ny][nx]) continue;
        // Knock out the wall between the two cells, then keep going.
        open[y + step.y ~/ 2][x + step.x ~/ 2] = true;
        carve(nx, ny);
      }
    }

    carve(1, 1);
    return _Maze(size: size, open: open);
  }

  final int size;
  final List<List<bool>> open;

  Point<int> get start => const Point(1, 1);

  Point<int> get goal => Point(size - 2, size - 2);

  bool contains(Point<int> cell) =>
      cell.x >= 0 && cell.y >= 0 && cell.x < size && cell.y < size;

  bool isWall(Point<int> cell) => !contains(cell) || !open[cell.y][cell.x];

  /// True when [from] and [to] are neighbours with no wall between them.
  bool isOpenBetween(Point<int> from, Point<int> to) {
    if (isWall(to)) return false;
    final dx = (to.x - from.x).abs();
    final dy = (to.y - from.y).abs();
    return dx + dy == 1;
  }
}
