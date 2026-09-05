import 'package:flutter/material.dart';

import 'play_button.dart';
import 'play_colors.dart';
import 'play_header.dart';

/// A confirmation, shaped like everything else in the app rather than like an
/// [AlertDialog].
class PlayDialog extends StatelessWidget {
  const PlayDialog({
    super.key,
    required this.icon,
    required this.accent,
    required this.title,
    required this.message,
    required this.cancelLabel,
    required this.confirmLabel,
    required this.confirmIcon,
    required this.onCancel,
    required this.onConfirm,
  });

  final IconData icon;
  final Color accent;
  final String title;
  final String message;
  final String cancelLabel;
  final String confirmLabel;
  final IconData confirmIcon;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final panel = PlayPanel(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
            child: Icon(icon, size: 38, color: PlayColors.onGround(accent)),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Fredoka',
              fontSize: 24,
              height: 1.15,
              fontWeight: FontWeight.w600,
              color: PlayColors.ink,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              height: 1.35,
              fontWeight: FontWeight.w600,
              color: PlayColors.ink.withValues(alpha: 0.66),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: PlayButton(
                  label: cancelLabel,
                  color: PlayColors.cream,
                  textColor: PlayColors.ink,
                  onPressed: onCancel,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: PlayButton(
                  label: confirmLabel,
                  icon: confirmIcon,
                  color: accent,
                  onPressed: onConfirm,
                ),
              ),
            ],
          ),
        ],
      ),
    );

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Material(color: Colors.transparent, child: panel),
    );
  }
}
