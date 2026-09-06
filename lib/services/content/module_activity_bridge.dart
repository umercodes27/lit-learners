import 'activity_pack_loader.dart';

/// Joins the dashboard's module tree to the age-pack curriculum.
///
/// The two content systems grew up separately: modules and their levels come
/// from the seeded (and later Firestore-synced) tree, while the age packs are
/// JSON files bundled with the app. A child does not know or care which is
/// which — tapping Math should reach everything the app has for Math — so this
/// is the single place that says how the two sets of ids line up.
class ModuleActivityBridge {
  const ModuleActivityBridge._();

  /// Dashboard module id -> age-pack module key.
  ///
  /// A module absent from this map has no age-pack counterpart, and its screen
  /// is left exactly as it was. Video is watched rather than played, Drawing is
  /// free-form on a canvas, and Tracing is taught inside each pack's own
  /// subject instead of standing as a subject of its own.
  static const _packModuleKeys = <String, String>{
    'math': 'math',
    'english': 'english',
    'urdu': 'urdu',
    'logic': 'logic',
    'story': 'storytelling',
  };

  /// The pack module backing this dashboard module, or null when there is
  /// none.
  static String? packModuleKeyFor(String moduleId) =>
      _packModuleKeys[moduleId];

  static bool hasActivities(String moduleId) =>
      _packModuleKeys.containsKey(moduleId);

  /// Which pack a child of this age plays.
  ///
  /// There is now a pack for every age the app accepts, so nobody is served
  /// someone else's curriculum: a four-year-old gets age 4 rather than the
  /// age-3 pack they used to fall back to. Ages outside the range still get
  /// the nearest pack rather than an empty screen — a just-turned-two gets
  /// age 2, and anyone older than four gets age 4. The age picker on the home
  /// screen remains the way to reach another pack deliberately.
  static int packAgeFor(int age) {
    if (age <= 2) return 2;
    if (age == 3) return 3;
    return 4;
  }

  static String packPathFor(int age) => switch (packAgeFor(age)) {
        2 => ActivityPackLoader.age2Path,
        3 => ActivityPackLoader.age3Path,
        _ => ActivityPackLoader.age4Path,
      };
}
