import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/koala_guide_message.dart';
import '../../models/learning_level.dart';
import '../../models/parent_report.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/parent_report_viewmodel.dart';
import '../../widgets/koala_guide.dart';
import '../../widgets/star_rating.dart';

class ParentReportsPage extends StatefulWidget {
  const ParentReportsPage({super.key});

  @override
  State<ParentReportsPage> createState() => _ParentReportsPageState();
}

class _ParentReportsPageState extends State<ParentReportsPage> {
  String? _loadedParentId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final parent = context.watch<AuthViewModel>().parent;
    if (parent != null && _loadedParentId != parent.id) {
      _loadedParentId = parent.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Parent Reports'),
        actions: [
          IconButton(
            tooltip: 'Refresh reports',
            onPressed: reports.isLoading
                ? null
                : () =>
                    context.read<ParentReportViewModel>().loadReport(parent.id),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: reports.isLoading
            ? const Center(child: CircularProgressIndicator())
            : _ReportBody(report: reports.report, error: reports.errorMessage),
      ),
    );
  }
}

class _ReportBody extends StatelessWidget {
  const _ReportBody({
    required this.report,
    required this.error,
  });

  final ParentReport? report;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final report = this.report;

    if (error != null) {
      return Center(child: Text(error!));
    }

    if (report == null || report.childReports.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          ContextualKoalaGuide(
            trigger: KoalaGuideTrigger.parentReport,
            audience: KoalaGuideAudience.parent,
            fallbackMessage: 'Create a child profile and complete a level to '
                'see reports here.',
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const ContextualKoalaGuide(
          trigger: KoalaGuideTrigger.parentReport,
          audience: KoalaGuideAudience.parent,
          fallbackMessage: 'A quick parent view of profile activity, quiz '
              'scores, rewards, and video watching.',
        ),
        const SizedBox(height: 16),
        _SummaryGrid(report: report),
        const SizedBox(height: 16),
        for (final childReport in report.childReports)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _ChildReportCard(report: childReport),
          ),
      ],
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.report});

  final ParentReport report;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _SummaryTile(
          icon: Icons.child_care,
          label: 'Learners',
          value: report.childCount.toString(),
        ),
        _SummaryTile(
          icon: Icons.check_circle,
          label: 'Completed',
          value: report.completedLevels.toString(),
        ),
        _SummaryTile(
          icon: Icons.star,
          label: 'Stars',
          value: report.totalStars.toString(),
        ),
        _SummaryTile(
          icon: Icons.quiz,
          label: 'Quiz avg',
          value: report.averageQuizScore == null
              ? '-'
              : '${report.averageQuizScore}%',
        ),
        _SummaryTile(
          icon: Icons.play_circle,
          label: 'Videos',
          value: report.watchedVideoLessons.toString(),
        ),
      ],
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 112,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Icon(icon),
              const SizedBox(height: 8),
              Text(
                value,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 2),
              Text(label, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChildReportCard extends StatelessWidget {
  const _ChildReportCard({required this.report});

  final ChildReport report;

  @override
  Widget build(BuildContext context) {
    final profile = report.profile;
    final latestProgress = report.progressReports.take(3).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(child: Text(profile.name.substring(0, 1))),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.name,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      Text(
                        'Age ${profile.age} - '
                        '${profile.isSynced ? 'synced' : 'pending sync'}',
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _InlineMetric(
                  icon: Icons.check,
                  label: '${report.completedLevels} levels',
                ),
                _InlineMetric(
                  icon: Icons.star,
                  label: '${report.starsEarned} stars',
                ),
                _InlineMetric(
                  icon: Icons.emoji_events,
                  label: '${report.rewardsEarned} rewards',
                ),
                _InlineMetric(
                  icon: Icons.play_arrow,
                  label: '${report.watchedVideoLessons} videos',
                ),
                _InlineMetric(
                  icon: Icons.quiz,
                  label: report.averageQuizScore == null
                      ? 'No quiz score'
                      : '${report.averageQuizScore}% quiz avg',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Profile updated ${_formatDate(profile.updatedAt)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (report.lastActivityAt != null)
              Text(
                'Last activity ${_formatDate(report.lastActivityAt!)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            const Divider(height: 24),
            if (latestProgress.isEmpty)
              const Text('No learning activity yet.')
            else
              for (final progressReport in latestProgress)
                _ProgressRow(report: progressReport),
          ],
        ),
      ),
    );
  }
}

class _InlineMetric extends StatelessWidget {
  const _InlineMetric({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 4),
        Text(label),
      ],
    );
  }
}

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({required this.report});

  final LevelProgressReport report;

  @override
  Widget build(BuildContext context) {
    final progress = report.progress;
    final watchedText = report.watchedLessonTitles.isEmpty
        ? null
        : 'Watched ${report.watchedLessonTitles.join(', ')}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_iconFor(report.levelType)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  report.levelTitle,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Text(report.moduleTitle),
                if (progress.score != null)
                  Text('Quiz score ${progress.score}%'),
                if (watchedText != null) Text(watchedText),
                Text(
                  _formatDate(progress.updatedAt),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          StarRating(count: progress.starsEarned),
        ],
      ),
    );
  }

  IconData _iconFor(LevelType type) {
    return switch (type) {
      LevelType.video => Icons.play_circle,
      LevelType.counting => Icons.exposure_plus_1,
      LevelType.matching => Icons.category,
      LevelType.story => Icons.menu_book,
      LevelType.drawing => Icons.brush,
      LevelType.flashcards => Icons.style,
    };
  }
}

String _formatDate(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '${date.year}-$month-$day $hour:$minute';
}
