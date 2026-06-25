import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/routing/route_names.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/onboarding_viewmodel.dart';
import '../../widgets/app_primary_button.dart';

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

    if (parent == null) {
      return const Scaffold(body: Center(child: Text('Parent not signed in.')));
    }

    final pages = onboarding.manualPages;
    final isLastPage = _pageIndex == pages.length - 1;

    return Scaffold(
      appBar: AppBar(title: const Text('Parent Manual')),
      body: SafeArea(
        child: pages.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
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
                          padding: const EdgeInsets.all(20),
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    _iconFor(page.iconName),
                                    size: 72,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                  ),
                                  const SizedBox(height: 18),
                                  Text(
                                    page.title,
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall
                                        ?.copyWith(
                                          fontWeight: FontWeight.w900,
                                        ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    page.body,
                                    textAlign: TextAlign.center,
                                    style:
                                        Theme.of(context).textTheme.bodyLarge,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(pages.length, (index) {
                            final selected = index == _pageIndex;
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              width: selected ? 24 : 8,
                              height: 8,
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              decoration: BoxDecoration(
                                color: selected
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.black26,
                                borderRadius: BorderRadius.circular(8),
                              ),
                            );
                          }),
                        ),
                        const SizedBox(height: 14),
                        AppPrimaryButton(
                          icon: isLastPage
                              ? Icons.assignment_turned_in
                              : Icons.arrow_forward,
                          label: isLastPage ? 'Start readiness test' : 'Next',
                          onPressed: () async {
                            if (isLastPage) {
                              await onboarding.completeManual(parent.id);
                              if (!context.mounted) return;
                              Navigator.of(context).pushReplacementNamed(
                                RouteNames.onboardingTest,
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
      _ => Icons.menu_book,
    };
  }
}
