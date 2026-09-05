import 'package:flutter/material.dart';

import 'play_colors.dart';
import 'play_motion.dart';

/// A text field made of the same parts as the rest of the play kit.
///
/// The parent screens were the last place still using Material's
/// [InputDecoration] — a hairline underline, a floating label and a 20px
/// glyph. That is a form control, and it read as a different app the moment a
/// parent arrived from the child screens.
///
/// This is the same white slab with a thick border and a hard drop that a
/// child taps everywhere else, with the icon promoted to a coloured disc and
/// the label sitting above the box rather than animating into its border.
/// A fixed label also spares the layout from a caption that changes height on
/// focus, which is what made the old wooden field awkward on a short phone.
class PlayField extends StatelessWidget {
  const PlayField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.color = PlayColors.blueberry,
    this.labelColor = Colors.white,
    this.hint,
    this.trailing,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.obscureText = false,
    this.autocorrect = true,
    this.enableSuggestions = true,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;

  /// The field's colour world — its border, its icon disc and its cursor.
  final Color color;

  /// The label above the box. White on a coloured ground, which is where most
  /// fields live; pass [PlayColors.ink] for a field inside a white panel.
  final Color labelColor;

  final String? hint;

  /// Sits inside the box, after the input. Used for the show-password toggle.
  final Widget? trailing;

  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final bool obscureText;
  final bool autocorrect;
  final bool enableSuggestions;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 6, bottom: 6),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Fredoka',
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: labelColor,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: PlayColors.card,
            borderRadius: BorderRadius.circular(PlayMotion.radius),
            border: Border.all(color: Colors.white, width: 4),
            boxShadow: [
              BoxShadow(
                color: PlayColors.ink.withValues(alpha: 0.20),
                offset: const Offset(0, 5),
                blurRadius: 0,
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                child: Icon(
                  icon,
                  size: 24,
                  color: PlayColors.onGround(color),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: keyboardType,
                  textInputAction: textInputAction,
                  autofillHints: autofillHints,
                  obscureText: obscureText,
                  autocorrect: autocorrect,
                  enableSuggestions: enableSuggestions,
                  onSubmitted: onSubmitted,
                  cursorColor: color,
                  cursorWidth: 3,
                  style: const TextStyle(
                    fontFamily: 'Fredoka',
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: PlayColors.ink,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    hintText: hint,
                    hintStyle: TextStyle(
                      fontFamily: 'Fredoka',
                      fontSize: 17,
                      fontWeight: FontWeight.w500,
                      color: PlayColors.ink.withValues(alpha: 0.35),
                    ),
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ),
      ],
    );
  }
}

/// A short line of text on a coloured ground — a caption, a hint, a rule.
class PlayNote extends StatelessWidget {
  const PlayNote(
    this.text, {
    super.key,
    this.align = TextAlign.center,
    this.style,
    this.color = Colors.white,
  });

  final String text;
  final TextAlign align;

  /// Merged over the note's own style, for scripts the display font cannot
  /// render.
  final TextStyle? style;

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: align,
      style: TextStyle(
        fontSize: 15,
        height: 1.35,
        fontWeight: FontWeight.w700,
        color: color.withValues(alpha: 0.92),
      ).merge(style),
    );
  }
}

/// Says something went wrong, or went right, without looking like a form
/// validation message.
class PlayBanner extends StatelessWidget {
  const PlayBanner({
    super.key,
    required this.message,
    this.isError = true,
  });

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    // Error is honey rather than red: this is the same app a two-year-old is
    // holding a moment later, and nothing in it shouts.
    final accent = isError ? PlayColors.tangerine : PlayColors.grass;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: PlayColors.card,
        borderRadius: BorderRadius.circular(PlayMotion.radius),
        border: Border.all(color: accent, width: 4),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
            child: Icon(
              isError ? Icons.priority_high_rounded : Icons.check_rounded,
              size: 22,
              color: PlayColors.onGround(accent),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 15,
                height: 1.3,
                fontWeight: FontWeight.w700,
                color: PlayColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
