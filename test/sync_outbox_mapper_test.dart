import 'package:flutter_test/flutter_test.dart';
import 'package:little_learners/models/sync_outbox_item.dart';
import 'package:little_learners/services/local/sync_outbox_mapper.dart';

void main() {
  test('SyncOutboxMapper round-trips local map values', () {
    final createdAt = DateTime.utc(2026, 2, 1, 10, 30);
    final item = SyncOutboxItem(
      id: 'outbox-1',
      entityType: SyncOutboxItem.childProfileEntity,
      entityId: 'child-1',
      operation: SyncOutboxItem.deleteOperation,
      payloadJson: '{"parentId":"parent-1","childId":"child-1"}',
      createdAt: createdAt,
      attemptCount: 2,
      lastError: 'network',
    );

    final map = SyncOutboxMapper.toLocalMap(item);
    final restored = SyncOutboxMapper.fromLocalMap(map);

    expect(restored.id, item.id);
    expect(restored.entityType, item.entityType);
    expect(restored.entityId, item.entityId);
    expect(restored.operation, item.operation);
    expect(restored.payloadJson, item.payloadJson);
    expect(restored.createdAt, createdAt);
    expect(restored.attemptCount, 2);
    expect(restored.lastError, 'network');
  });
}
