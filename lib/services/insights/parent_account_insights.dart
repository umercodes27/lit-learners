import '../../models/admin_stats.dart';

/// A labelled count, ready to become a bar.
typedef AccountBucket = ({String label, int count});

/// Shapes a list of parent accounts into the few things an admin can act on.
///
/// A hundred account rows answer no question anybody has. The shape of the
/// list does: whether these are mostly one-child families, and whether people
/// are still signing up.
class ParentAccountInsights {
  const ParentAccountInsights._();

  /// How many parents have no children registered, one, two, or three and up.
  ///
  /// Zero matters most and is the reason this is not just an average: a
  /// parent who registered and never added a child did not get started, and
  /// a mean of 1.4 hides every one of them.
  static List<AccountBucket> childrenPerParent(
    List<AdminParentAccountSummary> accounts,
  ) {
    var none = 0;
    var one = 0;
    var two = 0;
    var more = 0;

    for (final account in accounts) {
      switch (account.childProfileCount) {
        case 0:
          none++;
        case 1:
          one++;
        case 2:
          two++;
        default:
          more++;
      }
    }

    return [
      (label: 'None', count: none),
      (label: '1', count: one),
      (label: '2', count: two),
      (label: '3+', count: more),
    ];
  }

  /// Sign-ups per calendar month, oldest first, ending with the current one.
  ///
  /// Accounts with no recorded date are left out rather than bundled into
  /// the earliest month, which would invent a spike that never happened.
  static List<AccountBucket> joinsByMonth(
    List<AdminParentAccountSummary> accounts, {
    required DateTime now,
    int months = 6,
  }) {
    const names = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];

    final buckets = <AccountBucket>[];
    for (var back = months - 1; back >= 0; back--) {
      final month = DateTime(now.year, now.month - back);
      final count = accounts.where((account) {
        final joined = account.createdAt;
        return joined != null &&
            joined.year == month.year &&
            joined.month == month.month;
      }).length;

      buckets.add((label: names[month.month - 1], count: count));
    }
    return buckets;
  }

  /// Averaged over every account, including those with no children — the
  /// number is about take-up, not about the families who did get started.
  static double averageChildrenPerParent(
    List<AdminParentAccountSummary> accounts,
  ) {
    if (accounts.isEmpty) return 0;
    final total =
        accounts.fold(0, (sum, account) => sum + account.childProfileCount);
    return total / accounts.length;
  }

  /// Accounts whose email contains [query], case-insensitively. An empty
  /// query matches everything.
  static List<AdminParentAccountSummary> search(
    List<AdminParentAccountSummary> accounts,
    String query,
  ) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return accounts;
    return [
      for (final account in accounts)
        if (account.email.toLowerCase().contains(needle)) account,
    ];
  }
}
