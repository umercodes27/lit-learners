import '../models/admin_stats.dart';
import 'admin_authorization_repository.dart';

/// System-wide, read-only metrics for the admin portal.
abstract class AdminStatsRepository {
  Future<AdminStats> loadStats();

  Future<List<AdminParentAccountSummary>> loadParentAccounts();
}

/// Demo-mode metrics so the portal renders without Firebase.
class InMemoryAdminStatsRepository implements AdminStatsRepository {
  InMemoryAdminStatsRepository({
    AdminStats? stats,
    List<AdminParentAccountSummary>? parentAccounts,
  })  : _stats = stats ?? _demoStats,
        _parentAccounts = parentAccounts ?? _demoParentAccounts;

  final AdminStats _stats;
  final List<AdminParentAccountSummary> _parentAccounts;

  @override
  Future<AdminStats> loadStats() async => _stats;

  @override
  Future<List<AdminParentAccountSummary>> loadParentAccounts() async {
    return List.unmodifiable(_parentAccounts);
  }

  /// Eighteen made-up families, so the admin screens can be judged with
  /// something the shape of real data behind them.
  ///
  /// Only ever reached with `USE_FIREBASE=false` — with Firebase on, the
  /// Firestore repository is wired instead, so none of this can reach a real
  /// deployment.
  ///
  /// Dates are relative to now rather than fixed, or the sign-up chart would
  /// quietly empty out as months passed and the demo would stop looking like
  /// anything. The spread is deliberately uneven and rising, because a flat
  /// chart proves nothing about whether the chart works.
  static final _demoParentAccounts = <AdminParentAccountSummary>[
    for (final family in _demoFamilies)
      AdminParentAccountSummary(
        parentId: 'demo-parent-${family.$1}',
        email: family.$2,
        childProfileCount: family.$3,
        createdAt: DateTime.now().subtract(Duration(days: family.$4)),
      ),
  ];

  /// (id, email, children, days ago).
  ///
  /// Three families have no child profile at all. That is not padding: it is
  /// the case the accounts chart is built to surface, and a demo where
  /// everyone is a happy user would hide the one finding the screen exists
  /// to show.
  static const _demoFamilies = <(int, String, int, int)>[
    (1, 'ayesha.khan@example.com', 2, 164),
    (2, 'bilal.ahmed@example.com', 1, 151),
    (3, 'sana.riaz@example.com', 3, 139),
    (4, 'hamza.iqbal@example.com', 1, 126),
    (5, 'maryam.shah@example.com', 2, 112),
    (6, 'usman.tariq@example.com', 0, 104),
    (7, 'zainab.malik@example.com', 1, 95),
    (8, 'faisal.qureshi@example.com', 2, 81),
    (9, 'hina.abbas@example.com', 1, 73),
    (10, 'omar.siddiqui@example.com', 0, 64),
    (11, 'nadia.hussain@example.com', 3, 52),
    (12, 'imran.javed@example.com', 1, 44),
    (13, 'rabia.aslam@example.com', 2, 37),
    (14, 'danish.raza@example.com', 1, 31),
    (15, 'fatima.noor@example.com', 2, 22),
    (16, 'tariq.mehmood@example.com', 1, 15),
    (17, 'saira.bano@example.com', 0, 9),
    (18, 'kamran.ali@example.com', 1, 3),
  ];

  /// Totals that agree with the families above — 18 accounts, 24 children —
  /// and with the curriculum that actually ships: eight modules, 52 levels.
  /// A demo whose numbers contradict each other teaches an admin to distrust
  /// the screen.
  static const _demoStats = AdminStats(
    totalParentAccounts: 18,
    totalChildProfiles: 24,
    totalQuizzes: 31,
    totalModules: 8,
    totalLevels: 52,
    completedLevelCount: 96,
    moduleUsage: [
      AdminModuleUsage(
        moduleId: 'english',
        moduleTitle: 'English',
        attemptedLevelCount: 34,
        completedLevelCount: 24,
        learnersEngaged: 19,
      ),
      AdminModuleUsage(
        moduleId: 'math',
        moduleTitle: 'Math',
        attemptedLevelCount: 28,
        completedLevelCount: 19,
        learnersEngaged: 17,
      ),
      AdminModuleUsage(
        moduleId: 'urdu',
        moduleTitle: 'اردو',
        attemptedLevelCount: 22,
        completedLevelCount: 13,
        learnersEngaged: 12,
      ),
      AdminModuleUsage(
        moduleId: 'tracing',
        moduleTitle: 'Tracing',
        attemptedLevelCount: 18,
        completedLevelCount: 11,
        learnersEngaged: 10,
      ),
      AdminModuleUsage(
        moduleId: 'story',
        moduleTitle: 'Stories',
        attemptedLevelCount: 16,
        completedLevelCount: 11,
        learnersEngaged: 9,
      ),
      AdminModuleUsage(
        moduleId: 'logic',
        moduleTitle: 'Logic',
        attemptedLevelCount: 14,
        completedLevelCount: 8,
        learnersEngaged: 8,
      ),
      AdminModuleUsage(
        moduleId: 'drawing',
        moduleTitle: 'Drawing',
        attemptedLevelCount: 10,
        completedLevelCount: 6,
        learnersEngaged: 6,
      ),
      AdminModuleUsage(
        moduleId: 'video',
        moduleTitle: 'Video Learning',
        attemptedLevelCount: 6,
        completedLevelCount: 4,
        learnersEngaged: 5,
      ),
    ],
  );
}

/// Wraps a delegate so every metric read requires an authenticated admin,
/// mirroring [AuthorizedAdminContentRepository].
class AuthorizedAdminStatsRepository implements AdminStatsRepository {
  const AuthorizedAdminStatsRepository({
    required AdminStatsRepository delegate,
    required AdminAuthorizationRepository authorizationRepository,
  })  : _delegate = delegate,
        _authorizationRepository = authorizationRepository;

  final AdminStatsRepository _delegate;
  final AdminAuthorizationRepository _authorizationRepository;

  @override
  Future<AdminStats> loadStats() async {
    await _authorizationRepository.requireStatisticsAccess();
    return _delegate.loadStats();
  }

  @override
  Future<List<AdminParentAccountSummary>> loadParentAccounts() async {
    // Narrower than statistics: this list carries parent emails.
    await _authorizationRepository.requireParentAccountAccess();
    return _delegate.loadParentAccounts();
  }
}
