import 'child_profile.dart';
import 'learning_level.dart';
import 'progress.dart';

class ParentReport {
  const ParentReport({
    required this.parentId,
    required this.childReports,
    required this.generatedAt,
  });

  final String parentId;
  final List<ChildReport> childReports;
  final DateTime generatedAt;

  int get childCount => childReports.length;

  int get completedLevels {
    return childReports.fold(0, (sum, child) => sum + child.completedLevels);
  }

  int get totalStars {
    return childReports.fold(0, (sum, child) => sum + child.starsEarned);
  }

  int get watchedVideoLessons {
    return childReports.fold(
      0,
      (sum, child) => sum + child.watchedVideoLessons,
    );
  }

  int get rewardsEarned {
    return childReports.fold(0, (sum, child) => sum + child.rewardsEarned);
  }

  int? get averageQuizScore {
    final scores = [
      for (final child in childReports) ...child.quizScores,
    ];
    if (scores.isEmpty) return null;

    final total = scores.fold(0, (sum, score) => sum + score);
    return (total / scores.length).round();
  }
}

class ChildReport {
  const ChildReport({
    required this.profile,
    required this.progressReports,
  });

  final ChildProfile profile;
  final List<LevelProgressReport> progressReports;

  int get completedLevels {
    return progressReports.where((report) => report.progress.completed).length;
  }

  int get starsEarned {
    return progressReports.fold(
      0,
      (sum, report) => sum + report.progress.starsEarned,
    );
  }

  int get watchedVideoLessons {
    return progressReports.fold(
      0,
      (sum, report) => sum + report.progress.watchedLessonIds.length,
    );
  }

  int get rewardsEarned {
    return progressReports
        .where((report) => report.progress.rewardEarned)
        .length;
  }

  List<int> get quizScores {
    return [
      for (final report in progressReports)
        if (report.progress.score != null) report.progress.score!,
    ];
  }

  int? get averageQuizScore {
    if (quizScores.isEmpty) return null;

    final total = quizScores.fold(0, (sum, score) => sum + score);
    return (total / quizScores.length).round();
  }

  DateTime? get lastActivityAt {
    final dates = [
      for (final report in progressReports) report.progress.updatedAt,
      for (final report in progressReports)
        if (report.progress.lastWatchedAt != null)
          report.progress.lastWatchedAt!,
    ];
    if (dates.isEmpty) return null;

    dates.sort((a, b) => b.compareTo(a));
    return dates.first;
  }
}

class LevelProgressReport {
  const LevelProgressReport({
    required this.progress,
    required this.levelTitle,
    required this.moduleTitle,
    required this.levelType,
    required this.watchedLessonTitles,
  });

  final LevelProgress progress;
  final String levelTitle;
  final String moduleTitle;
  final LevelType levelType;
  final List<String> watchedLessonTitles;
}
