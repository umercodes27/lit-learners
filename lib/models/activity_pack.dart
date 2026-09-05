import 'activity_data.dart';

/// One level inside a module, keyed as it appears in the JSON (`level_1`).
class ActivityLevel {
  const ActivityLevel({
    required this.key,
    required this.moduleKey,
    required this.data,
  });

  /// `level_1`, `level_2`, … Kept verbatim so ordering and routing can use it.
  final String key;
  final String moduleKey;
  final ActivityData data;

  String get title => data.title;

  /// `Level 1` from `level_1`; falls back to the raw key for anything else,
  /// e.g. the age-3 pack's `moral_stories`.
  String get displayLabel {
    final match = RegExp(r'^level_(\d+)$').firstMatch(key);
    if (match != null) return 'Level ${match.group(1)}';
    return key
        .split('_')
        .map((word) => word.isEmpty ? word : '${word[0].toUpperCase()}${word.substring(1)}')
        .join(' ');
  }

  int get sortOrder {
    final match = RegExp(r'(\d+)').firstMatch(key);
    return match == null ? 999 : int.parse(match.group(1)!);
  }
}

/// One subject — english, urdu, math, logic, storytelling.
class ActivityModule {
  const ActivityModule({
    required this.key,
    required this.title,
    required this.levels,
  });

  final String key;
  final String title;
  final List<ActivityLevel> levels;
}

/// A whole age pack: the parsed contents of one `little-learners-ageN-data.json`.
///
/// Nothing here is age-2 specific. Pointing [ActivityPackLoader] at another
/// pack file gives the same widgets a different curriculum, which is the whole
/// reason the components take data rather than hard-coded content.
class ActivityPack {
  const ActivityPack({
    required this.age,
    required this.phase,
    required this.modules,
    required this.correctSound,
    required this.wrongSound,
  });

  factory ActivityPack.fromJson(Map<String, dynamic> json) {
    final feedback = json['feedback'];
    final feedbackMap = feedback is Map<String, dynamic> ? feedback : const {};

    final rawModules = json['modules'];
    final modules = <ActivityModule>[];

    if (rawModules is Map<String, dynamic>) {
      for (final entry in rawModules.entries) {
        final value = entry.value;
        if (value is! Map<String, dynamic>) continue;

        final moduleRtl = value['rtl'] as bool? ?? _isRightToLeft(entry.key);
        final levels = <ActivityLevel>[];

        for (final levelEntry in value.entries) {
          final levelValue = levelEntry.value;
          // A module map holds both scalars (title, rtl) and level maps; only
          // the maps that name a component are levels.
          if (levelValue is! Map<String, dynamic>) continue;
          if (!levelValue.containsKey('component')) continue;

          final data =
              ActivityData.fromJson(levelValue, moduleRtl: moduleRtl);
          if (data == null) continue;
          levels.add(ActivityLevel(
            key: levelEntry.key,
            moduleKey: entry.key,
            data: data,
          ));
        }

        levels.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

        modules.add(ActivityModule(
          key: entry.key,
          title: value['title'] as String? ?? _titleCase(entry.key),
          levels: levels,
        ));
      }
    }

    return ActivityPack(
      age: (json['age'] as num?)?.toInt() ?? 0,
      phase: json['phase'] as String? ?? '',
      modules: modules,
      correctSound: feedbackMap['correct_sound'] as String?,
      wrongSound: feedbackMap['wrong_sound'] as String?,
    );
  }

  final int age;
  final String phase;
  final List<ActivityModule> modules;

  /// Pack-wide reward and retry sounds. Individual levels do not override
  /// these in the age-2 pack, but a level could by carrying its own feedback.
  final String? correctSound;
  final String? wrongSound;

  ActivityModule? moduleByKey(String key) {
    for (final module in modules) {
      if (module.key == key) return module;
    }
    return null;
  }

  ActivityLevel? levelByKey(String moduleKey, String levelKey) {
    final module = moduleByKey(moduleKey);
    if (module == null) return null;
    for (final level in module.levels) {
      if (level.key == levelKey) return level;
    }
    return null;
  }

  /// Every asset path the pack references, deduplicated.
  Set<String> get referencedAssets => {
        if (correctSound != null) correctSound!,
        if (wrongSound != null) wrongSound!,
        for (final module in modules)
          for (final level in module.levels) ...[
            ...level.data.referencedAssets,
            if (level.data.correctSound != null) level.data.correctSound!,
            if (level.data.wrongSound != null) level.data.wrongSound!,
          ],
      };

  /// Modules that read right-to-left unless the pack says otherwise.
  ///
  /// The age-2 pack does not carry an `rtl` flag, and asking every author to
  /// remember one on the Urdu module is a rule that will be forgotten exactly
  /// once and then ship. A pack can still override it by setting `"rtl"`
  /// explicitly either way.
  static bool _isRightToLeft(String moduleKey) => moduleKey == 'urdu';

  static String _titleCase(String value) => value
      .split('_')
      .map((word) =>
          word.isEmpty ? word : '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');
}
