import 'dart:convert';

import '../../models/sync_outbox_item.dart';
import '../local/child_profile_dao.dart';
import '../local/sync_outbox_dao.dart';
import '../remote/child_profile_remote_data_source.dart';

class SyncReport {
  const SyncReport({
    required this.pushedProfiles,
    this.pulledProfiles = 0,
    this.removedProfiles = 0,
    required this.completedOutboxItems,
    required this.failedItems,
  });

  final int pushedProfiles;
  final int pulledProfiles;
  final int removedProfiles;
  final int completedOutboxItems;
  final int failedItems;

  bool get hasFailures => failedItems > 0;
}

class SyncService {
  SyncService({
    required ChildProfileDao childProfileDao,
    required SyncOutboxDao syncOutboxDao,
    required ChildProfileRemoteDataSource childProfileRemoteDataSource,
  })  : _childProfileDao = childProfileDao,
        _syncOutboxDao = syncOutboxDao,
        _childProfileRemoteDataSource = childProfileRemoteDataSource;

  final ChildProfileDao _childProfileDao;
  final SyncOutboxDao _syncOutboxDao;
  final ChildProfileRemoteDataSource _childProfileRemoteDataSource;

  Future<SyncReport> syncNow({String? parentId}) async {
    var pushedProfiles = 0;
    var pulledProfiles = 0;
    var removedProfiles = 0;
    var completedOutboxItems = 0;
    var failedItems = 0;

    final unsyncedProfiles = await _childProfileDao.getUnsynced();
    for (final profile in unsyncedProfiles) {
      try {
        await _childProfileRemoteDataSource.upsertProfile(profile);
        await _childProfileDao.markSynced(profile.id);
        pushedProfiles += 1;
      } catch (error) {
        failedItems += 1;
      }
    }

    final pendingItems = await _syncOutboxDao.getPending();
    for (final item in pendingItems) {
      try {
        await _handleOutboxItem(item);
        await _syncOutboxDao.markCompleted(item.id);
        completedOutboxItems += 1;
      } catch (error) {
        await _syncOutboxDao.markFailed(
          id: item.id,
          error: error.toString(),
        );
        failedItems += 1;
      }
    }

    if (parentId != null && failedItems == 0) {
      try {
        final pullReport = await _pullRemoteProfiles(parentId);
        pulledProfiles = pullReport.pulledProfiles;
        removedProfiles = pullReport.removedProfiles;
      } catch (error) {
        failedItems += 1;
      }
    }

    return SyncReport(
      pushedProfiles: pushedProfiles,
      pulledProfiles: pulledProfiles,
      removedProfiles: removedProfiles,
      completedOutboxItems: completedOutboxItems,
      failedItems: failedItems,
    );
  }

  Future<_ProfilePullReport> _pullRemoteProfiles(String parentId) async {
    final remoteProfiles =
        await _childProfileRemoteDataSource.getProfiles(parentId);
    var pulledProfiles = 0;

    for (final remoteProfile in remoteProfiles) {
      final existing = await _childProfileDao.getById(remoteProfile.id);
      if (existing != null &&
          !existing.isSynced &&
          existing.updatedAt.isAfter(remoteProfile.updatedAt)) {
        continue;
      }

      await _childProfileDao.upsert(remoteProfile.copyWith(isSynced: true));
      pulledProfiles += 1;
    }

    final remoteChildIds = remoteProfiles.map((profile) => profile.id).toSet();
    final removedProfiles = await _childProfileDao.deleteSyncedProfilesNotIn(
      parentId: parentId,
      childIds: remoteChildIds,
    );

    return _ProfilePullReport(
      pulledProfiles: pulledProfiles,
      removedProfiles: removedProfiles,
    );
  }

  Future<void> _handleOutboxItem(SyncOutboxItem item) async {
    if (item.entityType == SyncOutboxItem.childProfileEntity &&
        item.operation == SyncOutboxItem.deleteOperation) {
      final payload = jsonDecode(item.payloadJson) as Map<String, Object?>;
      await _childProfileRemoteDataSource.deleteProfile(
        parentId: payload['parentId']! as String,
        childId: payload['childId']! as String,
      );
      return;
    }

    throw UnsupportedError(
      'Unsupported sync item: ${item.entityType}/${item.operation}',
    );
  }
}

class _ProfilePullReport {
  const _ProfilePullReport({
    required this.pulledProfiles,
    required this.removedProfiles,
  });

  final int pulledProfiles;
  final int removedProfiles;
}
