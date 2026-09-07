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

  static final _demoParentAccounts = <AdminParentAccountSummary>[
    AdminParentAccountSummary(
      parentId: 'demo-parent-1',
      email: 'ayesha.khan@example.com',
      childProfileCount: 2,
      createdAt: DateTime(2026, 3, 14),
    ),
    AdminParentAccountSummary(
      parentId: 'demo-parent-2',
      email: 'bilal.ahmed@example.com',
      childProfileCount: 3,
      createdAt: DateTime(2026, 4, 2),
    ),
    AdminParentAccountSummary(
      parentId: 'demo-parent-3',
      email: 'sana.riaz@example.com',
      childProfileCount: 1,
      createdAt: DateTime(2026, 5, 27),
    ),
  ];

  static const _demoStats = AdminStats(
    totalParentAccounts: 3,
    totalChildProfiles: 6,
    totalQuizzes: 18,
    totalModules: 7,
    totalLevels: 34,
    completedLevelCount: 21,
    moduleUsage: [
      AdminModuleUsage(
        moduleId: 'english',
        moduleTitle: 'English',
        attemptedLevelCount: 12,
        completedLevelCount: 8,
        learnersEngaged: 5,
      ),
      AdminModuleUsage(
        moduleId: 'math',
        moduleTitle: 'Math',
        attemptedLevelCount: 9,
        completedLevelCount: 6,
        learnersEngaged: 4,
      ),
      AdminModuleUsage(
        moduleId: 'urdu',
        moduleTitle: 'اردو',
        attemptedLevelCount: 7,
        completedLevelCount: 4,
        learnersEngaged: 3,
      ),
      AdminModuleUsage(
        moduleId: 'story',
        moduleTitle: 'Stories',
        attemptedLevelCount: 5,
        completedLevelCount: 3,
        learnersEngaged: 2,
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
