import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/parent_report.dart';
import '../../services/insights/child_insights.dart';
import '../../services/insights/progress_summary_store.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/parent_report_viewmodel.dart';
import '../../widgets/play/play.dart';
import 'widgets/progress_ring.dart';
import 'widgets/report_cards.dart';

/// How a child is getting on, one child at a time.
///
/// This used to be a single list: every child, then every level each of them
/// had touched, as rows. With three children and a term's work that is a
/// hundred rows to scroll looking for a number — and the thing a parent
/// actually wants, is this going well and what should we do next, was nowhere
/// on the screen.
///
/// Now it shows one child, in rings that are read without counting, with the
/// findings underneath in plain sentences. Every level is still accounted for
/// in those numbers; the levels just are not the interface any more.
class ParentReportsPage extends StatefulWidget {
  const ParentReportsPage({super.key});

  @override
  State<ParentReportsPage> createState() => _ParentReportsPageState();
}

class _ParentReportsPageState extends State<ParentReportsPage> {
  String? _loadedParentId;
  String? _selectedChildId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final parent = context.watch<AuthViewModel>().parent;
    if (parent != null && _loadedParentId != parent.id) {
      _loadedParentId = parent.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<ParentReportViewModel>().loadReport(parent.id);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final parent = context.watch<AuthViewModel>().parent;
    final reports = context.watch<ParentReportViewModel>();

    if (parent == null) {
      return const Scaffold(body: Center(child: Text('Parent not signed in.')));
    }

    final children = reports.report?.childReports ?? const <ChildReport>[];
    final selected = _selectedFrom(children);

    return Scaffold(
      backgroundColor: PlayColors.cream,
      body: PlayGround(
        color: PlayColors.grape,
        child: Column(
          children: [
            PlayHeader(
              title: 'Progress',
              subtitle: children.length > 1 ? 'One child at a time' : null,
              onBack: Navigator.of(context).canPop()
                  ? () => Navigator.of(context).pop()
                  : null,
              trailing: Squishy(
                onTap: reports.isLoading
                    ? null
                    : () => context
                        .read<ParentReportViewModel>()
                        .loadReport(parent.id),
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(Icons.refresh_rounded, color: PlayColors.ink),
                ),
              ),
            ),
            if (children.length > 1)
              _ChildSwitcher(
                childReports: children,
                selectedId: selected?.profile.id,
                onSelect: (id) => setState(() => _selectedChildId = id),
              ),
            Expanded(child: _body(context, reports, selected)),
          ],
        ),
      ),
    );
  }

  ChildReport? _selectedFrom(List<ChildReport> children) {
    if (children.isEmpty) return null;
    for (final child in children) {
      if (child.profile.id == _selectedChildId) return child;
    }
    return children.first;
  }

  Widget _body(
    BuildContext context,
    ParentReportViewModel reports,
    ChildReport? selected,
  ) {
    if (reports.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: PlayColors.grape),
      );
    }
    if (reports.errorMessage != null) {
      return _Message(
        icon: Icons.cloud_off_rounded,
        title: 'Could not load',
        message: reports.errorMessage!,
      );
    }
    if (selected == null) {
      return const _Message(
        icon: Icons.child_care_rounded,
        title: 'No children yet',
        message: 'Add a child profile and their progress will appear here.',
      );
    }

    final insights = reports.insightsFor(selected.profile.id);
    if (insights == null) {
      return const _Message(
        icon: Icons.hourglass_empty_rounded,
        title: 'Working it out',
        message: 'Tap refresh if this stays here.',
      );
    }

    return _ChildProgress(
      insights: insights,
      summary: reports.summaryFor(selected.profile.id),
      isGenerating: reports.isGeneratingFor(selected.profile.id),
      error: reports.summaryErrorFor(selected.profile.id),
      canSummarise: reports.canSummarise,
      onGenerate: () => context
          .read<ParentReportViewModel>()
          .generateSummary(selected.profile.id),
    );
  }
}

/// One child's progress, as a picture rather than a list.
class _ChildProgress extends StatelessWidget {
  const _ChildProgress({
    required this.insights,
    required this.summary,
    required this.isGenerating,
    required this.error,
    required this.canSummarise,
    required this.onGenerate,
  });

  final ChildInsights insights;
  final ProgressSummary? summary;
  final bool isGenerating;
  final String? error;
  final bool canSummarise;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    final name = insights.profile.name;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      children: [
        _Headline(insights: insights),
        const SizedBox(height: 16),
        const PlaySectionLabel('Subjects', color: PlayColors.ink),
        const SizedBox(height: 10),
        PlayPanel(
          child: Wrap(
            alignment: WrapAlignment.spaceEvenly,
            spacing: 6,
            runSpacing: 18,
            children: [
              for (final module in insights.modules)
                SizedBox(
                  width: 96,
                  child: SubjectRing(
                    title: module.moduleTitle,
                    completion: module.completion,
                    color: PlayColors.forModuleId(module.moduleId),
                    caption: module.isStarted
                        ? '${module.starsEarned}/${module.starsPossible} stars'
                        : 'not tried',
                    dimmed: !module.isStarted,
                  ),
                ),
            ],
          ),
        ),
        if (canSummarise) ...[
          const SizedBox(height: 18),
          AiSummaryCard(
            childName: name,
            summary: summary,
            isGenerating: isGenerating,
            error: error,
            onGenerate: onGenerate,
          ),
        ],
        if (insights.findings.isNotEmpty) ...[
          const SizedBox(height: 18),
          const PlaySectionLabel('What we noticed', color: PlayColors.ink),
          const SizedBox(height: 10),
          for (final finding in insights.findings)
            InsightCard(insight: finding),
        ],
      ],
    );
  }
}

/// The one glance that answers "is this going well?".
class _Headline extends StatelessWidget {
  const _Headline({required this.insights});

  final ChildInsights insights;

  @override
  Widget build(BuildContext context) {
    return PlayPanel(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          ProgressRing(
            value: insights.overallCompletion,
            color: PlayColors.grape,
            size: 104,
            thickness: 12,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${(insights.overallCompletion * 100).round()}%',
                  style: const TextStyle(
                    fontFamily: 'Fredoka',
                    fontWeight: FontWeight.w900,
                    fontSize: 24,
                    height: 1,
                    color: PlayColors.ink,
                  ),
                ),
                Text(
                  'done',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: PlayColors.ink.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  insights.profile.name,
                  style: const TextStyle(
                    fontFamily: 'Fredoka',
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                    color: PlayColors.ink,
                  ),
                ),
                const SizedBox(height: 10),
                _Stat(
                  icon: Icons.star_rounded,
                  color: PlayColors.sunshine,
                  label: '${insights.totalStars} of '
                      '${insights.totalStarsPossible} stars',
                ),
                const SizedBox(height: 6),
                _Stat(
                  icon: Icons.check_circle_rounded,
                  color: PlayColors.grass,
                  label: '${insights.completedLevels} of '
                      '${insights.availableLevels} lessons',
                ),
                const SizedBox(height: 6),
                _Stat(
                  icon: Icons.bolt_rounded,
                  color: PlayColors.tangerine,
                  label: insights.levelsCompletedThisWeek == 0
                      ? 'nothing this week yet'
                      : '${insights.levelsCompletedThisWeek} this week',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.color, required this.label});

  final IconData icon;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 17, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: PlayColors.ink.withValues(alpha: 0.8),
            ),
          ),
        ),
      ],
    );
  }
}

class _ChildSwitcher extends StatelessWidget {
  const _ChildSwitcher({
    required this.childReports,
    required this.selectedId,
    required this.onSelect,
  });

  final List<ChildReport> childReports;
  final String? selectedId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        itemCount: childReports.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final child = childReports[index];
          final isSelected = child.profile.id == selectedId;

          return Squishy(
            onTap: () => onSelect(child.profile.id),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 18),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected ? PlayColors.grape : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white, width: 3),
              ),
              child: Text(
                child.profile.name,
                style: TextStyle(
                  fontFamily: 'Fredoka',
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: isSelected ? Colors.white : PlayColors.ink,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 54, color: PlayColors.ink.withValues(alpha: 0.35)),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(
                fontFamily: 'Fredoka',
                fontWeight: FontWeight.w900,
                fontSize: 20,
                color: PlayColors.ink,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: PlayColors.ink.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
