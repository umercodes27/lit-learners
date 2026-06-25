import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/parent_account.dart';
import '../../viewmodels/onboarding_viewmodel.dart';
import 'route_names.dart';

class AuthFlowRouter {
  const AuthFlowRouter._();

  static Future<void> routeAfterAuth({
    required BuildContext context,
    required ParentAccount parent,
    bool replace = true,
  }) async {
    final onboarding = context.read<OnboardingViewModel>();
    await onboarding.loadForParent(parent.id);
    if (!context.mounted) return;

    final route = !onboarding.manualCompleted
        ? RouteNames.onboardingManual
        : !onboarding.testPassed
            ? RouteNames.onboardingTest
            : RouteNames.profiles;

    if (replace) {
      Navigator.of(context).pushReplacementNamed(route);
    } else {
      Navigator.of(context).pushNamed(route);
    }
  }
}
