import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../models/admin_stats.dart';
import '../../services/insights/parent_account_insights.dart';
import '../../viewmodels/admin_auth_viewmodel.dart';
import '../../viewmodels/admin_stats_viewmodel.dart';
import 'widgets/admin_charts.dart';
import 'widgets/admin_form_fields.dart';
import 'widgets/admin_scaffold.dart';

/// Registered parent accounts, read only.
///
/// This used to be two counts and then every account as a row. At a hundred
/// families that is a hundred rows to scroll past, and none of them answer
/// the questions an admin actually has: are people still signing up, and are
/// they getting as far as adding a child?
///
/// So the shape comes first, in two small charts, and the list is searchable
/// and capped rather than dumped.
class AdminParentAccountsPage extends StatefulWidget {
  const AdminParentAccountsPage({super.key});

  @override
  State<AdminParentAccountsPage> createState() =>
      _AdminParentAccountsPageState();
}

class _AdminParentAccountsPageState extends State<AdminParentAccountsPage> {
  final _search = TextEditingController();
  var _didRequestLoad = false;
  var _showAll = false;

  /// Enough to scan, few enough to stay on one screen. Searching reaches
  /// anything past it, and "show all" is one tap away.
  static const _visibleByDefault = 12;

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isAdmin = context.watch<AdminAuthViewModel>().isAuthenticated;
    final stats = context.read<AdminStatsViewModel>();
    if (isAdmin && !_didRequestLoad && !stats.hasLoaded) {
      _didRequestLoad = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<AdminStatsViewModel>().load();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final stats = context.watch<AdminStatsViewModel>();
    final accounts = stats.parentAccounts;
    final matches = ParentAccountInsights.search(accounts, _search.text);
    final visible =
        _showAll ? matches : matches.take(_visibleByDefault).toList();

    return AdminScaffold(
      title: 'Parent Accounts',
      subtitle: 'Monitoring only',
      actions: [
        AdminHeaderAction(
          tooltip: 'Refresh',
          icon: Icons.refresh,
          onPressed: stats.isLoading
              ? null
              : () => context.read<AdminStatsViewModel>().load(),
        ),
      ],
      child: stats.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              children: [
                if (stats.errorMessage != null) ...[
                  AdminInlineError(message: stats.errorMessage!),
                  const SizedBox(height: 12),
                ],
                _Totals(stats: stats.stats, accounts: accounts),
                const SizedBox(height: 18),
                _Charts(accounts: accounts),
                const SizedBox(height: 18),
                AdminSectionHeading(
                  title: 'Registered Parents',
                  subtitle: matches.length == accounts.length
                      ? '${accounts.length} '
                          '${accounts.length == 1 ? 'account' : 'accounts'}. '
                          'View only — nothing can be edited here.'
                      : '${matches.length} of ${accounts.length} match '
                          '"${_search.text.trim()}".',
                ),
                const SizedBox(height: 10),
                AdminTextField(
                  controller: _search,
                  label: 'Search by email',
                ),
                if (accounts.isEmpty)
                  const AdminEmptyState(
                    icon: Icons.family_restroom_rounded,
                    title: 'No parent accounts yet',
                    message: 'Accounts appear here as soon as a parent '
                        'registers in the app.',
                  )
                else if (matches.isEmpty)
                  const AdminEmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'No match',
                    message: 'No account email contains that text.',
                  )
                else ...[
                  for (final account in visible)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _ParentAccountTile(account: account),
                    ),
                  if (matches.length > visible.length)
                    Center(
                      child: TextButton.icon(
                        onPressed: () => setState(() => _showAll = true),
                        icon: const Icon(Icons.expand_more_rounded),
                        label: Text(
                          'Show all ${matches.length}',
                        ),
                      ),
                    ),
                ],
              ],
            ),
    );
  }
}

class _Totals extends StatelessWidget {
  const _Totals({required this.stats, required this.accounts});

  final AdminStats stats;
  final List<AdminParentAccountSummary> accounts;

  @override
  Widget build(BuildContext context) {
    final average = ParentAccountInsights.averageChildrenPerParent(accounts);

    return Row(
      children: [
        Expanded(
          child: AdminMetricTile(
            icon: Icons.people_alt_rounded,
            label: 'Parent accounts',
            value: '${stats.totalParentAccounts}',
            accent: AppColors.plum,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: AdminMetricTile(
            icon: Icons.child_care_rounded,
            label: 'Child profiles',
            value: '${stats.totalChildProfiles}',
            accent: AppColors.aqua,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: AdminMetricTile(
            icon: Icons.groups_rounded,
            label: 'Children each',
            value: average.toStringAsFixed(1),
            accent: AppColors.violet,
          ),
        ),
      ],
    );
  }
}

class _Charts extends StatelessWidget {
  const _Charts({required this.accounts});

  final List<AdminParentAccountSummary> accounts;

  @override
  Widget build(BuildContext context) {
    if (accounts.isEmpty) return const SizedBox.shrink();

    final families = ParentAccountInsights.childrenPerParent(accounts);
    final joins = ParentAccountInsights.joinsByMonth(
      accounts,
      now: DateTime.now(),
    );
    final noChildren = families.first.count;

    return Column(
      children: [
        AdminSoftCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AdminSectionHeading(
                title: 'Children per family',
                subtitle: 'How far accounts get after registering',
              ),
              const SizedBox(height: 14),
              AdminDistributionChart(
                bars: [
                  for (final bucket in families)
                    AdminChartBar(
                      label: bucket.label,
                      value: bucket.count,
                      // The "none" bucket is the one worth noticing, so it is
                      // the one that is not the house colour.
                      accent: bucket.label == 'None'
                          ? AppColors.coral
                          : AppColors.plum,
                    ),
                ],
              ),
              if (noChildren > 0) ...[
                const SizedBox(height: 12),
                Text(
                  '$noChildren ${noChildren == 1 ? 'account has' : 'accounts have'} '
                  'no child profile yet, so nobody in '
                  '${noChildren == 1 ? 'it' : 'them'} has started learning.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        AdminSoftCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AdminSectionHeading(
                title: 'New sign-ups',
                subtitle: 'Last six months',
              ),
              const SizedBox(height: 14),
              AdminDistributionChart(
                bars: [
                  for (final month in joins)
                    AdminChartBar(
                      label: month.label,
                      value: month.count,
                      accent: AppColors.aqua,
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ParentAccountTile extends StatelessWidget {
  const _ParentAccountTile({required this.account});

  final AdminParentAccountSummary account;

  @override
  Widget build(BuildContext context) {
    final createdAt = account.createdAt;
    final hasChildren = account.childProfileCount > 0;

    return AdminSoftCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          AdminIconChip(
            icon: Icons.person_rounded,
            color: hasChildren ? AppColors.plum : AppColors.coral,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  account.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    AdminPill(
                      icon: Icons.child_care_rounded,
                      label: hasChildren
                          ? '${account.childProfileCount} '
                              '${account.childProfileCount == 1 ? 'child' : 'children'}'
                          : 'no children yet',
                      accent: hasChildren ? AppColors.aqua : AppColors.coral,
                    ),
                    if (createdAt != null)
                      AdminPill(
                        icon: Icons.calendar_today_rounded,
                        label: 'Joined ${createdAt.year}-'
                            '${_two(createdAt.month)}-${_two(createdAt.day)}',
                        accent: AppColors.violet,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _two(int value) => value.toString().padLeft(2, '0');
}
