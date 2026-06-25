import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/routing/app_router.dart';
import '../../models/koala_guide_message.dart';
import '../../viewmodels/parental_lock_viewmodel.dart';
import '../../widgets/app_primary_button.dart';
import '../../widgets/koala_guide.dart';

class ParentalLockPage extends StatefulWidget {
  const ParentalLockPage({
    required this.args,
    super.key,
  });

  final ParentalLockArgs args;

  @override
  State<ParentalLockPage> createState() => _ParentalLockPageState();
}

class _ParentalLockPageState extends State<ParentalLockPage> {
  final _answerController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ParentalLockViewModel>().loadChallenge();
    });
  }

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lock = context.watch<ParentalLockViewModel>();
    final challenge = lock.challenge;

    return Scaffold(
      appBar: AppBar(title: const Text('Parent Check')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const ContextualKoalaGuide(
              trigger: KoalaGuideTrigger.parentalLock,
              audience: KoalaGuideAudience.parent,
              fallbackMessage:
                  'Solve the quick parent challenge to change profiles.',
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      challenge?.prompt ?? 'Preparing challenge...',
                      textAlign: TextAlign.center,
                      style:
                          Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _answerController,
                      enabled: !lock.isLocked,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Answer',
                        prefixIcon: Icon(Icons.calculate),
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _submit(context),
                    ),
                    if (lock.errorMessage != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        lock.errorMessage!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    AppPrimaryButton(
                      icon: Icons.lock_open,
                      label: 'Unlock',
                      onPressed: challenge == null || lock.isLocked
                          ? null
                          : () => _submit(context),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit(BuildContext context) async {
    final passed = await context.read<ParentalLockViewModel>().verify(
          _answerController.text,
        );
    if (!context.mounted) return;

    if (passed) {
      Navigator.of(context).pushReplacementNamed(
        widget.args.successRoute,
        arguments: widget.args.successArguments,
      );
      return;
    }

    _answerController.clear();
  }
}
