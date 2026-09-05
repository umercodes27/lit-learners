import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/routing/route_names.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../widgets/play/play.dart';
import 'widgets/auth_page_shell.dart';

/// One step: take the email and ask Firebase to mail a reset link. The rest of
/// the flow happens in the parent's mail client and on Firebase's own page, so
/// there is nothing here to verify and no new password to collect.
class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _emailController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // A message left over from an earlier visit would otherwise greet the
    // parent before they have typed anything.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AuthViewModel>().resetPasswordFlow();
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();
    final sent = auth.infoMessage != null && auth.errorMessage == null;

    return AuthPageShell(
      titleLeading: 'RESET',
      titleTrailing: 'PASSWORD',
      ground: PlayColors.tangerine,
      accent: PlayColors.ink,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PlayNote(
            'Type the email on your account and we will send you a link to '
            'set a new password.',
            color: PlayColors.ink,
            style: TextStyle(
              fontSize: 15,
              color: PlayColors.ink.withValues(alpha: 0.66),
            ),
          ),
          const SizedBox(height: 16),
          PlayField(
            controller: _emailController,
            label: 'Email address',
            hint: 'parent@example.com',
            icon: Icons.mail_rounded,
            color: PlayColors.tangerine,
            labelColor: PlayColors.ink,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.email],
            autocorrect: false,
            onSubmitted: (_) => _submit(context),
          ),
          if (auth.errorMessage != null) ...[
            const SizedBox(height: 14),
            PlayBanner(message: auth.errorMessage!),
          ],
          if (sent) ...[
            const SizedBox(height: 14),
            PlayBanner(message: auth.infoMessage!, isError: false),
          ],
          const SizedBox(height: 18),
          PlayButton(
            icon: sent ? Icons.refresh_rounded : Icons.mark_email_read_rounded,
            label: auth.isLoading
                ? 'Sending...'
                : sent
                    ? 'Send it again'
                    : 'Send reset link',
            color: PlayColors.sunshine,
            big: true,
            onPressed: auth.isLoading ? null : () => _submit(context),
          ),
          if (sent) ...[
            const SizedBox(height: 6),
            Center(
              child: AuthTextLink(
                label: 'Back to sign in',
                color: PlayColors.grape,
                onPressed: () => _openLogin(context),
              ),
            ),
          ],
        ],
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

  Future<void> _submit(BuildContext context) {
    return context.read<AuthViewModel>().sendPasswordReset(
          _emailController.text,
        );
  }
}
