import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import 'admin_theme.dart';

/// One column of a distribution.
class AdminChartBar {
  const AdminChartBar({
    required this.label,
    required this.value,
    required this.accent,
    this.caption,
  });

  final String label;
  final int value;
  final Color accent;

  /// Second line under the label, for a unit or a share.
  final String? caption;
}

/// Vertical bars for a distribution — how many parents have one child, two,
/// three, and so on.
///
/// The point of a chart here is that the shape is read before any number is:
/// an admin looking at a hundred accounts wants to know whether they are
/// mostly one-child families before they want any individual row.
class AdminDistributionChart extends StatelessWidget {
  const AdminDistributionChart({
    super.key,
    required this.bars,
    this.height = 132,
    this.onBarTap,
    this.selectedLabel,
  });

  final List<AdminChartBar> bars;
  final double height;

  /// When set, the bars become the filter for whatever is below them. A chart
  /// an admin can point at beats a chart they have to translate into a search.
  final ValueChanged<AdminChartBar>? onBarTap;

  /// Label of the bar currently filtering, so it can be shown as picked.
  final String? selectedLabel;

  @override
  Widget build(BuildContext context) {
    if (bars.isEmpty) return const SizedBox.shrink();

    // Scaled to the tallest bar rather than to a round number: with a hundred
    // accounts in one bucket and three in another, a fixed scale would make
    // every small bucket invisible.
    final peak = bars.map((bar) => bar.value).reduce(math.max);
    final theme = Theme.of(context);

    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final bar in bars)
            Expanded(
              child: _tappable(
                bar,
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      '${bar.value}',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // A zero bucket still gets a sliver, so the axis reads as
                    // a row of buckets rather than a gap.
                    Expanded(
                      child: FractionallySizedBox(
                        alignment: Alignment.bottomCenter,
                        heightFactor: peak == 0
                            ? 0.02
                            : math.max(bar.value / peak, 0.02),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          decoration: BoxDecoration(
                            color: bar.value == 0
                                ? bar.accent.withValues(alpha: 0.25)
                                : bar.accent,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(8),
                            ),
                            border: bar.label == selectedLabel
                                ? Border.all(color: AppColors.ink, width: 2.5)
                                : null,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      bar.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (bar.caption != null)
                      Text(
                        bar.caption!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall,
                      ),
                  ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _tappable(AdminChartBar bar, Widget child) {
    final onTap = onBarTap;
    if (onTap == null) return child;

    return InkWell(
      onTap: () => onTap(bar),
      borderRadius: BorderRadius.circular(10),
      child: child,
    );
  }
}

/// A labelled horizontal bar. For ranked comparisons, where the labels are
/// words rather than short buckets.
class AdminRankedBar extends StatelessWidget {
  const AdminRankedBar({
    super.key,
    required this.label,
    required this.value,
    required this.fraction,
    required this.accent,
    this.caption,
  });

  final String label;
  final String value;

  /// 0..1, relative to the largest row in the group.
  final double fraction;
  final Color accent;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                value,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          AdminProgressBar(
            value: fraction.clamp(0.0, 1.0),
            color: accent,
            minHeight: 8,
          ),
          if (caption != null) ...[
            const SizedBox(height: 3),
            Text(caption!, style: theme.textTheme.labelSmall),
          ],
        ],
      ),
    );
  }
}
