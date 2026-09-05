import 'package:flutter/material.dart';

import '../../../widgets/play/play.dart';

/// The frame every parent auth screen sits in.
///
/// This used to be a photographic background with carved wooden text fields
/// and a honey `FilledButton` — its own little design system, shared with
/// nothing. Arriving here from the child screens felt like leaving the app,
/// which is exactly the complaint.
///
/// It is now built from the play kit: a solid colour ground, the koala, a
/// white slab for the form, and the same chunky button a child taps. Each
/// screen gets its own [ground] colour so the three of them are still
/// distinguishable at a glance.
class AuthPageShell extends StatelessWidget {
  const AuthPageShell({
    required this.titleLeading,
    required this.titleTrailing,
    required this.child,
    this.ground = PlayColors.blueberry,
    this.accent = PlayColors.sunshine,
    super.key,
  });

  final String titleLeading;
  final String titleTrailing;
  final Widget child;

  /// The screen's colour.
  final Color ground;

  /// The second word of the title, and the colour the form's fields carry.
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: PlayGround(
        color: ground,
        safeArea: false,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (canPop)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                  child: PlayIconButton(
                    icon: Icons.arrow_back_rounded,
                    semanticLabel: 'Go back',
                    onPressed: () => Navigator.of(context).pop(),
                    size: 58,
                  ),
                ),
              Expanded(
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.fromLTRB(20, canPop ? 10 : 20, 20, 28),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 430),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const _AuthKoala(),
                          const SizedBox(height: 10),
                          _AuthTitle(
                            leading: titleLeading,
                            trailing: titleTrailing,
                            accent: accent,
                          ),
                          const SizedBox(height: 18),
                          PlayPanel(
                            padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
                            child: child,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The guide, so the parent screens carry the same character the child screens
/// do rather than being the one part of the app with nobody in it.
class _AuthKoala extends StatelessWidget {
  const _AuthKoala();

  @override
  Widget build(BuildContext context) {
    final koala = Container(
      width: 96,
      height: 96,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 4),
        boxShadow: [
          BoxShadow(
            color: PlayColors.ink.withValues(alpha: 0.22),
            offset: const Offset(0, 6),
            blurRadius: 0,
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(
        'assets/images/koala/koala_guide_portrait.png',
        height: 84,
        fit: BoxFit.contain,
      ),
    );

    return Center(child: PopIn(index: 0, child: koala));
  }
}

/// Two words, two colours, deliberately enormous.
class _AuthTitle extends StatelessWidget {
  const _AuthTitle({
    required this.leading,
    required this.trailing,
    required this.accent,
  });

  final String leading;
  final String trailing;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    const baseStyle = TextStyle(
      fontFamily: 'Fredoka',
      fontSize: 40,
      fontWeight: FontWeight.w700,
      height: 1,
      shadows: [
        Shadow(color: Color(0x33000000), blurRadius: 0, offset: Offset(0, 3)),
      ],
    );

    return Semantics(
      header: true,
      label: '$leading $trailing',
      child: ExcludeSemantics(
        child: Wrap(
          alignment: WrapAlignment.center,
          spacing: 10,
          children: [
            Text(
              leading,
              textAlign: TextAlign.center,
              style: baseStyle.copyWith(color: Colors.white),
            ),
            Text(
              trailing,
              textAlign: TextAlign.center,
              style: baseStyle.copyWith(color: accent),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Continue with Google", a white slab next to the coloured primary one.
class AuthGoogleButton extends StatelessWidget {
  const AuthGoogleButton({
    required this.onPressed,
    this.label = 'Continue with Google',
    super.key,
  });

  final VoidCallback? onPressed;
  final String label;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;

    return Squishy(
      semanticLabel: label,
      onTap: onPressed,
      child: Container(
        height: PlayMotion.minTouchTarget,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: enabled ? PlayColors.card : PlayColors.cream,
          borderRadius: BorderRadius.circular(PlayMotion.radiusLarge),
          border: Border.all(
            color: PlayColors.ink.withValues(alpha: 0.12),
            width: 3,
          ),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: PlayColors.ink.withValues(alpha: 0.18),
                    offset: const Offset(0, 5),
                    blurRadius: 0,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const _GoogleGlyph(),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Fredoka',
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: PlayColors.ink.withValues(alpha: enabled ? 1 : 0.45),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoogleGlyph extends StatelessWidget {
  const _GoogleGlyph();

  @override
  Widget build(BuildContext context) {
    // The one sweep of gradient left in the app, because it is Google's mark
    // rather than ours.
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: SweepGradient(
          colors: [
            Color(0xFF4285F4),
            Color(0xFF34A853),
            Color(0xFFFBBC05),
            Color(0xFFEA4335),
            Color(0xFF4285F4),
          ],
        ),
      ),
      child: Container(
        width: 23,
        height: 23,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
        ),
        child: const Text(
          'G',
          style: TextStyle(
            color: Color(0xFF4285F4),
            fontFamily: 'Fredoka',
            fontSize: 17,
            height: 1.1,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

/// A word between two rules, separating the password form from Google.
class AuthOrDivider extends StatelessWidget {
  const AuthOrDivider({this.label = 'or', super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final line = Expanded(
      child: Container(
        height: 3,
        decoration: BoxDecoration(
          color: PlayColors.ink.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );

    return Row(
      children: [
        line,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Fredoka',
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: PlayColors.ink.withValues(alpha: 0.45),
            ),
          ),
        ),
        line,
      ],
    );
  }
}

/// A quiet action under the form: "Create account", "Forgot password?".
///
/// Replaces the Material [TextButton]s, whose 14px label and rectangular
/// ripple were the last untouched thing on these screens. Deliberately below
/// the 72px a child gets — these are grown-up actions, and sizing every one of
/// them like the primary button would leave nothing to say which is which.
class AuthTextLink extends StatelessWidget {
  const AuthTextLink({
    super.key,
    required this.label,
    required this.onPressed,
    this.color = PlayColors.blueberry,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final foreground = color.withValues(alpha: enabled ? 1 : 0.4);

    return Squishy(
      semanticLabel: label,
      onTap: onPressed,
      scale: 0.94,
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20, color: foreground),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Fredoka',
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: foreground,
                  decoration: TextDecoration.underline,
                  decorationColor: foreground.withValues(alpha: 0.4),
                  decorationThickness: 2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The show/hide password control, as a round button instead of a bare glyph.
class AuthPeekButton extends StatelessWidget {
  const AuthPeekButton({
    super.key,
    required this.hidden,
    required this.onPressed,
  });

  final bool hidden;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return PlayIconButton(
      icon: hidden ? Icons.visibility : Icons.visibility_off,
      semanticLabel: hidden ? 'Show password' : 'Hide password',
      onPressed: onPressed,
      color: PlayColors.cream,
      iconColor: PlayColors.grape,
      size: 44,
    );
  }
}

/// "New here? Create account" — a question and the way to answer it.
class AuthFooterPrompt extends StatelessWidget {
  const AuthFooterPrompt({
    super.key,
    required this.question,
    required this.action,
    required this.onPressed,
    this.color = PlayColors.blueberry,
  });

  final String question;
  final String action;
  final VoidCallback? onPressed;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          question,
          style: TextStyle(
            fontFamily: 'Fredoka',
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: PlayColors.ink.withValues(alpha: 0.6),
          ),
        ),
        AuthTextLink(label: action, color: color, onPressed: onPressed),
      ],
    );
  }
}
