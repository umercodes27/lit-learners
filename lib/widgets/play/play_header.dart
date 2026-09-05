import 'package:flutter/material.dart';

import 'play_button.dart';
import 'play_colors.dart';

/// The top of a play screen, in place of an [AppBar].
///
/// An `AppBar` is a document chrome: a 56px bar, a 20px title, a 24px back
/// arrow. Every child screen dropped it, and the parent screens keeping it is
/// most of why they read as a different app.
///
/// This is a round back button a small hand can hit and a large title painted
/// straight onto the ground, with no bar behind it.
class PlayHeader extends StatelessWidget {
  const PlayHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onBack,
    this.trailing,
    this.titleStyle,
    this.textDirection,
    this.padding = const EdgeInsets.fromLTRB(16, 12, 16, 10),
  });

  final String title;
  final String? subtitle;

  /// Omitted when there is nowhere to go back to, so the title moves left
  /// rather than sitting next to an inert button.
  final VoidCallback? onBack;

  final Widget? trailing;

  /// Merged over the title's own style. Needed for Urdu, which the display
  /// font has no glyphs for.
  final TextStyle? titleStyle;

  /// Lays the header out right-to-left when the screen is in Urdu.
  final TextDirection? textDirection;

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final direction = textDirection ?? TextDirection.ltr;
    final align =
        direction == TextDirection.rtl ? TextAlign.right : TextAlign.left;
    final cross = direction == TextDirection.rtl
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start;

    final heading = Directionality(
      textDirection: direction,
      child: Column(
        crossAxisAlignment: cross,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: align,
            style: const TextStyle(
              fontFamily: 'Fredoka',
              fontSize: 30,
              height: 1.1,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ).merge(titleStyle),
          ),
          if (subtitle != null)
            Text(
              subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: align,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.white.withValues(alpha: 0.85),
              ).merge(titleStyle),
            ),
        ],
      ),
    );

    return Padding(
      padding: padding,
      child: Row(
        children: [
          if (onBack != null) ...[
            PlayIconButton(
              icon: Icons.arrow_back_rounded,
              semanticLabel: 'Go back',
              onPressed: onBack,
              size: 58,
            ),
            const SizedBox(width: 12),
          ],
          Expanded(child: heading),
          if (trailing != null) ...[
            const SizedBox(width: 10),
            trailing!,
          ],
        ],
      ),
    );
  }
}

/// A label above a group of cards. Replaces the small grey section headings
/// the parent dashboard used.
class PlaySectionLabel extends StatelessWidget {
  const PlaySectionLabel(
    this.label, {
    super.key,
    this.trailing,
    this.color = Colors.white,
  });

  final String label;
  final Widget? trailing;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Fredoka',
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// The white slab everything on a play screen sits in.
///
/// [JellyCard] tints itself from a colour and is right for a card that belongs
/// to a module. This is the plainer one: a white block with a thick white edge
/// and a hard drop, which is what the child screens actually use most.
class PlayPanel extends StatelessWidget {
  const PlayPanel({
    super.key,
    required this.child,
    this.color = PlayColors.card,
    this.padding = const EdgeInsets.all(16),
    this.radius = 30,
    this.borderColor = Colors.white,
  });

  final Widget child;
  final Color color;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor, width: 4),
        boxShadow: [
          BoxShadow(
            color: PlayColors.ink.withValues(alpha: 0.20),
            offset: const Offset(0, 6),
            blurRadius: 0,
          ),
        ],
      ),
      child: child,
    );
  }
}
