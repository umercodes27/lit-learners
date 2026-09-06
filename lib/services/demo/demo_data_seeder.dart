import '../../core/constants/avatar_presets.dart';
import '../../core/utils/age_stage_helper.dart';
import '../../models/child_profile.dart';
import '../../models/learning_level.dart';
import '../../models/progress.dart';
import '../../repositories/auth_repository.dart';
import '../../repositories/content_repository.dart';
import '../local/child_profile_dao.dart';
import '../local/progress_dao.dart';
import 'demo_families.dart';

/// Fills the local database with invented families so the admin screens can
/// be looked at with something the shape of real data behind them.
///
/// Demo mode only. With Firebase on, none of this is constructed and the
/// admin portal reads the real project — so no invented family can reach a
/// client's data.
///
/// Everything is written through the same DAOs the app itself uses, and every
/// id is fixed, so seeding is idempotent and the numbers the dashboard counts
/// are genuinely counted rather than declared.
class DemoDataSeeder {
  DemoDataSeeder({
    required InMemoryAuthRepository authRepository,
    required ChildProfileDao childProfileDao,
    required ProgressDao progressDao,
    required ContentRepository contentRepository,
  })  : _auth = authRepository,
        _profiles = childProfileDao,
        _progress = progressDao,
        _content = contentRepository;

  final InMemoryAuthRepository _auth;
  final ChildProfileDao _profiles;
  final ProgressDao _progress;
  final ContentRepository _content;

  /// The password every demo family shares, so any of them can be signed into
  /// to see the parent side of the app as a family with real history.
  static const demoPassword = 'Demo@123';

  Future<void> seed() async {
    final now = DateTime.now();

    for (final family in demoFamilies) {
      final joined = now.subtract(Duration(days: family.joinedDaysAgo));

      _auth.seedAccount(
        id: family.parentId,
        email: family.email,
        password: demoPassword,
        createdAt: joined,
      );

      for (var index = 0; index < family.childCount; index++) {
        await _profiles.upsert(
          ChildProfile(
            id: family.childId(index),
            parentId: family.parentId,
            name: family.childNames[index],
            age: family.childAges[index],
            avatarAsset: AvatarPresets
                .all[(family.index + index) % AvatarPresets.all.length].id,
            leaderboardOptIn: family.index.isEven,
            displayPreference: 'en',
            createdAt: joined,
            updatedAt: joined,
            // Nothing here has been anywhere near a backend.
            isSynced: false,
          ),
        );
      }
    }

    await _seedProgress(now);
  }

  /// Gives the children some history, so module usage and completion rates
  /// are computed from rows rather than asserted.
  Future<void> _seedProgress(DateTime now) async {
    for (final family in demoFamilies) {
      if (family.levelsPlayed == 0) continue;

      for (var index = 0; index < family.childCount; index++) {
        final age = family.childAges[index];
        final levels = await _levelsFor(AgeStageHelper.stageForAge(age));
        if (levels.isEmpty) continue;

        // Deterministic rather than random: the demo should look the same
        // every launch, or nobody can tell a real change from a reshuffle.
        final seed = family.index * 31 + index * 7;
        final played = family.levelsPlayed.clamp(0, levels.length);

        for (var n = 0; n < played; n++) {
          final level = levels[(seed + n * 3) % levels.length];
          final variation = (seed + n) % 10;

          // Roughly a third are left unfinished, which is what makes the
          // completion rate mean anything and gives the parent report
          // something to call paused.
          final completed = variation > 2;
          final stars = completed ? 1 + (variation % 3) : 0;

          await _progress.upsert(
            LevelProgress(
              childId: family.childId(index),
              moduleId: level.moduleId,
              levelId: level.id,
              completed: completed,
              starsEarned: stars,
              rewardEarned: stars == 3,
              score: completed ? 55 + variation * 4 : null,
              updatedAt: now.subtract(Duration(days: (seed + n * 2) % 40)),
              isSynced: false,
            ),
          );
        }
      }
    }
  }

  /// Four stages, twenty-four children: without this the whole curriculum
  /// would be read back out of the database once per child.
  final Map<int, List<LearningLevel>> _levelCache = {};

  Future<List<LearningLevel>> _levelsFor(int stage) async {
    final cached = _levelCache[stage];
    if (cached != null) return cached;

    final modules = await _content.getModulesForStage(stage);
    final levels = <LearningLevel>[];
    for (final module in modules) {
      levels.addAll(
        await _content.getLevelsForModule(moduleId: module.id, stage: stage),
      );
    }
    return _levelCache[stage] = levels;
  }
}
