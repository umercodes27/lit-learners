import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/age2_skin.dart';
import '../../models/activity_data.dart';
import 'activity_asset_image.dart';
import 'activity_audio.dart';
import 'activity_feedback_controller.dart';
import 'activity_stage.dart';

/// Drag each thing into the place it belongs.
///
/// The zones take their artwork from the pack — a farm, a road — and fall back
/// to a plain labelled panel when a background is missing, so a level whose
/// scenery has not been drawn yet is still fully playable.
///
/// A thing dropped in the wrong zone bounces back rather than sticking. At
/// this age an undoable mistake is worse than no feedback at all.
class SortIntoZonesWidget extends StatefulWidget {
  const SortIntoZonesWidget({
    required this.data,
    required this.audio,
    super.key,
    this.onCompleted,
  });

  final SortIntoZonesData data;
  final ActivityAudio audio;
  final VoidCallback? onCompleted;

  @override
  State<SortIntoZonesWidget> createState() => _SortIntoZonesWidgetState();
}

class _SortIntoZonesWidgetState extends State<SortIntoZonesWidget> {
  late final ActivityFeedbackController _feedback =
      ActivityFeedbackController(audio: widget.audio);

  /// Index of every item already placed, by the zone it landed in.
  final Map<int, String> _placed = {};
  bool _finished = false;
  Timer? _finishTimer;

  @override
  void dispose() {
    _finishTimer?.cancel();
    _feedback.dispose();
    super.dispose();
  }

  List<int> get _remaining => [
        for (var i = 0; i < widget.data.items.length; i++)
          if (!_placed.containsKey(i)) i,
      ];

  Future<void> _onDropped(String zoneKey, int itemIndex) async {
    final item = widget.data.items[itemIndex];
    if (item.zoneKey != zoneKey) {
      await _feedback.tryAgain();
      return;
    }

    setState(() => _placed[itemIndex] = zoneKey);
    await _feedback.celebrate();

    if (_placed.length == widget.data.items.length) {
      _finishTimer = Timer(const Duration(milliseconds: 1500), () {
        if (mounted) setState(() => _finished = true);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.data.isEmpty) {
      return ActivityStage(
        title: widget.data.title,
        isRtl: widget.data.isRtl,
        child: const ActivityEmptyNotice(
          message: 'This level has nothing to sort yet.',
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
          headline: 'All sorted!',
        ),
      );
    }

    final palette = Age2Skin.of(context);
    final remaining = _remaining;

    return ActivityStage(
      title: widget.data.title,
      isRtl: widget.data.isRtl,
      roundIndex: _placed.length.clamp(0, widget.data.items.length - 1),
      roundCount: widget.data.items.length,
      feedback: _feedback,
      child: Column(
        children: [
          const Text('Put each one where it belongs', style: Age2Text.prompt),
          const SizedBox(height: 20),
          Expanded(
            child: Row(
              children: [
                for (var z = 0; z < widget.data.zones.length; z++) ...[
                  if (z > 0) const SizedBox(width: 18),
                  Expanded(
                    child: _Zone(
                      zone: widget.data.zones[z],
                      landed: [
                        for (final entry in _placed.entries)
                          if (entry.value == widget.data.zones[z].key)
                            widget.data.items[entry.key],
                      ],
                      onAccept: (index) =>
                          _onDropped(widget.data.zones[z].key, index),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),
          Container(
            height: 128,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.75),
              borderRadius: Age2Surfaces.radius,
              border: Border.all(
                color: palette.accent.withValues(alpha: 0.25),
                width: 3,
              ),
            ),
            child: remaining.isEmpty
                ? const Center(child: Text('All done!', style: Age2Text.label))
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: remaining.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 14),
                    itemBuilder: (context, i) {
                      final index = remaining[i];
                      final tile = _ItemTile(
                        image: widget.data.items[index].image,
                        accent: palette.accent,
                      );
                      return Draggable<int>(
                        data: index,
                        feedback: Material(
                          color: Colors.transparent,
                          child: Opacity(opacity: 0.9, child: tile),
                        ),
                        childWhenDragging: Opacity(opacity: 0.3, child: tile),
                        child: tile,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ItemTile extends StatelessWidget {
  const _ItemTile({required this.image, required this.accent});

  final String? image;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: Age2Surfaces.radius,
        border: Border.all(color: accent.withValues(alpha: 0.35), width: 3),
        boxShadow: Age2Surfaces.lift(tint: accent),
      ),
      child: ActivityAssetImage(path: image, size: 72),
    );
  }
}

class _Zone extends StatelessWidget {
  const _Zone({
    required this.zone,
    required this.landed,
    required this.onAccept,
  });

  final SortZone zone;
  final List<SortItem> landed;
  final ValueChanged<int> onAccept;

  /// `farm` -> `Farm`. The word is for the adult; the picture is what the
  /// child navigates by.
  String get _label => zone.key.isEmpty
      ? ''
      : zone.key[0].toUpperCase() + zone.key.substring(1);

  @override
  Widget build(BuildContext context) {
    final palette = Age2Skin.of(context);

    return DragTarget<int>(
      onAcceptWithDetails: (details) => onAccept(details.data),
      builder: (context, candidate, rejected) {
        final hovering = candidate.isNotEmpty;
        return Container(
          decoration: BoxDecoration(
            color: palette.background,
            borderRadius: Age2Surfaces.radius,
            border: Border.all(
              color: hovering
                  ? palette.accent
                  : palette.accent.withValues(alpha: 0.3),
              width: hovering ? 6 : 3,
            ),
            boxShadow: Age2Surfaces.lift(tint: palette.accent),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (zone.background != null)
                Opacity(
                  opacity: 0.55,
                  child: ActivityAssetImage(
                    path: zone.background,
                    fit: BoxFit.cover,
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        child: Text(_label, style: Age2Text.label),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final item in landed)
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppColors.mint,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                    color: AppColors.leaf, width: 2),
                              ),
                              child: ActivityAssetImage(
                                  path: item.image, size: 52),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
