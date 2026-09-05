import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/routing/app_router.dart';
import '../../viewmodels/parental_lock_viewmodel.dart';
import '../../services/audio/sound_controller.dart';
import '../../widgets/play/play.dart';

/// The sum a grown-up has to solve before the parent area opens.
///
/// Rebuilt on the play kit so the door between the child screens and the
/// parent area does not look like a different app on either side of it. The
/// challenge, the attempt limit and the routing are untouched.
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
    AppSound.instance.stopMusic();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ParentalLockViewModel>().loadChallenge();
    });
  }

  @override
  Widget build(BuildContext context) {
    final lock = context.watch<ParentalLockViewModel>();
    final challenge = lock.challenge;
    final hasError = lock.errorMessage != null;

    return Scaffold(
      body: PlayGround(
        color: PlayColors.tangerine,
        safeArea: false,
        child: SafeArea(
          child: Column(
            children: [
              PlayHeader(
                title: 'Parent Check',
                onBack: Navigator.of(context).canPop()
                    ? () => Navigator.of(context).maybePop()
                    : null,
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                  children: [
                    const _ParentCheckHeader(),
                    const SizedBox(height: 18),
                    _EquationCard(
                      prompt: challenge?.prompt ?? 'Preparing challenge...',
                    ),
                    const SizedBox(height: 16),
                    _AnswerBox(answer: _typedAnswer, hasError: hasError),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 26,
                      child: hasError
                          ? PlayNote(
                              lock.errorMessage!,
                              style: const TextStyle(fontSize: 15),
                            )
                          : const SizedBox.shrink(),
                    ),
                    const SizedBox(height: 12),
                    _NumberPad(
                      enabled: challenge != null && !lock.isLocked,
                      onDigit: _appendDigit,
                      onDelete: _deleteDigit,
                      onSubmit: () => _submit(context),
                    ),
                  ],
                ),
              ),
            ],
          ),
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
      final successRoute = widget.args.successRoute;
      if (successRoute == null) {
        Navigator.of(context).pop(true);
        return;
      }
      Navigator.of(context).pushReplacementNamed(
        successRoute,
        arguments: widget.args.successArguments,
      );
      return;
    }

    setState(() => _typedAnswer = '');
  }
}

class _ParentCheckHeader extends StatelessWidget {
  const _ParentCheckHeader();

  @override
  Widget build(BuildContext context) {
    return PlayPanel(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: const BoxDecoration(
              color: PlayColors.grape,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.lock_person_rounded,
              color: Colors.white,
              size: 36,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Solve the parent check',
                  style: TextStyle(
                    fontFamily: 'Fredoka',
                    fontSize: 22,
                    height: 1.15,
                    fontWeight: FontWeight.w600,
                    color: PlayColors.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'This keeps profile settings and reports in grown-up hands.',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.3,
                    fontWeight: FontWeight.w600,
                    color: PlayColors.ink.withValues(alpha: 0.62),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The sum itself, as big as it will go.
class _EquationCard extends StatelessWidget {
  const _EquationCard({required this.prompt});

  final String prompt;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 28),
      decoration: BoxDecoration(
        color: PlayColors.grape,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white, width: 4),
        boxShadow: [
          BoxShadow(
            color: PlayColors.ink.withValues(alpha: 0.24),
            offset: const Offset(0, 6),
            blurRadius: 0,
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'VERIFICATION EQUATION',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.6,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 12),
          FittedBox(
            child: Text(
              prompt,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Fredoka',
                fontSize: 40,
                height: 1.1,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// What has been typed so far.
class _AnswerBox extends StatelessWidget {
  const _AnswerBox({required this.answer, required this.hasError});

  final String answer;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    final accent = hasError ? PlayColors.strawberry : Colors.white;

    return AnimatedContainer(
      duration: PlayMotion.pressDown,
      height: 84,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: PlayColors.card,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: accent, width: 4),
        boxShadow: [
          BoxShadow(
            color: PlayColors.ink.withValues(alpha: 0.20),
            offset: const Offset(0, 6),
            blurRadius: 0,
          ),
        ],
      ),
      child: Text(
        answer.isEmpty ? '?' : answer,
        style: TextStyle(
          fontFamily: 'Fredoka',
          fontSize: 40,
          height: 1,
          fontWeight: FontWeight.w700,
          letterSpacing: answer.isEmpty ? 0 : 4,
          color: hasError
              ? PlayColors.strawberry
              : answer.isEmpty
                  ? PlayColors.ink.withValues(alpha: 0.28)
                  : PlayColors.ink,
        ),
      ),
    );
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

    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.4,
      children: [
        for (final key in keys)
          _KeyButton(label: key, enabled: enabled, onTap: () => onDigit(key)),
        _KeyButton(
          icon: Icons.backspace_rounded,
          enabled: enabled,
          onTap: onDelete,
        ),
        _KeyButton(label: '0', enabled: enabled, onTap: () => onDigit('0')),
        _KeyButton(
          icon: Icons.arrow_forward_rounded,
          isSubmit: true,
          enabled: enabled,
          onTap: onSubmit,
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
    final surface = isSubmit ? PlayColors.grass : PlayColors.card;
    final foreground = PlayColors.onGround(surface);

    return Squishy(
      semanticLabel: label ?? (isSubmit ? 'Check answer' : 'Delete'),
      onTap: enabled ? onTap : null,
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: PlayColors.ink.withValues(alpha: 0.18),
                offset: const Offset(0, 5),
                blurRadius: 0,
              ),
            ],
          ),
          child: icon == null
              ? Text(
                  label!,
                  style: TextStyle(
                    fontFamily: 'Fredoka',
                    fontSize: 30,
                    height: 1,
                    fontWeight: FontWeight.w700,
                    color: foreground,
                  ),
                )
              : Icon(icon, color: foreground, size: 30),
        ),
      ),
    );
  }
}
