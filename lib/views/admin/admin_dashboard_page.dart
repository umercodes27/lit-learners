import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/routing/route_names.dart';
import '../../models/admin_content.dart';
import '../../viewmodels/admin_content_viewmodel.dart';
import '../../viewmodels/auth_viewmodel.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  var _didRequestLoad = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final parent = context.watch<AuthViewModel>().parent;
    if (parent?.canManageAdminContent == true && !_didRequestLoad) {
      _didRequestLoad = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<AdminContentViewModel>().loadContent();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();
    final admin = context.watch<AdminContentViewModel>();

    if (auth.isLoading) {
      return const Scaffold(
        body: SafeArea(child: Center(child: CircularProgressIndicator())),
      );
    }

    if (auth.parent?.canManageAdminContent != true) {
      return const _AdminAccessDenied();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            tooltip: 'Refresh dashboard',
            onPressed: admin.isLoading
                ? null
                : () => context.read<AdminContentViewModel>().loadContent(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.line),
                    color: AppColors.panel,
                  ),
                  child: const Icon(
                    Icons.admin_panel_settings,
                    color: AppColors.sky,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Admin Portal',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      Text(
                        'Hi, ${auth.parent?.email ?? 'Admin'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            if (admin.isLoading)
              const Center(child: CircularProgressIndicator())
            else ...[
              _AdminSummary(admin: admin),
              const SizedBox(height: 18),
              Text(
                'Manage App',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _AdminMenuCard(
                      title: 'Manage\nContent',
                      subtitle: 'Modules, levels, quizzes',
                      icon: Icons.book_outlined,
                      iconColor: AppColors.sky,
                      backgroundColor: const Color(0xFFE6F1FB),
                      onTap: () => Navigator.of(context).pushNamed(
                        RouteNames.adminContent,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _AdminMenuCard(
                      title: 'Publishing\nQueue',
                      subtitle: '${_inReviewCount(admin)} awaiting review',
                      icon: Icons.rate_review_outlined,
                      iconColor: AppColors.plum,
                      backgroundColor: const Color(0xFFEEEDFE),
                      onTap: () => Navigator.of(context).pushNamed(
                        RouteNames.adminContent,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _AdminMenuCard(
                title: 'Progress\nReports',
                subtitle: 'Parent dashboard metrics',
                icon: Icons.insights_outlined,
                iconColor: AppColors.leaf,
                backgroundColor: const Color(0xFFE1F5EE),
                isWide: true,
                onTap: () => Navigator.of(context).pushNamed(
                  RouteNames.parentReports,
                ),
              ),
              const SizedBox(height: 12),
              _SystemInfoTile(
                label: 'System status',
                value: admin.errorMessage ?? admin.infoMessage ?? 'Ready',
                isError: admin.errorMessage != null,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AdminSummary extends StatelessWidget {
  const _AdminSummary({required this.admin});

  final AdminContentViewModel admin;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Content Snapshot',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _SummaryMetric(
                  icon: Icons.widgets_outlined,
                  label: 'Modules',
                  value: admin.modules.length.toString(),
                ),
                const SizedBox(width: 8),
                _SummaryMetric(
                  icon: Icons.map_outlined,
                  label: 'Levels',
                  value: admin.levels.length.toString(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _SummaryMetric(
                  icon: Icons.public,
                  label: 'Published',
                  value: _publishedCount(admin).toString(),
                ),
                const SizedBox(width: 8),
                _SummaryMetric(
                  icon: Icons.drafts_outlined,
                  label: 'Drafts',
                  value: _draftCount(admin).toString(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.cloud,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.line),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(icon,
                  size: 20, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    Text(label),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminMenuCard extends StatelessWidget {
  const _AdminMenuCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.backgroundColor,
    required this.onTap,
    this.isWide = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final Color backgroundColor;
  final VoidCallback onTap;
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: EdgeInsets.all(isWide ? 16 : 14),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor),
              ),
              SizedBox(width: isWide ? 14 : 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                            height: 1.05,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (isWide) const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _SystemInfoTile extends StatelessWidget {
  const _SystemInfoTile({
    required this.label,
    required this.value,
    required this.isError,
  });

  final String label;
  final String value;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: isError ? AppColors.coral : AppColors.leaf,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  Text(value),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminAccessDenied extends StatelessWidget {
  const _AdminAccessDenied();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'This parent account is not approved to access the admin portal.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}

int _publishedCount(AdminContentViewModel admin) {
  return admin.modules.where((item) => item.isPublished).length +
      admin.levels.where((item) => item.isPublished).length;
}

int _draftCount(AdminContentViewModel admin) {
  return admin.modules
          .where((item) => item.publishStatus == AdminPublishStatus.draft)
          .length +
      admin.levels
          .where((item) => item.publishStatus == AdminPublishStatus.draft)
          .length;
}

int _inReviewCount(AdminContentViewModel admin) {
  return admin.modules
          .where((item) => item.publishStatus == AdminPublishStatus.inReview)
          .length +
      admin.levels
          .where((item) => item.publishStatus == AdminPublishStatus.inReview)
          .length;
}
