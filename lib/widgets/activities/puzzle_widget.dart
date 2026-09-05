import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/age2_skin.dart';
import '../../models/activity_data.dart';
import 'activity_asset_image.dart';
import 'activity_audio.dart';
import 'activity_feedback_controller.dart';
import 'activity_stage.dart';

/// Drag the pieces into their slots to rebuild the picture.
///
/// The slot count comes from the pack's `piece_count`, so the same widget does
/// the two-piece apple in the age-2 pack and a four-piece board in a later one
/// without a code change. Slots are laid out in rows of two, which keeps a
/// four-piece board square and a two-piece board side by side.
///
/// A piece only drops into its own slot. Wrong drops play the gentle retry
/// sound and bounce back rather than locking anything in, because at this age
/// an undoable mistake is worse than no feedback.
class PuzzleWidget extends StatefulWidget {
  const PuzzleWidget({
    required this.data,
    required this.audio,
    super.key,
    this.onCompleted,
  });

  final PuzzleData data;
  final ActivityAudio audio;
  final VoidCallback? onCompleted;

  @override
  State<PuzzleWidget> createState() => _PuzzleWidgetState();
}

class _PuzzleWidgetState extends State<PuzzleWidget> {
  late final ActivityFeedbackController _feedback =
      ActivityFeedbackController(audio: widget.audio);

  int _itemIndex = 0;
  Set<int> _placed = {};
  bool _finished = false;
  Timer? _advanceTimer;

  @override
  void dispose() {
    _advanceTimer?.cancel();
    _feedback.dispose();
    super.dispose();
  }

  PuzzleItem get _item => widget.data.items[_itemIndex];

  /// The pieces for the current item.
  ///
  /// A pack may ship cut-up files, or name only the whole picture and a piece
  /// count — the age-3 duck does the latter. In that case the picture is
  /// sliced into an even grid on screen, so no pre-cut artwork is needed and
  /// any `piece_count` that squares works.
  List<PuzzlePiece> get _pieces {
    final item = _item;
    if (item.pieces.isNotEmpty) {
      return [for (final path in item.pieces) PuzzlePiece.file(path)];
    }

    final full = item.fullImage;
    final count = widget.data.pieceCount;
    if (full == null || count < 2) return const [];

    final columns = count <= 3 ? count : (count / 2).ceil();
    final rows = (count / columns).ceil();
    return [
      for (var i = 0; i < count; i++)
        PuzzlePiece.slice(
          fullImage: full,
          index: i,
          columns: columns,
          rows: rows,
        ),
    ];
  }

  /// Tray order is fixed per item but not the solution order, so the child has
  /// something to work out. Reversing is enough for two pieces and stays
  /// deterministic, which keeps the screen testable.
  List<int> get _trayOrder =>
      List<int>.generate(_pieces.length, (i) => i).reversed.toList();

  Future<void> _onAccepted(int slotIndex, int pieceIndex) async {
    if (pieceIndex != slotIndex) {
      await _feedback.tryAgain();
      return;
    }

    setState(() => _placed = {..._placed, slotIndex});

    if (_placed.length < _pieces.length) return;

    await _feedback.celebrate();
    _advanceTimer = Timer(const Duration(milliseconds: 1600), _advance);
  }

  void _advance() {
    if (!mounted) return;
    if (_itemIndex >= widget.data.items.length - 1) {
      setState(() => _finished = true);
      return;
    }
    setState(() {
      _itemIndex++;
      _placed = {};
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.data.isEmpty) {
      return ActivityStage(
        title: widget.data.title,
        isRtl: widget.data.isRtl,
        child: const ActivityEmptyNotice(
          message: 'This puzzle has no pieces yet.',
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
          headline: 'You built it!',
        ),
      );
    }

    final item = _item;
    final pieces = _pieces;
    final solved = _placed.length == pieces.length;

    return ActivityStage(
      title: widget.data.title,
      isRtl: widget.data.isRtl,
      roundIndex: _itemIndex,
      roundCount: widget.data.items.length,
      feedback: _feedback,
      child: Column(
        children: [
          Text(
            solved ? 'All done!' : 'Drag the pieces together',
            style: Age2Text.prompt,
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Center(
              child: solved && item.fullImage != null
                  ? ActivityAssetImage(path: item.fullImage, size: 200)
                  : _SlotBoard(
                      pieces: pieces,
                      placed: _placed,
                      onAccepted: _onAccepted,
                    ),
            ),
          ),
          const SizedBox(height: 16),
          _PieceTray(
            pieces: pieces,
            order: _trayOrder,
            placed: _placed,
          ),
        ],
      ),
    );
  }
}

class _SlotBoard extends StatelessWidget {
  const _SlotBoard({
    required this.pieces,
    required this.placed,
    required this.onAccepted,
  });

  final List<PuzzlePiece> pieces;
  final Set<int> placed;
  final void Function(int slotIndex, int pieceIndex) onAccepted;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 16,
      runSpacing: 16,
      children: [
        for (var i = 0; i < pieces.length; i++)
          SizedBox(
            width: 136,
            height: 136,
            child: DragTarget<int>(
              onAcceptWithDetails: (details) => onAccepted(i, details.data),
              builder: (context, candidate, rejected) {
                final isPlaced = placed.contains(i);
                final hovering = candidate.isNotEmpty;
                return Container(
                  decoration: BoxDecoration(
                    color: isPlaced ? AppColors.mint : Colors.white,
                    borderRadius: Age2Surfaces.radius,
                    border: Border.all(
                      color: isPlaced
                          ? AppColors.leaf
                          : hovering
                              ? Age2Skin.of(context).accent
                              : Age2Skin.of(context)
                                  .accent
                                  .withValues(alpha: 0.3),
                      width: hovering || isPlaced ? 5 : 3,
                    ),
                  ),
                  padding: const EdgeInsets.all(8),
                  child: isPlaced
                      ? PuzzlePieceView(piece: pieces[i])
                      : Center(
                          child: Text(
                            '${i + 1}',
                            style: Age2Text.glyph.copyWith(
                              fontSize: 40,
                              color: Age2Skin.of(context)
                                  .accent
                                  .withValues(alpha: 0.45),
                            ),
                          ),
                        ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _PieceTray extends StatelessWidget {
  const _PieceTray({
    required this.pieces,
    required this.order,
    required this.placed,
  });

  final List<PuzzlePiece> pieces;
  final List<int> order;
  final Set<int> placed;

  @override
  Widget build(BuildContext context) {
    final remaining = order.where((index) => !placed.contains(index)).toList();

    return Container(
      height: 136,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.75),
        borderRadius: Age2Surfaces.radius,
        border: Border.all(
          color: Age2Skin.of(context).accent.withValues(alpha: 0.25),
          width: 3,
        ),
      ),
      child: remaining.isEmpty
          ? const Center(
              child: Text(
                'All pieces placed',
                style: Age2Text.label,
              ),
            )
          : ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: remaining.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, position) {
                final pieceIndex = remaining[position];
                final piece = pieces[pieceIndex];
                final tile = Container(
                  width: 108,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.lemon,
                    borderRadius: Age2Surfaces.radius,
                    border: Border.all(color: AppColors.honey, width: 3),
                    boxShadow: Age2Surfaces.lift(tint: AppColors.honey),
                  ),
                  child: PuzzlePieceView(piece: piece),
                );
                return Draggable<int>(
                  data: pieceIndex,
                  feedback: Material(
                    color: Colors.transparent,
                    child: Opacity(opacity: 0.9, child: tile),
                  ),
                  childWhenDragging: Opacity(opacity: 0.3, child: tile),
                  child: tile,
                );
              },
            ),
    );
  }
}


/// One piece of a puzzle: either its own file, or a slice of the whole
/// picture.
@immutable
class PuzzlePiece {
  const PuzzlePiece._({
    this.path,
    this.fullImage,
    this.index = 0,
    this.columns = 1,
    this.rows = 1,
  });

  const PuzzlePiece.file(String path) : this._(path: path);

  const PuzzlePiece.slice({
    required String fullImage,
    required int index,
    required int columns,
    required int rows,
  }) : this._(
          fullImage: fullImage,
          index: index,
          columns: columns,
          rows: rows,
        );

  final String? path;
  final String? fullImage;
  final int index;
  final int columns;
  final int rows;

  bool get isSlice => fullImage != null;

  int get column => index % columns;
  int get row => index ~/ columns;
}

/// Draws a puzzle piece.
///
/// A slice is cut with [Align]'s fractional factors rather than by decoding
/// and cropping the bytes: the widget layer already has the picture, and
/// clipping a region of it costs nothing and keeps the piece crisp at any
/// size.
class PuzzlePieceView extends StatelessWidget {
  const PuzzlePieceView({required this.piece, super.key});

  final PuzzlePiece piece;

  @override
  Widget build(BuildContext context) {
    if (!piece.isSlice) {
      return ActivityAssetImage(path: piece.path);
    }

    // -1 is the left/top edge, +1 the right/bottom; evenly spaced between.
    double axis(int position, int total) =>
        total <= 1 ? 0 : (position / (total - 1)) * 2 - 1;

    return ClipRect(
      child: Align(
        alignment: Alignment(
          axis(piece.column, piece.columns),
          axis(piece.row, piece.rows),
        ),
        widthFactor: 1 / piece.columns,
        heightFactor: 1 / piece.rows,
        child: ActivityAssetImage(path: piece.fullImage),
      ),
    );
  }
}
