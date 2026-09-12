import '../../data/seed_content.dart';
import '../../models/learning_level.dart';
import '../../models/learning_module.dart';
import '../local/content_dao.dart';
import '../remote/content_remote_data_source.dart';

class ContentSyncReport {
  const ContentSyncReport({
    required this.modulesPulled,
    required this.levelsPulled,
    required this.didApplyRemoteContent,
    required this.failedItems,
  });

  final int modulesPulled;
  final int levelsPulled;
  final bool didApplyRemoteContent;
  final int failedItems;

  bool get hasFailures => failedItems > 0;
}

class ContentSyncService {
  ContentSyncService({
    required ContentDao contentDao,
    required ContentRemoteDataSource contentRemoteDataSource,
    List<LearningModule>? bundledModules,
    List<LearningLevel>? bundledLevels,
  })  : _contentDao = contentDao,
        _contentRemoteDataSource = contentRemoteDataSource,
        _bundledModules = bundledModules ?? seedModules,
        _bundledLevels = bundledLevels ?? seedLevels;

  final ContentDao _contentDao;
  final ContentRemoteDataSource _contentRemoteDataSource;

  /// The curriculum that ships inside the app. It is the floor, not a first
  /// draft: remote content is layered over it rather than replacing it.
  final List<LearningModule> _bundledModules;
  final List<LearningLevel> _bundledLevels;

  /// Remote content wins where the ids match, and adds where they do not.
  ///
  /// A module missing from the remote side means "the admin has not published
  /// one by that name", not "delete the one that ships in the app". Hiding a
  /// bundled module would need to be said explicitly, not inferred from
  /// silence.
  ({List<LearningModule> modules, List<LearningLevel> levels})
      _mergedOverBundle(ContentBundle bundle) {
    // Insertion order is preserved, so the bundled curriculum keeps its
    // running order and anything new is appended after it.
    final modules = <String, LearningModule>{
      for (final module in _bundledModules) module.id: module,
    };
    for (final module in bundle.modules) {
      modules[module.id] = module;
    }

    final levels = <String, LearningLevel>{
      for (final level in _bundledLevels) level.id: level,
    };
    for (final level in bundle.levels) {
      levels[level.id] = level;
    }

    // A level reaches a child only when its module does - either one that
    // ships in the app or one an admin has published. This is the one place
    // that knows both, which is why the remote sources no longer filter: they
    // could only check the second, and so discarded every published edit to a
    // built-in level whose module had never been written to Firestore.
    final moduleIds = modules.keys.toSet();

    return (
      modules: modules.values.toList(),
      levels: [
        for (final level in levels.values)
          if (moduleIds.contains(level.moduleId)) level,
      ],
    );
  }

  Future<ContentSyncReport> syncNow() async {
    try {
      final bundle = await _contentRemoteDataSource.getPublishedContent();

      // Merged over the bundled curriculum, never substituted for it.
      //
      // This used to write the remote bundle straight into the database,
      // which meant publishing a single module from the admin panel deleted
      // all eight bundled ones and every level under them: `replaceContent`
      // empties the content tables first, and the remote side only ever
      // holds what an admin has explicitly published.
      //
      // Written even when nothing is published. An empty remote side used to
      // return early without touching the database, so undoing the last
      // admin edit — restoring a built-in level, or deleting the only custom
      // module — never reached a device: it kept showing the edited copy.
      // The bundle merged with nothing is the bundle, which is the right
      // answer for that case too.
      final merged = _mergedOverBundle(bundle);
      await _contentDao.replaceContent(
        modules: merged.modules,
        levels: merged.levels,
      );
      return ContentSyncReport(
        modulesPulled: bundle.modules.length,
        levelsPulled: bundle.levels.length,
        didApplyRemoteContent: !bundle.isEmpty,
        failedItems: 0,
      );
    } catch (error) {
      return const ContentSyncReport(
        modulesPulled: 0,
        levelsPulled: 0,
        didApplyRemoteContent: false,
        failedItems: 1,
      );
    }
  }
}
