import 'package:flutter/material.dart';

import 'play_colors.dart';
import 'play_motion.dart';
import 'squishy.dart';

/// The big chunky button every child screen uses.
///
/// Flat colour, a solid drop underneath rather than a blur, and a minimum
/// height far above the Material default — the old buttons were 52px of text,
/// which is a control sized for an adult reading a form.
///
/// No gradient: a solid slab with a hard shadow reads as a physical thing to
/// press, which a gradient does not.
class PlayButton extends StatelessWidget {
  const PlayButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.color = PlayColors.sunshine,
    this.textColor,
    this.big = false,
    this.expand = true,
    this.labelStyle,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color color;
  final Color? textColor;

  /// Primary action on the screen. Taller and larger type.
  final bool big;

  final bool expand;

  /// Merged over the button's own style. Needed for scripts the display font
  /// has no glyphs for, such as Urdu — without it those labels fall back to a
  /// font that cannot render them.
  final TextStyle? labelStyle;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final surface = enabled ? color : color.withValues(alpha: 0.45);
    final foreground =
        textColor ?? (enabled ? PlayColors.onGround(color) : PlayColors.ink);
    final height =
        big ? PlayMotion.primaryTouchTarget : PlayMotion.minTouchTarget;

    final button = Squishy(
      semanticLabel: label,
      onTap: onPressed,
      child: Container(
        height: height,
        padding: EdgeInsets.symmetric(horizontal: big ? 28 : 22),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(PlayMotion.radiusLarge),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.65),
            width: 3,
          ),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    offset: const Offset(0, 6),
                    blurRadius: 0,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: big ? 36 : 28, color: foreground),
              const SizedBox(width: 10),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Fredoka',
                  fontSize: big ? 26 : 21,
                  fontWeight: FontWeight.w600,
                  color: foreground,
                ).merge(labelStyle),
              ),
            ),
          ],
        ),
      ),
    );

    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// A round icon button, sized for a small hand.
///
/// Replaces the 24px `IconButton`s dotted around the child screens, which are
/// half the size a two-year-old can reliably hit.
class PlayIconButton extends StatelessWidget {
  const PlayIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.semanticLabel,
    this.color = PlayColors.card,
    this.iconColor = PlayColors.ink,
    this.size = 64,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String semanticLabel;
  final Color color;
  final Color iconColor;
  final double size;

  @override
  Widget build(BuildContext context) {
    // Tooltip as well as the semantic label: it is what a grown-up gets on a
    // long press, and the only way to name an icon that carries no text.
    return Tooltip(
      message: semanticLabel,
      child: Squishy(
        semanticLabel: semanticLabel,
        onTap: onPressed,
        scale: 0.9,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.75),
              width: 3,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.16),
                offset: const Offset(0, 4),
                blurRadius: 0,
              ),
            ],
          ),
          child: Icon(icon, color: iconColor, size: size * 0.46),
        ),
      ),
    );
  }
}
