import '../../core/utils/activity_component_visuals.dart';
import '../../models/activity_pack.dart';
import '../../models/learning_level.dart';
import '../../views/child_dashboard/widgets/level_map.dart';

/// Puts age-pack activities onto the level map the seeded ladder walks.
///
/// The two content systems model a level differently. The seeded ladder stores
/// a [LearningLevel] row per level and tracks progress against its id; a pack
/// level is a JSON blob describing one playable component and is not in the
/// database at all. The map, though, only ever asks a stop for four things -
/// its number, its title, its caption and whether it can be opened - so a pack
/// level can answer as well as a seeded one.
///
/// This is the adapter that lets it. It builds a [LearningLevel] that exists
/// only to be drawn: nothing reads it back, nothing saves it, and its id is
/// deliberately prefixed so a row can never be confused for a real one.
class ActivityPackStops {
  const ActivityPackStops._();

  /// Prefix marking an id as drawn-only. Progress is keyed by level id, so an
  /// id that could collide with a seeded level would write pack progress onto
  /// a real level's row.
  static const idPrefix = 'pack';

  static String levelIdFor(ActivityLevel level) =>
      '$idPrefix:${level.moduleKey}:${level.key}';

  /// One stop per pack level, in the pack's own order.
  ///
  /// Every stop comes back open. The packs record no progress - finishing an
  /// activity pops the screen and nothing is written - so locking them in
  /// sequence would strand a child behind a door that never opens. Until pack
  /// completion is stored, an open road is the honest drawing of it.
  static List<LevelStopData> forModule(
    ActivityModule module, {
    required String moduleId,
    required int stage,
  }) {
    final levels = [...module.levels]
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    return [
      for (final (index, level) in levels.indexed)
        LevelStopData(
          level: _drawnLevel(level, moduleId: moduleId, stage: stage, number: index + 1),
          stars: 0,
          completed: false,
          canOpen: true,
          canDownload: false,
          // What the child will be doing, which is the useful thing to say
          // about a pack level. See [LevelStopData.caption].
          caption: ActivityComponentVisuals.labelFor(level.data.component),
          lockReason: '',
        ),
    ];
  }

  static LearningLevel _drawnLevel(
    ActivityLevel level, {
    required String moduleId,
    required int stage,
    required int number,
  }) {
    return LearningLevel(
      id: levelIdFor(level),
      moduleId: moduleId,
      stage: stage,
      levelNumber: number,
      title: level.data.title,
      subtitle: ActivityComponentVisuals.labelFor(level.data.component),
      // The seeded types describe how a level is played, and no pack activity
      // maps cleanly onto one. Only the map's drawing reads this field, and it
      // reads it for nothing but the stop disc, so the most neutral member
      // stands in rather than a wrong-but-specific one.
      type: LevelType.flashcards,
      passingScore: 0,
      isBundled: true,
      isDownloaded: true,
    );
  }
}
