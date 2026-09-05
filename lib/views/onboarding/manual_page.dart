import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/localization/onboarding_strings.dart';
import '../../core/routing/route_names.dart';
import '../../models/onboarding.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/onboarding_viewmodel.dart';
import '../../widgets/play/play.dart';
import 'widgets/onboarding_language_toggle.dart';

/// The parent guide, swiped one card at a time.
///
/// The cards themselves were the least bad thing on the parent path, but they
/// were purple gradient panels under an `AppBar` — the grown-up palette, on
/// the first screen a parent sees after signing up. Same cards, same words,
/// now built out of the play kit.
class ManualPage extends StatefulWidget {
  const ManualPage({super.key});

  @override
  State<ManualPage> createState() => _ManualPageState();
}

class _ManualPageState extends State<ManualPage> {
  PageController? _pageController;
  int _pageIndex = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final onboarding = context.watch<OnboardingViewModel>();
    _pageController ??= PageController(
      initialPage: onboarding.currentManualPage,
    );
    _pageIndex = onboarding.currentManualPage;
  }

  @override
  void dispose() {
    _pageController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();
    final onboarding = context.watch<OnboardingViewModel>();
    final parent = auth.parent;
    final language = onboarding.language;
    final strings = OnboardingStrings.of(language);

    if (parent == null) {
      return Scaffold(body: Center(child: Text(strings.notSignedIn)));
    }

    final pages = onboarding.manualPages;
    final isLastPage = _pageIndex == pages.length - 1;

    return Scaffold(
      body: PlayGround(
        color: PlayColors.grape,
        safeArea: false,
        child: SafeArea(
          child: Directionality(
            textDirection: language.textDirection,
            child: Column(
              children: [
                PlayHeader(
                  title: strings.manualTitle,
                  subtitle: '${strings.welcomeBack}, '
                      '${_parentLabel(parent.email)} 👋',
                  textDirection: language.textDirection,
                  titleStyle: language.styleFor(null),
                  trailing: const OnboardingLanguageToggle(),
                ),
                if (pages.isEmpty)
                  const Expanded(
                    child: Center(child: CircularProgressIndicator()),
                  )
                else ...[
                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: pages.length,
                      onPageChanged: (index) {
                        setState(() => _pageIndex = index);
                        onboarding.saveManualPage(parent.id, index);
                      },
                      itemBuilder: (context, index) {
                        final page = pages[index];
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
                          // Centred when the card fits, scrollable when it
                          // does not: Urdu bodies run taller than their
                          // English counterparts and short phones have little
                          // room.
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              return SingleChildScrollView(
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    minHeight: constraints.maxHeight,
                                  ),
                                  child: Center(
                                    child: _ManualCard(
                                      icon: _iconFor(page.iconName),
                                      color: PlayColors.byIndex(index),
                                      title: page.title,
                                      body: page.body,
                                      language: language,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (var index = 0; index < pages.length; index++)
                              _ManualProgressDot(
                                selected: index == _pageIndex,
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        PlayNote(
                          strings.guideProgressFor(
                            _pageIndex + 1,
                            pages.length,
                          ),
                          style: language.styleFor(null),
                        ),
                        const SizedBox(height: 14),
                        PlayButton(
                          icon: isLastPage
                              ? Icons.assignment_turned_in_rounded
                              : Icons.arrow_forward_rounded,
                          label: isLastPage
                              ? strings.startReadinessTest
                              : strings.next,
                          labelStyle: language.styleFor(null),
                          color: PlayColors.sunshine,
                          big: true,
                          onPressed: () async {
                            if (isLastPage) {
                              await onboarding.completeManual(parent.id);
                              if (!context.mounted) return;
                              // Straight to the picker so the parent chooses
                              // the readiness test's language first.
                              Navigator.of(context).pushReplacementNamed(
                                RouteNames.onboardingLanguage,
                              );
                              return;
                            }
                            await _pageController?.nextPage(
                              duration: const Duration(milliseconds: 220),
                              curve: Curves.easeOut,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _iconFor(String iconName) {
    return switch (iconName) {
      'family' => Icons.family_restroom,
      'timer' => Icons.timer,
      'heart' => Icons.favorite,
      'lock' => Icons.lock,
      'marking' => Icons.rate_review,
      _ => Icons.menu_book,
    };
  }
}

/// One page of the guide: a big coloured badge, a title, and the body.
class _ManualCard extends StatelessWidget {
  const _ManualCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
    required this.language,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String body;
  final OnboardingLanguage language;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 430),
      child: PlayPanel(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: Icon(icon, size: 48, color: PlayColors.onGround(color)),
            ),
            const SizedBox(height: 18),
            Directionality(
              textDirection: language.textDirection,
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: language.styleFor(
                  const TextStyle(
                    fontFamily: 'Fredoka',
                    fontSize: 28,
                    height: 1.15,
                    fontWeight: FontWeight.w600,
                    color: PlayColors.ink,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Directionality(
              textDirection: language.textDirection,
              child: Text(
                body,
                textAlign: TextAlign.center,
                style: language.styleFor(
                  TextStyle(
                    fontSize: 17,
                    height: language.bodyLineHeight,
                    fontWeight: FontWeight.w600,
                    color: PlayColors.ink.withValues(alpha: 0.68),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ManualProgressDot extends StatelessWidget {
  const _ManualProgressDot({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: PlayMotion.settleCurve,
      width: selected ? 44 : 16,
      height: 16,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: selected ? PlayColors.sunshine : Colors.white.withValues(
          alpha: 0.42,
        ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white, width: 2),
      ),
    );
  }
}

String _parentLabel(String email) {
  final name = email.split('@').first.trim();
  if (name.isEmpty) return 'Parent';
  return name[0].toUpperCase() + name.substring(1);
}
