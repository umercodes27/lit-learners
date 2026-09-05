import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/routing/auth_flow_router.dart';
import '../../core/routing/route_names.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../widgets/play/play.dart';
import 'widgets/auth_page_shell.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
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
    final auth = context.watch<AuthViewModel>();

    return AuthPageShell(
      titleLeading: 'PARENT',
      titleTrailing: 'LOGIN',
      ground: PlayColors.blueberry,
      accent: PlayColors.sunshine,
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PlayField(
              controller: _emailController,
              label: 'Email address',
              hint: 'parent@example.com',
              icon: Icons.mail_rounded,
              color: PlayColors.blueberry,
              labelColor: PlayColors.ink,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              autocorrect: false,
            ),
            const SizedBox(height: 14),
            PlayField(
              controller: _passwordController,
              label: 'Password',
              icon: Icons.lock_rounded,
              color: PlayColors.grape,
              labelColor: PlayColors.ink,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              autocorrect: false,
              enableSuggestions: false,
              onSubmitted: (_) => _submit(context),
              trailing: AuthPeekButton(
                hidden: _obscurePassword,
                onPressed: () {
                  setState(() => _obscurePassword = !_obscurePassword);
                },
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: AuthTextLink(
                label: 'Forgot password?',
                color: PlayColors.grape,
                onPressed: auth.isLoading
                    ? null
                    : () => Navigator.of(context).pushNamed(
                          RouteNames.forgotPassword,
                        ),
              ),
            ),
            if (auth.errorMessage != null) ...[
              const SizedBox(height: 4),
              PlayBanner(message: auth.errorMessage!),
            ],
            const SizedBox(height: 14),
            PlayButton(
              icon: Icons.arrow_forward_rounded,
              label: auth.isLoading ? 'Signing in...' : 'Sign in',
              color: PlayColors.sunshine,
              big: true,
              onPressed: auth.isLoading ? null : () => _submit(context),
            ),
            const SizedBox(height: 16),
            const AuthOrDivider(),
            const SizedBox(height: 16),
            AuthGoogleButton(
              onPressed: auth.isLoading ? null : () => _submitGoogle(context),
            ),
            const SizedBox(height: 6),
            AuthFooterPrompt(
              question: 'New here?',
              action: 'Create account',
              color: PlayColors.blueberry,
              onPressed: auth.isLoading
                  ? null
                  : () => Navigator.of(context).pushNamed(RouteNames.signup),
            ),
            const SizedBox(height: 6),
            Container(
              height: 3,
              decoration: BoxDecoration(
                color: PlayColors.ink.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 6),
            Center(
              child: AuthTextLink(
                label: 'Admin login',
                icon: Icons.admin_panel_settings_outlined,
                color: PlayColors.ink,
                onPressed: auth.isLoading
                    ? null
                    : () =>
                        Navigator.of(context).pushNamed(RouteNames.adminLogin),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit(BuildContext context) async {
    final auth = context.read<AuthViewModel>();
    final success = await auth.signIn(
      email: _emailController.text,
      password: _passwordController.text,
    );
    if (!context.mounted || !success || auth.parent == null) return;

    await AuthFlowRouter.routeAfterAuth(
      context: context,
      parent: auth.parent!,
    );
  }

  Future<void> _submitGoogle(BuildContext context) async {
    final auth = context.read<AuthViewModel>();
    final success = await auth.signInWithGoogle();
    if (!context.mounted || !success || auth.parent == null) return;

    await AuthFlowRouter.routeAfterAuth(
      context: context,
      parent: auth.parent!,
    );
  }
}
