import 'package:flutter/material.dart';

import '../../../services/insights/child_insights.dart';
import '../../../services/insights/progress_summary_store.dart';
import '../../../widgets/play/play.dart';

/// One thing the app noticed, said in a sentence a parent can act on.
class InsightCard extends StatelessWidget {
  const InsightCard({super.key, required this.insight});

  final Insight insight;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = _look(insight.kind);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: PlayPanel(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    insight.headline,
                    style: const TextStyle(
                      fontFamily: 'Fredoka',
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      color: PlayColors.ink,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    insight.detail,
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.35,
                      color: PlayColors.ink.withValues(alpha: 0.75),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Colour carries the meaning before the words are read, so a parent
  /// glancing at the screen can tell praise from a nudge.
  (IconData, Color) _look(InsightKind kind) => switch (kind) {
        InsightKind.strength =>
          (Icons.emoji_events_rounded, PlayColors.grass),
        InsightKind.momentum => (Icons.bolt_rounded, PlayColors.sunshine),
        InsightKind.needsPractice =>
          (Icons.refresh_rounded, PlayColors.tangerine),
        InsightKind.stalled => (Icons.pause_circle_rounded, PlayColors.grape),
        InsightKind.notStarted => (Icons.explore_rounded, PlayColors.sky),
        InsightKind.idle => (Icons.bedtime_rounded, PlayColors.blueberry),
      };
}

/// The written summary, or the button that asks for one.
///
/// Never generated automatically. It costs a model call, so it happens
/// because a parent asked for it, and the report is complete without it.
class AiSummaryCard extends StatelessWidget {
  const AiSummaryCard({
    super.key,
    required this.childName,
    required this.summary,
    required this.isGenerating,
    required this.error,
    required this.onGenerate,
  });

  final String childName;
  final ProgressSummary? summary;
  final bool isGenerating;
  final String? error;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    final written = summary;

    return PlayPanel(
      color: PlayColors.cream,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: PlayColors.grape.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(Icons.auto_awesome_rounded,
                    color: PlayColors.grape, size: 21),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'In a nutshell',
                  style: TextStyle(
                    fontFamily: 'Fredoka',
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    color: PlayColors.ink,
                  ),
                ),
              ),
              if (written != null && !isGenerating)
                Squishy(
                  onTap: onGenerate,
                  child: const Padding(
                    padding: EdgeInsets.all(6),
                    child: Icon(Icons.refresh_rounded,
                        size: 20, color: PlayColors.grape),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (isGenerating)
            Row(
              children: [
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: PlayColors.grape),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Reading how $childName is getting on…',
                    style: TextStyle(
                      fontSize: 13.5,
                      color: PlayColors.ink.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ],
            )
          else if (written != null) ...[
            Text(
              written.summary,
              style: const TextStyle(
                fontSize: 15,
                height: 1.45,
                color: PlayColors.ink,
              ),
            ),
            if (written.suggestions.isNotEmpty) ...[
              const SizedBox(height: 14),
              for (final suggestion in written.suggestions)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Icon(Icons.arrow_forward_rounded,
                            size: 16, color: PlayColors.grass),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          suggestion,
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1.35,
                            color: PlayColors.ink,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ] else ...[
            Text(
              'Get a short note about how $childName is getting on, and two '
              'or three things to try this week.',
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: PlayColors.ink.withValues(alpha: 0.75),
              ),
            ),
            const SizedBox(height: 14),
            PlayButton(
              label: 'Write me a summary',
              icon: Icons.auto_awesome_rounded,
              color: PlayColors.grape,
              onPressed: onGenerate,
            ),
          ],
          if (error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: PlayColors.strawberry.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                error!,
                style: const TextStyle(fontSize: 13, color: PlayColors.ink),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
