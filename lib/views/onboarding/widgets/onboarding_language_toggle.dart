import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/localization/onboarding_strings.dart';
import '../../../models/onboarding.dart';
import '../../../viewmodels/onboarding_viewmodel.dart';
import '../../../widgets/play/play.dart';

/// Header control that swaps the onboarding flow between English and Urdu.
///
/// Each option is labelled in its own script so a parent who reads only one of
/// the two can still find it.
///
/// Now a white pill on the screen's colour rather than a lilac one on white —
/// it sits in the play header, where the old lavender chips disappeared.
class OnboardingLanguageToggle extends StatelessWidget {
  const OnboardingLanguageToggle({super.key});

  @override
  Widget build(BuildContext context) {
    final onboarding = context.watch<OnboardingViewModel>();
    final selected = onboarding.language;

    return Tooltip(
      message: OnboardingStrings.of(selected).changeLanguage,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: PlayColors.card,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: [
            BoxShadow(
              color: PlayColors.ink.withValues(alpha: 0.18),
              offset: const Offset(0, 4),
              blurRadius: 0,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final language in OnboardingLanguage.values)
              _ToggleChip(
                language: language,
                selected: language == selected,
                onTap: () =>
                    context.read<OnboardingViewModel>().setLanguage(language),
              ),
          ],
        ),
      ),
    );
  }
}

class _ToggleChip extends StatelessWidget {
  const _ToggleChip({
    required this.language,
    required this.selected,
    required this.onTap,
  });

  final OnboardingLanguage language;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Squishy(
      semanticLabel: language.englishLabel,
      onTap: onTap,
      scale: 0.9,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: PlayMotion.settleCurve,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? PlayColors.grape : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Directionality(
          textDirection: language.textDirection,
          child: Text(
            language.nativeLabel,
            style: language.styleFor(
              TextStyle(
                fontFamily: 'Fredoka',
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: selected
                    ? Colors.white
                    : PlayColors.ink.withValues(alpha: 0.6),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
