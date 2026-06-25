import 'package:flutter/material.dart';

class LockedOverlay extends StatelessWidget {
  const LockedOverlay({
    required this.reason,
    super.key,
  });

  final String reason;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.78),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Tooltip(
            message: reason,
            child: const Icon(Icons.lock, size: 32),
          ),
        ),
      ),
    );
  }
}
