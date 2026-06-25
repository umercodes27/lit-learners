import 'package:flutter_test/flutter_test.dart';
import 'package:little_learners/models/sync_outbox_item.dart';
import 'package:little_learners/services/local/sync_outbox_dao.dart';

void main() {
  group('InMemorySyncOutboxDao', () {
    test('queues, fails, and completes pending items', () async {
      final dao = InMemorySyncOutboxDao();
      final item = SyncOutboxItem.childProfileDelete(
        parentId: 'parent-1',
        childId: 'child-1',
      );

      await dao.enqueue(item);

      expect(await dao.getPending(), hasLength(1));

      await dao.markFailed(id: item.id, error: 'offline');
      final failed = (await dao.getPending()).single;

      expect(failed.attemptCount, 1);
      expect(failed.lastError, 'offline');

      await dao.markCompleted(item.id);

      expect(await dao.getPending(), isEmpty);
    });
  });
}
