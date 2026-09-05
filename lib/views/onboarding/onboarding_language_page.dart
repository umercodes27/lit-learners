import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/localization/onboarding_strings.dart';
import '../../core/routing/route_names.dart';
import '../../models/onboarding.dart';
import '../../viewmodels/onboarding_viewmodel.dart';
import '../../widgets/play/play.dart';

/// Sits between the parent guide and the readiness test so the parent picks
/// the language the test is written in before answering anything.
class OnboardingLanguagePage extends StatelessWidget {
  const OnboardingLanguagePage({super.key});

  @override
  Widget build(BuildContext context) {
    final onboarding = context.watch<OnboardingViewModel>();
    final language = onboarding.language;
    final strings = OnboardingStrings.of(language);

    return Scaffold(
      body: PlayGround(
        color: PlayColors.sky,
        safeArea: false,
        child: SafeArea(
          child: Directionality(
            textDirection: language.textDirection,
            child: Column(
              children: [
                PlayHeader(
                  title: strings.languageTitle,
                  textDirection: language.textDirection,
                  titleStyle: language.styleFor(null),
                  onBack: Navigator.of(context).canPop()
                      ? () => Navigator.of(context).maybePop()
                      : null,
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
                    children: [
                      PopIn(
                        index: 0,
                        child: _LanguageHero(
                          heading: strings.languageHeading,
                          subtitle: strings.languageSubtitle,
                          language: language,
                        ),
                      ),
                      const SizedBox(height: 20),
                      for (var index = 0;
                          index < OnboardingLanguage.values.length;
                          index++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: PopIn(
                            index: index + 1,
                            child: Builder(
                              builder: (context) {
                                final option =
                                    OnboardingLanguage.values[index];
                                return PlayChoice(
                                  label: option.nativeLabel,
                                  // Only when it adds something: the English
                                  // option would otherwise say "English"
                                  // twice.
                                  caption:
                                      option.nativeLabel == option.englishLabel
                                          ? null
                                          : option.englishLabel,
                                  selected: option == language,
                                  color: PlayColors.byIndex(index + 3),
                                  textDirection: option.textDirection,
                                  labelStyle: option.styleFor(null),
                                  semanticLabel: option.englishLabel,
                                  onTap: () => context
                                      .read<OnboardingViewModel>()
                                      .setLanguage(option),
                                );
                              },
                            ),
                          ),
                        ),
                      const SizedBox(height: 6),
                      PlayNote(
                        strings.languageNote,
                        align: language.textAlign,
                        style: language.styleFor(null),
                      ),
                    ],
                  ),
                ),
                // Pinned below the list rather than sitting at the end of it.
                // There are only two things to choose from, so the way onward
                // should never be something a parent has to scroll to find.
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 4, 18, 16),
                  child: PlayButton(
                    icon: Icons.arrow_forward_rounded,
                    label: strings.continueLabel,
                    labelStyle: language.styleFor(null),
                    color: PlayColors.sunshine,
                    big: true,
                    onPressed: () {
                      Navigator.of(context).pushReplacementNamed(
                        RouteNames.onboardingTest,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// What the choice is for, on the koala's white card.
class _LanguageHero extends StatelessWidget {
  const _LanguageHero({
    required this.heading,
    required this.subtitle,
    required this.language,
  });

  final String heading;
  final String subtitle;
  final OnboardingLanguage language;

  @override
  Widget build(BuildContext context) {
    return PlayPanel(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: language.textDirection == TextDirection.rtl
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: const BoxDecoration(
              color: PlayColors.grape,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.translate_rounded,
              size: 38,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            heading,
            textAlign: language.textAlign,
            style: language.styleFor(
              const TextStyle(
                fontFamily: 'Fredoka',
                fontSize: 26,
                height: 1.15,
                fontWeight: FontWeight.w600,
                color: PlayColors.ink,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: language.textAlign,
            style: language.styleFor(
              TextStyle(
                fontSize: 16,
                height: language.bodyLineHeight,
                fontWeight: FontWeight.w600,
                color: PlayColors.ink.withValues(alpha: 0.66),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
