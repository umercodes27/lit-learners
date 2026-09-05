import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/routing/auth_flow_router.dart';
import '../../core/routing/route_names.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../widgets/play/play.dart';
import 'widgets/auth_page_shell.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
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
      titleLeading: 'CREATE',
      titleTrailing: 'ACCOUNT',
      ground: PlayColors.mint,
      accent: PlayColors.grape,
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PlayField(
              controller: _emailController,
              label: 'Email address',
              hint: 'parent@example.com',
              icon: Icons.mail_rounded,
              color: PlayColors.mint,
              labelColor: PlayColors.ink,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.newUsername],
              autocorrect: false,
            ),
            const SizedBox(height: 14),
            PlayField(
              controller: _passwordController,
              label: 'Create password',
              icon: Icons.lock_rounded,
              color: PlayColors.grape,
              labelColor: PlayColors.ink,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.newPassword],
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
            const SizedBox(height: 10),
            PlayNote(
              '8+ characters with uppercase, number and symbol',
              color: PlayColors.ink,
              style: TextStyle(
                fontSize: 14,
                color: PlayColors.ink.withValues(alpha: 0.6),
              ),
            ),
            if (auth.errorMessage != null) ...[
              const SizedBox(height: 12),
              PlayBanner(message: auth.errorMessage!),
            ],
            const SizedBox(height: 16),
            PlayButton(
              icon: Icons.arrow_forward_rounded,
              label: auth.isLoading ? 'Creating...' : 'Create account',
              color: PlayColors.sunshine,
              big: true,
              onPressed: auth.isLoading ? null : () => _submit(context),
            ),
            const SizedBox(height: 16),
            const AuthOrDivider(),
            const SizedBox(height: 16),
            AuthGoogleButton(
              label: 'Sign up with Google',
              onPressed: auth.isLoading ? null : () => _submitGoogle(context),
            ),
            const SizedBox(height: 6),
            AuthFooterPrompt(
              question: 'Already registered?',
              action: 'Sign in',
              color: PlayColors.grape,
              onPressed: auth.isLoading ? null : () => _openLogin(context),
            ),
          ],
        ),
      ),
    );
  }

  void _openLogin(BuildContext context) {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }
    navigator.pushReplacementNamed(RouteNames.login);
  }

  Future<void> _submit(BuildContext context) async {
    final auth = context.read<AuthViewModel>();
    final success = await auth.signUp(
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
    // Google has no separate sign-up: the same call creates the account the
    // first time and signs in on every later visit.
    final auth = context.read<AuthViewModel>();
    final success = await auth.signInWithGoogle();
    if (!context.mounted || !success || auth.parent == null) return;

    await AuthFlowRouter.routeAfterAuth(
      context: context,
      parent: auth.parent!,
    );
  }
}
