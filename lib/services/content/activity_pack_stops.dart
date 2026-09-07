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

  /// The copy the seeded ladder shows on a stop that is not open yet. Repeated
  /// verbatim so a child meets one explanation, not two.
  static const lockReason = 'Finish the previous level first.';

  /// One stop per pack level, in the pack's own order.
  ///
  /// Stops unlock in sequence, exactly as the seeded ladder's do: the first is
  /// always open, and each one after it waits for the one before to be
  /// finished. That ordering is the pack's own - its levels are keyed
  /// `level_1`, `level_2`, and its content is authored to be met in that order.
  ///
  /// [isCompleted] and [starsFor] are asked about the drawn level's id, which
  /// is what completing a pack activity records against. See [levelIdFor].
  static List<LevelStopData> forModule(
    ActivityModule module, {
    required String moduleId,
    required int stage,
    required bool Function(String levelId) isCompleted,
    required int Function(String levelId) starsFor,
  }) {
    final levels = _sorted(module);
    final drawnLevels = levelsFor(module, moduleId: moduleId, stage: stage);

    final stops = <LevelStopData>[];
    var previousDone = true;

    for (final (index, drawn) in drawnLevels.indexed) {
      final level = levels[index];
      final done = isCompleted(drawn.id);

      stops.add(
        LevelStopData(
          level: drawn,
          stars: starsFor(drawn.id),
          completed: done,
          canOpen: previousDone,
          canDownload: false,
          // What the child will be doing, which is the useful thing to say
          // about a pack level. See [LevelStopData.caption].
          caption: ActivityComponentVisuals.labelFor(level.data.component),
          lockReason: lockReason,
        ),
      );

      previousDone = done;
    }

    return stops;
  }

  /// The same drawn levels [forModule] puts on the map, without the map.
  ///
  /// A pack activity records progress against these ids, so anything that
  /// reads a child's progress — the parent's report most of all — has to know
  /// the levels exist. Without them the rows are orphans: real progress
  /// pointing at a level nothing can name, and a subject the child has been
  /// playing all week reads as never started.
  static List<LearningLevel> levelsFor(
    ActivityModule module, {
    required String moduleId,
    required int stage,
  }) {
    return [
      for (final (index, level) in _sorted(module).indexed)
        _drawnLevel(level, moduleId: moduleId, stage: stage, number: index + 1),
    ];
  }

  /// The pack's own order, which is the order its content is authored to be
  /// met in. Shared so the map and the report number the levels identically.
  static List<ActivityLevel> _sorted(ActivityModule module) =>
      [...module.levels]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

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
