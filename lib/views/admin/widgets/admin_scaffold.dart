import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/routing/route_names.dart';
import '../../../viewmodels/admin_auth_viewmodel.dart';
import '../../../viewmodels/admin_stats_viewmodel.dart';
import 'admin_theme.dart';

// Re-exported so an admin screen only has to import the scaffold to get the
// whole visual vocabulary.
export 'admin_theme.dart';

/// Shared chrome for admin screens.
///
/// Guards every page behind the admin session so a deep link cannot bypass
/// UC-18, and hosts the UC-20 logout affordance.
///
/// The header is the same grape/violet gradient the parent dashboard uses, so
/// crossing into the admin area does not look like leaving the app.
class AdminScaffold extends StatelessWidget {
  const AdminScaffold({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.actions = const [],
    this.showLogout = false,
    this.floatingActionButton,
  });

  final String title;

  /// Second line under the title, for saying what the screen is for.
  final String? subtitle;

  final Widget child;

  /// Icon actions. Rendered on a translucent white chip so a bare white glyph
  /// does not vanish into the light end of the gradient.
  final List<Widget> actions;

  final bool showLogout;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    final adminAuth = context.watch<AdminAuthViewModel>();

    if (!adminAuth.isAuthenticated) {
      return const AdminAccessDenied();
    }

    return Scaffold(
      backgroundColor: AppColors.cloud,
      appBar: AppBar(
        toolbarHeight: 72,
        backgroundColor: AppColors.grape,
        foregroundColor: Colors.white,
        // A childless `DecoratedBox` collapses to zero height under the app
        // bar's loose constraints, which leaves the gradient invisible;
        // `Container` expands into them instead.
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: AdminPalette.headerGradient,
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
        actions: [
          ...actions,
          if (showLogout) ...[
            const SizedBox(width: 4),
            IconButton.filled(
              tooltip: 'Log out',
              style: IconButton.styleFrom(
                backgroundColor: AppColors.coral,
                foregroundColor: Colors.white,
              ),
              onPressed: adminAuth.isLoading
                  ? null
                  : () => confirmAdminLogout(context),
              icon: const Icon(Icons.logout_rounded),
            ),
          ],
          const SizedBox(width: 12),
        ],
      ),
      body: SafeArea(child: child),
      floatingActionButton: floatingActionButton,
    );
  }
}

/// Header action styled to stay legible on the gradient.
class AdminHeaderAction extends StatelessWidget {
  const AdminHeaderAction({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton.filled(
      tooltip: tooltip,
      style: IconButton.styleFrom(
        backgroundColor: Colors.white.withValues(alpha: 0.16),
        foregroundColor: Colors.white,
        disabledBackgroundColor: Colors.white.withValues(alpha: 0.08),
        disabledForegroundColor: Colors.white54,
      ),
      onPressed: onPressed,
      icon: Icon(icon),
    );
  }
}

/// UC-20: confirm, terminate the session, return to the admin login screen.
Future<void> confirmAdminLogout(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      icon: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: AppColors.coral.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.logout_rounded, color: AppColors.coral),
      ),
      title: const Text('Log out?'),
      content: const Text(
        'This will end your admin session and return you to the login screen.',
        textAlign: TextAlign.center,
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('No'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.coral),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Yes, log out'),
        ),
      ],
    ),
  );

  if (confirmed != true || !context.mounted) return;

  final adminAuth = context.read<AdminAuthViewModel>();
  final statsViewModel = context.read<AdminStatsViewModel>();
  final navigator = Navigator.of(context);
  final messenger = ScaffoldMessenger.of(context);

  final signedOut = await adminAuth.signOut();

  if (!signedOut) {
    // Alternative flow: logout failed, offer a retry rather than stranding
    // the admin in a half-open session.
    messenger.showSnackBar(
      SnackBar(
        content: Text(adminAuth.errorMessage ?? 'Logout failed.'),
        action: SnackBarAction(
          label: 'Retry',
          onPressed: () {
            if (context.mounted) confirmAdminLogout(context);
          },
        ),
      ),
    );
    return;
  }

  statsViewModel.reset();

  // Pop back out of the admin section to whatever the admin came from.
  //
  // This used to clear the whole stack, which left the app with nothing
  // underneath: pressing back after logging out then popped the last route
  // and showed a blank screen the app could not be navigated out of. Admin is
  // always entered with pushNamed from the login page or the parent
  // dashboard, so the app the admin arrived from is still down there.
  navigator.popUntil((route) => route.isFirst || !_isAdminRoute(route));
}

/// Every admin screen lives under `/admin`, which is what lets logout pop
/// the whole section off in one go without naming each route.
bool _isAdminRoute(Route<dynamic> route) {
  final name = route.settings.name;
  return name != null && name.startsWith('/admin');
}

class AdminAccessDenied extends StatelessWidget {
  const AdminAccessDenied({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cloud,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: AdminSoftCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 26,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: AppColors.coral.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.lock_outline,
                        size: 30,
                        color: AppColors.coral,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Access Denied: Admin Rights Required',
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Sign in with an admin account to open this screen.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.ink.withValues(alpha: 0.66),
                          ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () =>
                            Navigator.of(context).pushNamedAndRemoveUntil(
                          RouteNames.adminLogin,
                          // Keep the app underneath, or back from the login
                          // screen lands on an empty stack.
                          (route) => route.isFirst,
                        ),
                        icon: const Icon(Icons.login_rounded, size: 20),
                        label: const Text('Go to admin login'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
