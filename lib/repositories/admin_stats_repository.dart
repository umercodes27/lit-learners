import '../models/admin_stats.dart';
import '../services/demo/demo_families.dart';
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

  /// The same invented families the local seeder writes into the database.
  ///
  /// Shared rather than restated, so this fallback and the seeded demo can
  /// never disagree about who exists. In practice demo mode uses
  /// [LocalAdminStatsRepository], which counts real rows; this stands in only
  /// where no local database is available at all.
  static final _demoParentAccounts = <AdminParentAccountSummary>[
    for (final family in demoFamilies)
      AdminParentAccountSummary(
        parentId: family.parentId,
        email: family.email,
        childProfileCount: family.childCount,
        createdAt: DateTime.now().subtract(
          Duration(days: family.joinedDaysAgo),
        ),
      ),
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
