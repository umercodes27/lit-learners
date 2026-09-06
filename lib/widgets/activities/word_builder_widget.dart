import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/localization/urdu_letters.dart';
import '../../core/theme/age2_skin.dart';
import '../../models/activity_data.dart';
import '../../services/audio/glyph_speech.dart';
import 'activity_audio.dart';
import 'activity_feedback_controller.dart';
import 'activity_stage.dart';

/// Build a word by dragging letter tiles into the blanks.
///
/// No artwork at all: both the blanks and the tiles are drawn from the fonts
/// the app already ships, which is what lets one component serve a 3-letter
/// English word and a 2-letter Urdu one. Urdu tiles are authored as romanised
/// names — `"Alif"` — and turned into script here, so a child sees ا and never
/// the English word for it.
///
/// Right-to-left assembly is not special-cased: [ActivityStage] wraps the
/// screen in the level's [Directionality], so the Urdu slots fill from the
/// right because the row lays out that way.
///
/// A tile only drops into the slot it belongs in. Letting any tile land
/// anywhere and marking the word wrong at the end would leave a four-year-old
/// with a full row of blanks and no idea which one to move; refusing the drop
/// keeps the mistake at the tile the child is holding.
class WordBuilderWidget extends StatefulWidget {
  const WordBuilderWidget({
    required this.data,
    required this.audio,
    super.key,
    this.onCompleted,
    this.speech,
  });

  final WordBuilderData data;
  final ActivityAudio audio;
  final VoidCallback? onCompleted;

  /// Injected in tests; the device's voice otherwise.
  final GlyphSpeech? speech;

  @override
  State<WordBuilderWidget> createState() => _WordBuilderWidgetState();
}

class _WordBuilderWidgetState extends State<WordBuilderWidget> {
  late final ActivityFeedbackController _feedback =
      ActivityFeedbackController(audio: widget.audio);
  late final GlyphSpeech _speech = widget.speech ?? GlyphSpeech();

  int _index = 0;
  bool _locked = false;
  bool _finished = false;
  Timer? _advanceTimer;

  /// Slot index -> the tray entry dropped there, or null while empty.
  late List<_Tile?> _slots;

  /// Tiles still to place, in the order they are offered.
  late List<_Tile> _tray;

  @override
  void initState() {
    super.initState();
    _loadRound();
    WidgetsBinding.instance.addPostFrameCallback((_) => _announce());
  }

  @override
  void dispose() {
    _advanceTimer?.cancel();
    _speech.stop();
    _feedback.dispose();
    super.dispose();
  }

  WordBuilderItem get _item => widget.data.items[_index];

  void _loadRound() {
    final tiles = [
      for (var i = 0; i < _item.tiles.length; i++)
        _Tile(id: i, label: _item.tiles[i]),
    ];
    _slots = List<_Tile?>.filled(tiles.length, null);
    _tray = _shuffled(tiles, _item.word);
  }

  /// Scrambled the same way every time for a given word.
  ///
  /// A word is only two to four tiles, so a random shuffle lands on the solved
  /// order often enough to matter — and a level that is sometimes already
  /// finished is not a level. Rotating by a hash of the word guarantees a
  /// scramble and still gives every word a different one.
  static List<_Tile> _shuffled(List<_Tile> tiles, String word) {
    if (tiles.length < 2) return tiles;
    var hash = 0;
    for (final unit in word.codeUnits) {
      hash = (hash * 31 + unit) & 0x7FFFFFFF;
    }
    final shift = 1 + hash % (tiles.length - 1);
    return [...tiles.sublist(shift), ...tiles.sublist(0, shift)];
  }

  /// The script a tile shows. Urdu names become glyphs; English letters are
  /// already what they should be.
  static String _glyphOf(String label) =>
      UrduLetters.glyphFor(label) ?? label;

  bool get _isUrdu =>
      widget.data.isRtl ||
      _item.tiles.any((tile) => UrduLetters.glyphFor(tile) != null);

  Future<void> _announce() async {
    if (!mounted || _finished) return;
    await _speech.speak(_item.word, urdu: _isUrdu);
  }

  Future<void> _onDropped(int slotIndex, _Tile tile) async {
    if (_locked) return;

    if (tile.label != _item.tiles[slotIndex]) {
      await _feedback.tryAgain();
      return;
    }

    setState(() {
      _slots[slotIndex] = tile;
      _tray = [..._tray]..removeWhere((entry) => entry.id == tile.id);
    });

    if (_slots.every((slot) => slot != null)) {
      setState(() => _locked = true);
      await _feedback.celebrate();
      unawaited(_speech.speak(_item.word, urdu: _isUrdu));
      _advanceTimer = Timer(const Duration(milliseconds: 1500), _advance);
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
      _locked = false;
      _loadRound();
    });
    _announce();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.data.isEmpty) {
      return ActivityStage(
        title: widget.data.title,
        isRtl: widget.data.isRtl,
        child: const ActivityEmptyNotice(
          message: 'This level has no words yet.',
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
          headline: 'Words built!',
        ),
      );
    }

    return ActivityStage(
      title: widget.data.title,
      isRtl: widget.data.isRtl,
      roundIndex: _index,
      roundCount: widget.data.items.length,
      feedback: _feedback,
      onReplayPrompt: _announce,
      child: SingleChildScrollView(
        child: Column(
          children: [
            const Text('Build the word', style: Age2Text.prompt),
            const SizedBox(height: 26),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 14,
              runSpacing: 14,
              children: [
                for (var i = 0; i < _slots.length; i++)
                  _Slot(
                    filled: _slots[i],
                    isUrdu: _isUrdu,
                    onAccept: (tile) => _onDropped(i, tile),
                    accepts: !_locked && _slots[i] == null,
                  ),
              ],
            ),
            const SizedBox(height: 40),
            const Text(
              'Drag the letters up',
              style: Age2Text.label,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 16,
              runSpacing: 16,
              children: [
                for (final tile in _tray)
                  _TrayTile(tile: tile, isUrdu: _isUrdu, enabled: !_locked),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// One letter, identified by position so a repeated letter is still its own
/// tile.
class _Tile {
  const _Tile({required this.id, required this.label});

  final int id;
  final String label;
}

/// A blank in the word, which fills in when the right letter lands on it.
class _Slot extends StatelessWidget {
  const _Slot({
    required this.filled,
    required this.isUrdu,
    required this.onAccept,
    required this.accepts,
  });

  final _Tile? filled;
  final bool isUrdu;
  final ValueChanged<_Tile> onAccept;
  final bool accepts;

  @override
  Widget build(BuildContext context) {
    final palette = Age2Skin.of(context);
    final tile = filled;

    return DragTarget<_Tile>(
      onWillAcceptWithDetails: (_) => accepts,
      onAcceptWithDetails: (details) => onAccept(details.data),
      builder: (context, candidate, rejected) {
        final hovering = candidate.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 84,
          height: 96,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: tile == null ? palette.background : Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: tile != null
                  ? Age2Colors.clover
                  : palette.accent.withValues(alpha: hovering ? 0.9 : 0.45),
              width: hovering || tile != null ? 5 : 4,
            ),
            boxShadow:
                tile == null ? null : Age2Surfaces.lift(tint: palette.accent),
          ),
          child: tile == null
              ? null
              : Text(
                  _WordBuilderWidgetState._glyphOf(tile.label),
                  style: isUrdu ? Age2Text.urduGlyph : Age2Text.glyph,
                ),
        );
      },
    );
  }
}

/// A letter waiting to be dragged.
class _TrayTile extends StatelessWidget {
  const _TrayTile({
    required this.tile,
    required this.isUrdu,
    required this.enabled,
  });

  final _Tile tile;
  final bool isUrdu;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final palette = Age2Skin.of(context);
    final face = _face(palette, lifted: false);

    if (!enabled) return face;

    return Draggable<_Tile>(
      data: tile,
      feedback: _face(palette, lifted: true),
      childWhenDragging: Opacity(opacity: 0.3, child: face),
      child: face,
    );
  }

  Widget _face(Age2Palette palette, {required bool lifted}) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 84,
        height: 96,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: palette.accent, width: lifted ? 5 : 4),
          boxShadow: Age2Surfaces.lift(tint: palette.accent),
        ),
        child: Text(
          _WordBuilderWidgetState._glyphOf(tile.label),
          style: isUrdu ? Age2Text.urduGlyph : Age2Text.glyph,
        ),
      ),
    );
  }
}
