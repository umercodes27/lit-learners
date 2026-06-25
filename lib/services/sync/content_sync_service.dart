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
  })  : _contentDao = contentDao,
        _contentRemoteDataSource = contentRemoteDataSource;

  final ContentDao _contentDao;
  final ContentRemoteDataSource _contentRemoteDataSource;

  Future<ContentSyncReport> syncNow() async {
    try {
      final bundle = await _contentRemoteDataSource.getPublishedContent();
      if (bundle.isEmpty) {
        return const ContentSyncReport(
          modulesPulled: 0,
          levelsPulled: 0,
          didApplyRemoteContent: false,
          failedItems: 0,
        );
      }

      await _contentDao.replaceContent(
        modules: bundle.modules,
        levels: bundle.levels,
      );
      return ContentSyncReport(
        modulesPulled: bundle.modules.length,
        levelsPulled: bundle.levels.length,
        didApplyRemoteContent: true,
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
