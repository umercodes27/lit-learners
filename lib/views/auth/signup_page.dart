import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/routing/auth_flow_router.dart';
import '../../core/routing/route_names.dart';
import '../../viewmodels/auth_viewmodel.dart';
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
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuthWoodenTextField(
              controller: _emailController,
              label: 'Email address',
              hint: 'parent@example.com',
              prefixIcon: Icons.mail_outline_rounded,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.newUsername],
              autocorrect: false,
            ),
            const SizedBox(height: 14),
            AuthWoodenTextField(
              controller: _passwordController,
              label: 'Create password',
              prefixIcon: Icons.lock_outline_rounded,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.newPassword],
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
            const SizedBox(height: 8),
            const Text(
              '8+ characters with uppercase, number and symbol',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF6F3D20),
                fontFamily: 'Fredoka',
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (auth.errorMessage != null) ...[
              const SizedBox(height: 12),
              AuthMessageBanner(
                message: auth.errorMessage!,
              ),
            ],
            const SizedBox(height: 16),
            AuthActionButton(
              icon: Icons.person_add_alt_1_rounded,
              label: auth.isLoading ? 'Creating...' : 'Create account',
              onPressed: auth.isLoading ? null : () => _submit(context),
            ),
            const SizedBox(height: 10),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text(
                  'Already registered?',
                  style: TextStyle(
                    color: Color(0xFF6F3D20),
                    fontFamily: 'Fredoka',
                    fontWeight: FontWeight.w700,
                  ),
                ),
                TextButton(
                  onPressed: auth.isLoading ? null : () => _openLogin(context),
                  child: const Text('Sign in'),
                ),
              ],
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
}
