import '../models/learning_level.dart';
import '../models/parent_report.dart';
import '../models/progress.dart';
import '../repositories/child_profile_repository.dart';
import '../repositories/content_repository.dart';
import '../repositories/progress_repository.dart';
import '../services/content/activity_pack_stops.dart';
import '../services/sync/progress_sync_service.dart';
import '../services/sync/sync_service.dart';

abstract class ParentReportRepository {
  Future<ParentReport> getReport(String parentId);
}

class CachedParentReportRepository implements ParentReportRepository {
  CachedParentReportRepository({
    required ChildProfileRepository childProfileRepository,
    required ProgressRepository progressRepository,
    required ContentRepository contentRepository,
    SyncService? profileSyncService,
    ProgressSyncService? progressSyncService,
  })  : _childProfileRepository = childProfileRepository,
        _progressRepository = progressRepository,
        _contentRepository = contentRepository,
        _profileSyncService = profileSyncService,
        _progressSyncService = progressSyncService;

  final ChildProfileRepository _childProfileRepository;
  final ProgressRepository _progressRepository;
  final ContentRepository _contentRepository;
  final SyncService? _profileSyncService;
  final ProgressSyncService? _progressSyncService;

  @override
  Future<ParentReport> getReport(String parentId) async {
    await _profileSyncService?.syncNow(parentId: parentId);
    final profiles = await _childProfileRepository.getProfiles(parentId);
    final childReports = <ChildReport>[];

    for (final profile in profiles) {
      await _progressSyncService?.syncNow(childId: profile.id);
      final progress = await _progressRepository.getProgressForChild(
        profile.id,
      );
      childReports.add(
        ChildReport(
          profile: profile,
          progressReports: await _progressReports(progress),
        ),
      );
    }

    childReports.sort((a, b) {
      final aDate = a.lastActivityAt ?? a.profile.updatedAt;
      final bDate = b.lastActivityAt ?? b.profile.updatedAt;
      return bDate.compareTo(aDate);
    });

    return ParentReport(
      parentId: parentId,
      childReports: childReports,
      generatedAt: DateTime.now(),
    );
  }

  Future<List<LevelProgressReport>> _progressReports(
    List<LevelProgress> progressItems,
  ) async {
    final reports = <LevelProgressReport>[];
    final sortedProgress = progressItems.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    for (final progress in sortedProgress) {
      final level = await _contentRepository.getLevelById(progress.levelId);
      final module = await _contentRepository.getModuleById(progress.moduleId);
      reports.add(
        LevelProgressReport(
          progress: progress,
          levelTitle: level?.title ?? _titleForUnknownLevel(progress.levelId),
          moduleTitle: module?.title ?? progress.moduleId,
          levelType: level?.type ?? LevelType.flashcards,
          watchedLessonTitles: _watchedLessonTitles(level, progress),
        ),
      );
    }
    return reports;
  }

  /// What to call a level the content tree has never heard of.
  ///
  /// Age-pack activities are played from JSON rather than from a level row, so
  /// `getLevelById` cannot name one. Their ids are built by
  /// [ActivityPackStops.levelIdFor] as `pack:<subject>:<level_key>`, and the
  /// last segment is the readable half - printing the whole id would show a
  /// parent something that looks like a bug.
  /// What to call a level the content tree has never heard of.
  ///
  /// Age-pack activities are played from JSON rather than from a level row, so
  /// `getLevelById` cannot name one. Their ids are built by
  /// [ActivityPackStops.levelIdFor] as `pack:<subject>:<level_key>`, and the
  /// last segment is the readable half — printing the whole id would show a
  /// parent something that looks like a bug.
  String _titleForUnknownLevel(String levelId) {
    if (!levelId.startsWith('${ActivityPackStops.idPrefix}:')) return levelId;

    final key = levelId.split(':').last;
    final numbered = RegExp(r'^level_(\d+)$').firstMatch(key);
    if (numbered != null) return 'Level ${numbered.group(1)}';

    // Anything not numbered, like the age-3 pack's `moral_stories`.
    return key
        .split('_')
        .map(
          (word) => word.isEmpty
              ? word
              : '${word[0].toUpperCase()}${word.substring(1)}',
        )
        .join(' ');
  }

  List<String> _watchedLessonTitles(
    LearningLevel? level,
    LevelProgress progress,
  ) {
    final lessons = level?.videoLessons ?? const [];
    return progress.watchedLessonIds.map((lessonId) {
      for (final lesson in lessons) {
        if (lesson.id == lessonId) return lesson.title;
      }
      return lessonId;
    }).toList();
  }
}
