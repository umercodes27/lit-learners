import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../models/admin_stats.dart';
import '../../services/insights/parent_account_insights.dart';
import '../../viewmodels/admin_auth_viewmodel.dart';
import '../../viewmodels/admin_stats_viewmodel.dart';
import 'widgets/account_grid.dart';
import 'widgets/admin_charts.dart';
import 'widgets/admin_form_fields.dart';
import 'widgets/admin_scaffold.dart';

/// Registered parent accounts, read only.
///
/// This began as two counts and then every account as a row. At a hundred
/// families that is four screens of scrolling, and none of it answers what an
/// admin came to find out.
///
/// So the shape comes first, and the accounts are discs rather than rows: a
/// hundred of them fit in a few lines and their colours show the take-up
/// problem before a single address is read. The charts are the filter — tap a
/// bar and the grid below narrows to those families — and tapping a disc
/// opens that account, which is where the scrolling was headed anyway.
class AdminParentAccountsPage extends StatefulWidget {
  const AdminParentAccountsPage({super.key});

  @override
  State<AdminParentAccountsPage> createState() =>
      _AdminParentAccountsPageState();
}

class _AdminParentAccountsPageState extends State<AdminParentAccountsPage> {
  final _search = TextEditingController();
  var _didRequestLoad = false;
  String? _bucketFilter;
  String? _selectedParentId;

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

    final matches = [
      for (final account
          in ParentAccountInsights.search(accounts, _search.text))
        if (_bucketFilter == null ||
            accountBucket(account.childProfileCount) == _bucketFilter)
          account,
    ];

    final selected = matches
        .where((account) => account.parentId == _selectedParentId)
        .firstOrNull;

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
                _Charts(
                  accounts: accounts,
                  selectedBucket: _bucketFilter,
                  onBucketTap: (bucket) => setState(() {
                    _bucketFilter = _bucketFilter == bucket ? null : bucket;
                    _selectedParentId = null;
                  }),
                ),
                const SizedBox(height: 18),
                AdminSectionHeading(
                  title: 'Everyone',
                  subtitle: _subtitle(accounts.length, matches.length),
                ),
                const SizedBox(height: 10),
                AdminTextField(
                  controller: _search,
                  label: 'Search by email',
                ),
                if (_bucketFilter != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: InputChip(
                        label: Text(_bucketFilter == 'None'
                            ? 'No children'
                            : '$_bucketFilter children'),
                        onDeleted: () => setState(() => _bucketFilter = null),
                      ),
                    ),
                  ),
                if (selected != null)
                  AccountDetailCard(
                    account: selected,
                    onClose: () => setState(() => _selectedParentId = null),
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
                    title: 'Nothing matches',
                    message: 'Try a different search, or clear the filter.',
                  )
                else ...[
                  AccountGrid(
                    accounts: matches,
                    selectedId: _selectedParentId,
                    onSelect: (account) => setState(
                      () => _selectedParentId =
                          _selectedParentId == account.parentId
                              ? null
                              : account.parentId,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const _Legend(),
                ],
              ],
            ),
    );
  }

  String _subtitle(int total, int shown) {
    if (shown == total) {
      return '$total ${total == 1 ? 'account' : 'accounts'}. Tap anyone for '
          'their details.';
    }
    return 'Showing $shown of $total.';
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
  const _Charts({
    required this.accounts,
    required this.selectedBucket,
    required this.onBucketTap,
  });

  final List<AdminParentAccountSummary> accounts;
  final String? selectedBucket;
  final ValueChanged<String> onBucketTap;

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
                subtitle: 'Tap a bar to see just those families',
              ),
              const SizedBox(height: 14),
              AdminDistributionChart(
                selectedLabel: selectedBucket,
                onBarTap: (bar) => onBucketTap(bar.label),
                bars: [
                  for (final bucket in families)
                    AdminChartBar(
                      label: bucket.label,
                      value: bucket.count,
                      // The "none" bucket is the one worth noticing, so it is
                      // the one that is not the house colour.
                      accent: accountAccent(_countFor(bucket.label)),
                    ),
                ],
              ),
              if (noChildren > 0) ...[
                const SizedBox(height: 12),
                Text(
                  '$noChildren ${noChildren == 1 ? 'account has' : 'accounts have'} '
                  'no child profile yet, so nobody on '
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

  /// A representative child count for a bucket, so the bar takes the same
  /// colour as the discs it stands for.
  int _countFor(String bucket) => switch (bucket) {
        'None' => 0,
        '1' => 1,
        '2' => 2,
        _ => 3,
      };
}

/// What the colours mean, said once rather than guessed at.
class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    const entries = [
      (0, 'No children'),
      (1, '1 child'),
      (2, '2 children'),
      (3, '3 or more'),
    ];

    return Wrap(
      spacing: 14,
      runSpacing: 8,
      children: [
        for (final (count, label) in entries)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 13,
                height: 13,
                decoration: BoxDecoration(
                  color: accountAccent(count),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 6),
              Text(label, style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
      ],
    );
  }
}
