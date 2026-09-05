import 'package:flutter/material.dart';

import 'play/play.dart';

/// The strip along the bottom of every child screen that holds the grown-up
/// actions. Same place, same look on each screen, so "leave this child's
/// dashboard" is always found in one spot rather than hunted for in a header.
class ChildActionBar extends StatelessWidget {
  const ChildActionBar({required this.actions, super.key});

  /// Laid out as equal halves, so two actions never crowd each other on a
  /// small phone.
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: PlayColors.card,
        border: Border(top: BorderSide(color: Colors.white, width: 4)),
        boxShadow: [
          BoxShadow(color: Color(0x1A2B2145), offset: Offset(0, -4)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              for (final action in actions) ...[
                if (action != actions.first) const SizedBox(width: 10),
                Expanded(child: action),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
