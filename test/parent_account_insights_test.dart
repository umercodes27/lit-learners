import 'package:flutter_test/flutter_test.dart';
import 'package:little_learners/models/admin_stats.dart';
import 'package:little_learners/services/insights/parent_account_insights.dart';

AdminParentAccountSummary account(
  String email, {
  int children = 1,
  DateTime? joined,
}) =>
    AdminParentAccountSummary(
      parentId: email,
      email: email,
      childProfileCount: children,
      createdAt: joined,
    );

void main() {
  group('children per parent', () {
    test('buckets, with parents who never added a child kept visible', () {
      final buckets = ParentAccountInsights.childrenPerParent([
        account('a@x.com', children: 0),
        account('b@x.com', children: 0),
        account('c@x.com', children: 1),
        account('d@x.com', children: 2),
        account('e@x.com', children: 5),
      ]);

      expect(buckets.map((b) => b.label), ['None', '1', '2', '3+']);
      expect(buckets.map((b) => b.count), [2, 1, 1, 1]);
    });

    test('no accounts still returns the buckets, all empty', () {
      final buckets = ParentAccountInsights.childrenPerParent([]);
      expect(buckets, hasLength(4));
      expect(buckets.every((b) => b.count == 0), isTrue);
    });
  });

  group('joins by month', () {
    final now = DateTime(2026, 9, 15);

    test('runs oldest first and ends with the current month', () {
      final buckets = ParentAccountInsights.joinsByMonth(
        [
          account('a@x.com', joined: DateTime(2026, 9, 2)),
          account('b@x.com', joined: DateTime(2026, 9, 20)),
          account('c@x.com', joined: DateTime(2026, 7, 4)),
        ],
        now: now,
        months: 3,
      );

      expect(buckets.map((b) => b.label), ['Jul', 'Aug', 'Sep']);
      expect(buckets.map((b) => b.count), [1, 0, 2]);
    });

    test('a month boundary at the turn of the year still walks back', () {
      final buckets = ParentAccountInsights.joinsByMonth(
        [account('a@x.com', joined: DateTime(2025, 12, 30))],
        now: DateTime(2026, 1, 10),
        months: 3,
      );

      expect(buckets.map((b) => b.label), ['Nov', 'Dec', 'Jan']);
      expect(buckets.map((b) => b.count), [0, 1, 0]);
    });

    test('accounts with no date are left out, not piled into the first month',
        () {
      final buckets = ParentAccountInsights.joinsByMonth(
        [account('a@x.com'), account('b@x.com')],
        now: now,
        months: 3,
      );

      expect(buckets.every((b) => b.count == 0), isTrue,
          reason: 'an unknown date must not invent a spike');
    });
  });

  test('the average counts parents who added nobody', () {
    final average = ParentAccountInsights.averageChildrenPerParent([
      account('a@x.com', children: 0),
      account('b@x.com', children: 2),
    ]);
    expect(average, 1.0);
    expect(ParentAccountInsights.averageChildrenPerParent([]), 0);
  });

  group('search', () {
    final accounts = [
      account('Ayesha@Example.com'),
      account('bilal@example.com'),
      account('carla@other.org'),
    ];

    test('matches case-insensitively anywhere in the address', () {
      expect(
        ParentAccountInsights.search(accounts, 'AYESHA').map((a) => a.email),
        ['Ayesha@Example.com'],
      );
      expect(ParentAccountInsights.search(accounts, 'example.com'), hasLength(2));
    });

    test('an empty query matches everything', () {
      expect(ParentAccountInsights.search(accounts, '   '), hasLength(3));
    });
  });
}
