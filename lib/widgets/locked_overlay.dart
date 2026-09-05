import 'package:flutter/material.dart';

import 'play/play.dart';

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
          color: Colors.white.withValues(alpha: 0.66),
          borderRadius: BorderRadius.circular(PlayMotion.radiusLarge),
        ),
        child: Center(
          child: Tooltip(
            message: reason,
            child: Container(
              width: 66,
              height: 66,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: PlayColors.grape,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 4),
              ),
              child: const Icon(Icons.lock, size: 32, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}
