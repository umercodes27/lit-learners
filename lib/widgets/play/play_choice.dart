import 'package:flutter/material.dart';

import 'play_colors.dart';
import 'play_motion.dart';
import 'squishy.dart';

/// One pickable answer: a chunky slab that fills with colour when chosen.
///
/// Replaces [RadioListTile], which the onboarding screens used for both the
/// language picker and the readiness test. A radio is a 20px ring next to a
/// line of text, and wrapping one in a coloured box is what throws the
/// "ListTile background color or ink splashes may be invisible" assertion the
/// readiness test has been failing on.
///
/// Chosen state is carried by the whole slab going solid, not by a small
/// glyph — that reads across the room, which is how a parent checks their
/// answers with a child on their lap.
class PlayChoice extends StatelessWidget {
  const PlayChoice({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.color = PlayColors.grape,
    this.caption,
    this.labelStyle,
    this.captionStyle,
    this.textDirection,
    this.semanticLabel,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color color;

  /// A second line under the label, in the reader's other script.
  final String? caption;

  /// Merged over the label's own style, for Urdu.
  final TextStyle? labelStyle;
  final TextStyle? captionStyle;

  final TextDirection? textDirection;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final direction = textDirection ?? TextDirection.ltr;
    final rtl = direction == TextDirection.rtl;
    final foreground = selected ? PlayColors.onGround(color) : PlayColors.ink;

    final mark = Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: selected ? Colors.white : PlayColors.cream,
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? Colors.white : color.withValues(alpha: 0.45),
          width: 3,
        ),
      ),
      child:
          selected ? Icon(Icons.check_rounded, size: 24, color: color) : null,
    );

    final text = Column(
      crossAxisAlignment:
          rtl ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          textAlign: rtl ? TextAlign.right : TextAlign.left,
          style: TextStyle(
            fontFamily: 'Fredoka',
            fontSize: 19,
            height: 1.25,
            fontWeight: FontWeight.w600,
            color: foreground,
          ).merge(labelStyle),
        ),
        if (caption != null)
          Text(
            caption!,
            textAlign: rtl ? TextAlign.right : TextAlign.left,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: foreground.withValues(alpha: 0.7),
            ).merge(captionStyle),
          ),
      ],
    );

    return Squishy(
      semanticLabel: semanticLabel ?? label,
      onTap: onTap,
      scale: 0.97,
      child: AnimatedContainer(
        duration: PlayMotion.pressDown,
        constraints: const BoxConstraints(minHeight: PlayMotion.minTouchTarget),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? color : PlayColors.card,
          borderRadius: BorderRadius.circular(PlayMotion.radius),
          border: Border.all(
            color: selected ? Colors.white : color.withValues(alpha: 0.35),
            width: 4,
          ),
          boxShadow: [
            BoxShadow(
              color: PlayColors.ink.withValues(alpha: selected ? 0.24 : 0.14),
              offset: const Offset(0, 5),
              blurRadius: 0,
            ),
          ],
        ),
        child: Directionality(
          textDirection: direction,
          child: Row(
            children: [
              mark,
              const SizedBox(width: 12),
              Expanded(child: text),
            ],
          ),
        ),
      ),
    );
  }
}
