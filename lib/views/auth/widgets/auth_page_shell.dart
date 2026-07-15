import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

const _woodLight = Color(0xFFE4AD68);
const _woodDark = Color(0xFF6F3D20);
const _woodMid = Color(0xFFA96637);

class AuthPageShell extends StatelessWidget {
  const AuthPageShell({
    required this.titleLeading,
    required this.titleTrailing,
    required this.child,
    super.key,
  });

  final String titleLeading;
  final String titleTrailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/splash/little_learners_splash.png',
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
          ),
          ColoredBox(color: Colors.white.withValues(alpha: 0.04)),
          SafeArea(
            child: Stack(
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final topSpace = (constraints.maxHeight * 0.24)
                        .clamp(126.0, 216.0)
                        .toDouble();

                    return SingleChildScrollView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: EdgeInsets.fromLTRB(24, topSpace, 24, 32),
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 410),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _AuthTitle(
                                leading: titleLeading,
                                trailing: titleTrailing,
                              ),
                              const SizedBox(height: 20),
                              child,
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
                if (Navigator.of(context).canPop())
                  Positioned(
                    left: 12,
                    top: 10,
                    child: IconButton.filled(
                      tooltip: 'Back',
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.honey,
                        foregroundColor: AppColors.coral,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: const BorderSide(color: Colors.white, width: 2),
                        ),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthTitle extends StatelessWidget {
  const _AuthTitle({required this.leading, required this.trailing});

  final String leading;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    const baseStyle = TextStyle(
      fontFamily: 'Fredoka',
      fontSize: 38,
      fontWeight: FontWeight.w800,
      height: 0.98,
      shadows: [
        Shadow(color: Color(0x556F3D20), blurRadius: 1, offset: Offset(0, 2)),
      ],
    );

    return Semantics(
      header: true,
      label: '$leading $trailing',
      child: ExcludeSemantics(
        child: Wrap(
          alignment: WrapAlignment.center,
          spacing: 10,
          runSpacing: 2,
          children: [
            Text(
              leading,
              textAlign: TextAlign.center,
              style: baseStyle.copyWith(color: AppColors.honey),
            ),
            Text(
              trailing,
              textAlign: TextAlign.center,
              style: baseStyle.copyWith(color: AppColors.coral),
            ),
          ],
        ),
      ),
    );
  }
}

class AuthWoodenTextField extends StatelessWidget {
  const AuthWoodenTextField({
    required this.controller,
    required this.label,
    required this.prefixIcon,
    this.hint,
    this.suffixIcon,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.obscureText = false,
    this.autocorrect = true,
    this.enableSuggestions = true,
    this.onSubmitted,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData prefixIcon;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final bool obscureText;
  final bool autocorrect;
  final bool enableSuggestions;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _woodLight,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(
            color: Color(0x406F3D20),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          const Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: _WoodGrainPainter()),
            ),
          ),
          TextField(
            controller: controller,
            keyboardType: keyboardType,
            textInputAction: textInputAction,
            autofillHints: autofillHints,
            obscureText: obscureText,
            autocorrect: autocorrect,
            enableSuggestions: enableSuggestions,
            onSubmitted: onSubmitted,
            cursorColor: AppColors.coral,
            style: const TextStyle(
              color: _woodDark,
              fontFamily: 'Fredoka',
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              labelText: label,
              hintText: hint,
              filled: false,
              labelStyle: const TextStyle(
                color: _woodDark,
                fontFamily: 'Fredoka',
                fontWeight: FontWeight.w700,
              ),
              floatingLabelStyle: const TextStyle(
                color: AppColors.coral,
                fontFamily: 'Fredoka',
                fontWeight: FontWeight.w800,
              ),
              hintStyle: TextStyle(
                color: _woodDark.withValues(alpha: 0.58),
                fontFamily: 'Fredoka',
              ),
              prefixIcon: Icon(prefixIcon, color: _woodDark),
              suffixIcon: suffixIcon,
              suffixIconColor: _woodDark,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: _woodDark, width: 2),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.coral, width: 3),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AuthActionButton extends StatelessWidget {
  const AuthActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    super.key,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.honey,
          foregroundColor: AppColors.coral,
          disabledBackgroundColor: AppColors.honey.withValues(alpha: 0.62),
          disabledForegroundColor: AppColors.coral.withValues(alpha: 0.62),
          elevation: 4,
          shadowColor: _woodDark.withValues(alpha: 0.28),
          textStyle: const TextStyle(
            fontFamily: 'Fredoka',
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
      ),
    );
  }
}

class AuthMessageBanner extends StatelessWidget {
  const AuthMessageBanner({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xE6FFF3B0),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.coral.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.coral),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: _woodDark,
                fontFamily: 'Fredoka',
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WoodGrainPainter extends CustomPainter {
  const _WoodGrainPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final grainPaint = Paint()
      ..color = _woodMid.withValues(alpha: 0.28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    for (final fraction in <double>[0.18, 0.42, 0.7, 0.86]) {
      final y = size.height * fraction;
      final path = Path()
        ..moveTo(-8, y)
        ..cubicTo(
          size.width * 0.24,
          y - 4,
          size.width * 0.55,
          y + 5,
          size.width + 8,
          y - 2,
        );
      canvas.drawPath(path, grainPaint);
    }

    final knotPaint = Paint()
      ..color = _woodDark.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.78, size.height * 0.3),
        width: 24,
        height: 8,
      ),
      knotPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _WoodGrainPainter oldDelegate) => false;
}
