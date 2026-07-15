import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/routing/app_router.dart';
import '../../models/koala_guide_message.dart';
import '../../viewmodels/parental_lock_viewmodel.dart';
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
  String _typedAnswer = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ParentalLockViewModel>().loadChallenge();
    });
  }

  @override
  Widget build(BuildContext context) {
    final lock = context.watch<ParentalLockViewModel>();
    final challenge = lock.challenge;

    return Scaffold(
      appBar: AppBar(title: const Text('Parent Check')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          children: [
            const ContextualKoalaGuide(
              trigger: KoalaGuideTrigger.parentalLock,
              audience: KoalaGuideAudience.parent,
              fallbackMessage:
                  'Solve the quick parent challenge to change profiles.',
            ),
            const SizedBox(height: 20),
            Container(
              width: 74,
              height: 74,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.sky.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.lock_person_outlined,
                color: AppColors.sky,
                size: 34,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Solve the parent check',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              'This keeps profile settings and reports in grown-up hands.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.ink,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 28),
                child: Column(
                  children: [
                    Text(
                      'Verification Equation'.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.6,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      challenge?.prompt ?? 'Preparing challenge...',
                      textAlign: TextAlign.center,
                      style:
                          Theme.of(context).textTheme.headlineMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                              ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            DecoratedBox(
              decoration: BoxDecoration(
                color: lock.errorMessage == null
                    ? AppColors.panel
                    : AppColors.coral.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: lock.errorMessage == null
                      ? AppColors.line
                      : AppColors.coral,
                ),
              ),
              child: SizedBox(
                height: 62,
                child: Center(
                  child: Text(
                    _typedAnswer.isEmpty ? '-' : _typedAnswer,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: lock.errorMessage == null
                              ? AppColors.ink
                              : AppColors.coral,
                          fontWeight: FontWeight.w900,
                          letterSpacing: _typedAnswer.isEmpty ? 0 : 3,
                        ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 24,
              child: lock.errorMessage == null
                  ? const SizedBox.shrink()
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: AppColors.coral,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            lock.errorMessage!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: AppColors.coral),
                          ),
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 10),
            _NumberPad(
              enabled: challenge != null && !lock.isLocked,
              onDigit: _appendDigit,
              onDelete: _deleteDigit,
              onSubmit: () => _submit(context),
            ),
          ],
        ),
      ),
    );
  }

  void _appendDigit(String digit) {
    if (_typedAnswer.length >= 3) return;
    setState(() => _typedAnswer += digit);
  }

  void _deleteDigit() {
    if (_typedAnswer.isEmpty) return;
    setState(() {
      _typedAnswer = _typedAnswer.substring(0, _typedAnswer.length - 1);
    });
  }

  Future<void> _submit(BuildContext context) async {
    if (_typedAnswer.isEmpty) return;
    final passed = await context.read<ParentalLockViewModel>().verify(
          _typedAnswer,
        );
    if (!context.mounted) return;

    if (passed) {
      Navigator.of(context).pushReplacementNamed(
        widget.args.successRoute,
        arguments: widget.args.successArguments,
      );
      return;
    }

    setState(() => _typedAnswer = '');
  }
}

class _NumberPad extends StatelessWidget {
  const _NumberPad({
    required this.enabled,
    required this.onDigit,
    required this.onDelete,
    required this.onSubmit,
  });

  final bool enabled;
  final ValueChanged<String> onDigit;
  final VoidCallback onDelete;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    const keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9'];
    return Column(
      children: [
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.5,
          children: [
            for (final key in keys)
              _KeyButton(
                label: key,
                enabled: enabled,
                onTap: () => onDigit(key),
              ),
            _KeyButton(
              icon: Icons.backspace_outlined,
              enabled: enabled,
              onTap: onDelete,
            ),
            _KeyButton(
              label: '0',
              enabled: enabled,
              onTap: () => onDigit('0'),
            ),
            _KeyButton(
              icon: Icons.arrow_forward_rounded,
              isSubmit: true,
              enabled: enabled,
              onTap: onSubmit,
            ),
          ],
        ),
      ],
    );
  }
}

class _KeyButton extends StatelessWidget {
  const _KeyButton({
    required this.enabled,
    required this.onTap,
    this.label,
    this.icon,
    this.isSubmit = false,
  });

  final String? label;
  final IconData? icon;
  final bool isSubmit;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = isSubmit ? Colors.white : AppColors.ink;
    return FilledButton(
      onPressed: enabled ? onTap : null,
      style: FilledButton.styleFrom(
        backgroundColor: isSubmit ? AppColors.ink : AppColors.panel,
        foregroundColor: foreground,
        disabledBackgroundColor: AppColors.line,
        disabledForegroundColor: AppColors.ink.withValues(alpha: 0.38),
        side: BorderSide(
          color: isSubmit ? AppColors.ink : AppColors.line,
        ),
      ),
      child: icon == null
          ? Text(
              label!,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: foreground,
              ),
            )
          : Icon(icon, color: foreground),
    );
  }
}
