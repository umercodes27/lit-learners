import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_config.dart';
import '../../core/constants/app_colors.dart';
import '../../core/routing/route_names.dart';
import '../../viewmodels/admin_auth_viewmodel.dart';
import '../../viewmodels/admin_stats_viewmodel.dart';
import 'widgets/admin_wooden_shell.dart';

/// UC-18: dedicated admin entry point with its own session.
class AdminLoginPage extends StatefulWidget {
  const AdminLoginPage({super.key});

  @override
  State<AdminLoginPage> createState() => _AdminLoginPageState();
}

class _AdminLoginPageState extends State<AdminLoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final adminAuth = context.watch<AdminAuthViewModel>();

    return AdminAuthShell(
      titleLeading: 'ADMIN',
      titleTrailing: 'LOGIN',
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AdminWoodenField(
              controller: _emailController,
              label: 'Admin email',
              hint: 'admin@example.com',
              prefixIcon: Icons.admin_panel_settings_outlined,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              autocorrect: false,
            ),
            const SizedBox(height: 14),
            AdminWoodenField(
              controller: _passwordController,
              label: 'Password',
              prefixIcon: Icons.lock_outline_rounded,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              autocorrect: false,
              enableSuggestions: false,
              suffixIcon: IconButton(
                tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                onPressed: () {
                  setState(() => _obscurePassword = !_obscurePassword);
                },
                icon: Icon(
                  _obscurePassword ? Icons.visibility : Icons.visibility_off,
                ),
              ),
              onSubmitted: (_) => _submit(context),
            ),
            if (!_isFirebaseLive) ...[
              const SizedBox(height: 14),
              const _LocalDataNotice(),
            ],
            if (adminAuth.errorMessage != null) ...[
              const SizedBox(height: 12),
              AdminAuthBanner(message: adminAuth.errorMessage!),
            ],
            const SizedBox(height: 16),
            AdminAuthButton(
              icon: Icons.login_rounded,
              label: adminAuth.isLoading ? 'Signing in...' : 'Sign in as admin',
              onPressed: adminAuth.isLoading ? null : () => _submit(context),
            ),
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: adminAuth.isLoading
                  ? null
                  : () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: const Text('Back to parent login'),
            ),
          ],
        ),
      ),
    );
  }

  /// Firebase is only really live when it both was asked for and started.
  bool get _isFirebaseLive => AppConfig.useFirebase && Firebase.apps.isNotEmpty;

  Future<void> _submit(BuildContext context) async {
    final adminAuth = context.read<AdminAuthViewModel>();
    final success = await adminAuth.signIn(
      email: _emailController.text,
      password: _passwordController.text,
    );
    if (!context.mounted || !success) return;

    // Metrics are per-session; drop anything a previous admin loaded.
    context.read<AdminStatsViewModel>().reset();
    await Navigator.of(context).pushReplacementNamed(RouteNames.adminDashboard);
  }
}

/// Says plainly that the portal is not talking to Firebase.
///
/// Without this the demo repositories look exactly like a working backend:
/// content saves, statistics render, and nothing reaches the project.
class _LocalDataNotice extends StatelessWidget {
  const _LocalDataNotice();

  @override
  Widget build(BuildContext context) {
    // Shaped like AdminAuthBanner — 8px corners, wood-brown Fredoka text —
    // so it sits with the sign-in banners rather than beside them.
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.lemon.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.honey),
      ),
      child: const Padding(
        padding: EdgeInsets.all(10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.cloud_off_rounded, size: 20, color: _noticeBrown),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Not connected to Firebase. Anything you change here stays on '
                'this device and is lost on reload.',
                style: TextStyle(
                  color: _noticeBrown,
                  fontFamily: 'Fredoka',
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The wood brown the auth banners write in. Kept local because the shell
/// keeps its own copy private.
const _noticeBrown = Color(0xFF6F3D20);
