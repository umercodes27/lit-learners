import 'dart:convert';

import '../../models/progress.dart';

class ProgressMapper {
  const ProgressMapper._();

  static LevelProgress fromLocalMap(Map<String, Object?> map) {
    return LevelProgress(
      childId: map['childId']! as String,
      moduleId: map['moduleId']! as String,
      levelId: map['levelId']! as String,
      completed: (map['completed']! as int) == 1,
      score: map['score'] as int?,
      starsEarned: map['starsEarned']! as int,
      rewardEarned: (map['rewardEarned']! as int) == 1,
      rewardEarnedAt: _optionalDate(map['rewardEarnedAt']),
      watchedLessonIds: _stringListFromJson(
        map['watchedLessonIdsJson']! as String,
      ),
      lastWatchedAt: _optionalDate(map['lastWatchedAt']),
      updatedAt: DateTime.parse(map['updatedAt']! as String),
      isSynced: (map['isSynced']! as int) == 1,
    );
  }

  static Map<String, Object?> toLocalMap(LevelProgress progress) {
    return {
      'childId': progress.childId,
      'moduleId': progress.moduleId,
      'levelId': progress.levelId,
      'completed': progress.completed ? 1 : 0,
      'score': progress.score,
      'starsEarned': progress.starsEarned,
      'rewardEarned': progress.rewardEarned ? 1 : 0,
      'rewardEarnedAt': progress.rewardEarnedAt?.toIso8601String(),
      'watchedLessonIdsJson': jsonEncode(progress.watchedLessonIds),
      'lastWatchedAt': progress.lastWatchedAt?.toIso8601String(),
      'updatedAt': progress.updatedAt.toIso8601String(),
      'isSynced': progress.isSynced ? 1 : 0,
    };
  }

  static DateTime? _optionalDate(Object? value) {
    if (value == null) return null;
    return DateTime.parse(value as String);
  }

  static List<String> _stringListFromJson(String json) {
    final decoded = jsonDecode(json) as List<dynamic>;
    return decoded.cast<String>();
  }
}
