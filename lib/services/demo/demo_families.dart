/// One invented family: a parent account and the children on it.
class DemoFamily {
  const DemoFamily({
    required this.index,
    required this.email,
    required this.childNames,
    required this.childAges,
    required this.joinedDaysAgo,
    required this.levelsPlayed,
  });

  final int index;
  final String email;
  final List<String> childNames;
  final List<int> childAges;

  /// Relative to now rather than a fixed date, or the sign-up chart would
  /// quietly empty out as months passed and the demo would stop looking like
  /// anything at all.
  final int joinedDaysAgo;

  /// How many levels each child of this family has attempted. Kept per family
  /// so the progress statistics are uneven in a way real usage is.
  final int levelsPlayed;

  String get parentId => 'demo-parent-$index';
  int get childCount => childNames.length;

  String childId(int child) => 'demo-child-$index-$child';
}

/// Eighteen invented families, twenty-four children.
///
/// The single source for every demo number, so the dashboard totals, the
/// accounts charts and the seeded database cannot disagree with each other. A
/// demo whose own figures contradict themselves teaches an admin to distrust
/// the screen.
///
/// Three families have no child at all. That is not padding — it is the case
/// the accounts chart exists to surface, and a demo where everyone is a happy
/// user would hide the one finding that screen was built to show.
///
/// The join dates rise across the window and dip in the partial current
/// month, because a flat chart proves nothing about whether the chart works.
const demoFamilies = <DemoFamily>[
  DemoFamily(
    index: 1,
    email: 'ayesha.khan@example.com',
    childNames: ['Zara', 'Ali'],
    childAges: [3, 2],
    joinedDaysAgo: 164,
    levelsPlayed: 9,
  ),
  DemoFamily(
    index: 2,
    email: 'bilal.ahmed@example.com',
    childNames: ['Hassan'],
    childAges: [4],
    joinedDaysAgo: 151,
    levelsPlayed: 12,
  ),
  DemoFamily(
    index: 3,
    email: 'sana.riaz@example.com',
    childNames: ['Ayla', 'Bilal', 'Noor'],
    childAges: [2, 3, 4],
    joinedDaysAgo: 139,
    levelsPlayed: 7,
  ),
  DemoFamily(
    index: 4,
    email: 'hamza.iqbal@example.com',
    childNames: ['Yusuf'],
    childAges: [3],
    joinedDaysAgo: 126,
    levelsPlayed: 11,
  ),
  DemoFamily(
    index: 5,
    email: 'maryam.shah@example.com',
    childNames: ['Amna', 'Saad'],
    childAges: [4, 2],
    joinedDaysAgo: 112,
    levelsPlayed: 6,
  ),
  DemoFamily(
    index: 6,
    email: 'usman.tariq@example.com',
    childNames: [],
    childAges: [],
    joinedDaysAgo: 104,
    levelsPlayed: 0,
  ),
  DemoFamily(
    index: 7,
    email: 'zainab.malik@example.com',
    childNames: ['Eman'],
    childAges: [2],
    joinedDaysAgo: 95,
    levelsPlayed: 5,
  ),
  DemoFamily(
    index: 8,
    email: 'faisal.qureshi@example.com',
    childNames: ['Musa', 'Hania'],
    childAges: [3, 2],
    joinedDaysAgo: 81,
    levelsPlayed: 8,
  ),
  DemoFamily(
    index: 9,
    email: 'hina.abbas@example.com',
    childNames: ['Areeba'],
    childAges: [4],
    joinedDaysAgo: 73,
    levelsPlayed: 14,
  ),
  DemoFamily(
    index: 10,
    email: 'omar.siddiqui@example.com',
    childNames: [],
    childAges: [],
    joinedDaysAgo: 64,
    levelsPlayed: 0,
  ),
  DemoFamily(
    index: 11,
    email: 'nadia.hussain@example.com',
    childNames: ['Ibrahim', 'Maha', 'Zoya'],
    childAges: [4, 3, 2],
    joinedDaysAgo: 52,
    levelsPlayed: 10,
  ),
  DemoFamily(
    index: 12,
    email: 'imran.javed@example.com',
    childNames: ['Rayyan'],
    childAges: [2],
    joinedDaysAgo: 44,
    levelsPlayed: 4,
  ),
  DemoFamily(
    index: 13,
    email: 'rabia.aslam@example.com',
    childNames: ['Laiba', 'Umar'],
    childAges: [3, 4],
    joinedDaysAgo: 37,
    levelsPlayed: 9,
  ),
  DemoFamily(
    index: 14,
    email: 'danish.raza@example.com',
    childNames: ['Fatima'],
    childAges: [2],
    joinedDaysAgo: 31,
    levelsPlayed: 3,
  ),
  DemoFamily(
    index: 15,
    email: 'fatima.noor@example.com',
    childNames: ['Aiza', 'Talha'],
    childAges: [2, 4],
    joinedDaysAgo: 22,
    levelsPlayed: 6,
  ),
  DemoFamily(
    index: 16,
    email: 'tariq.mehmood@example.com',
    childNames: ['Hurain'],
    childAges: [3],
    joinedDaysAgo: 15,
    levelsPlayed: 5,
  ),
  DemoFamily(
    index: 17,
    email: 'saira.bano@example.com',
    childNames: [],
    childAges: [],
    joinedDaysAgo: 9,
    levelsPlayed: 0,
  ),
  DemoFamily(
    index: 18,
    email: 'kamran.ali@example.com',
    childNames: ['Zain'],
    childAges: [2],
    joinedDaysAgo: 3,
    levelsPlayed: 2,
  ),
];

int get demoChildCount =>
    demoFamilies.fold(0, (sum, family) => sum + family.childCount);
