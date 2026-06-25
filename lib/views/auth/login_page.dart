import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/routing/auth_flow_router.dart';
import '../../core/routing/route_names.dart';
import '../../models/koala_guide_message.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../widgets/app_primary_button.dart';
import '../../widgets/koala_guide.dart';

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

    return Scaffold(
      appBar: AppBar(title: const Text('Parent Login')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const ContextualKoalaGuide(
              trigger: KoalaGuideTrigger.authWelcome,
              audience: KoalaGuideAudience.parent,
              fallbackMessage:
                  'Welcome back. Parent access comes before child profiles.',
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.mail),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock),
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                  onPressed: () {
                    setState(() => _obscurePassword = !_obscurePassword);
                  },
                  icon: Icon(
                    _obscurePassword ? Icons.visibility : Icons.visibility_off,
                  ),
                ),
              ),
              onSubmitted: (_) => _submit(context),
            ),
            if (auth.errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                auth.errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 18),
            AppPrimaryButton(
              icon: Icons.login,
              label: auth.isLoading ? 'Signing in...' : 'Sign in',
              onPressed: auth.isLoading ? null : () => _submit(context),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: auth.isLoading
                  ? null
                  : () => Navigator.of(context).pushNamed(RouteNames.signup),
              icon: const Icon(Icons.person_add),
              label: const Text('Create account'),
            ),
            TextButton(
              onPressed: auth.isLoading
                  ? null
                  : () {
                      Navigator.of(context).pushNamed(
                        RouteNames.forgotPassword,
                      );
                    },
              child: const Text('Forgot password?'),
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
}
