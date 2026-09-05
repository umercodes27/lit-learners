import 'package:flutter/material.dart';

import 'play/play.dart';

/// The one labelled door from a child screen into the parent dashboard. An
/// icon on its own read as decoration, so the words travel with it everywhere
/// it appears.
class ParentAreaButton extends StatelessWidget {
  const ParentAreaButton({
    required this.onPressed,
    this.compact = false,
    super.key,
  });

  final VoidCallback onPressed;

  /// Trims the button down for a spot inside a header, where it sits beside
  /// other content rather than filling a bar of its own.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return PlayButton(
      label: 'Parent dashboard',
      icon: Icons.family_restroom_rounded,
      color: PlayColors.sunshine,
      onPressed: onPressed,
    );
  }
}
