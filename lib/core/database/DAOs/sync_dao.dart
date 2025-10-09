import 'package:drift/drift.dart';
import 'package:fairshare_app/core/database/app_database.dart';
import 'package:fairshare_app/core/database/tables/sync_table.dart';
import 'package:fairshare_app/core/logging/app_logger.dart';

part 'sync_dao.g.dart';

@DriftAccessor(tables: [SyncQueue])
class SyncDao extends DatabaseAccessor<AppDatabase>
    with _$SyncDaoMixin, LoggerMixin {
  final AppDatabase db;

  SyncDao(this.db) : super(db);

  /// Enqueue an operation to the upload queue
  /// Uses INSERT OR REPLACE to ensure only one operation per entity
  Future<void> enqueueOperation({
    required String entityType,
    required String entityId,
    required String operationType,
    String? metadata,
  }) async {
    log.d('📤 Enqueueing: $entityType/$entityId ($operationType)');

    // Check if already exists
    final existing =
        await (select(syncQueue)..where(
          (q) => q.entityType.equals(entityType) & q.entityId.equals(entityId),
        )).getSingleOrNull();

    if (existing != null) {
      // Update existing entry
      await (update(syncQueue)..where((q) => q.id.equals(existing.id))).write(
        SyncQueueCompanion(
          operationType: Value(operationType),
          metadata: Value(metadata),
          createdAt: Value(DateTime.now()),
          retryCount: Value(0),
          lastError: const Value(null),
        ),
      );
      log.d('✅ Updated existing queue entry');
    } else {
      // Insert new entry
      await into(syncQueue).insert(
        SyncQueueCompanion(
          entityType: Value(entityType),
          entityId: Value(entityId),
          operationType: Value(operationType),
          metadata: Value(metadata),
          createdAt: Value(DateTime.now()),
          retryCount: Value(0),
          lastError: const Value(null),
        ),
      );
      log.d('✅ Enqueued successfully');
    }
  }

  // === SYNC-SAFE INSERT/UPDATE OPERATIONS ===
  // These methods are used by the sync service to apply remote changes
  // without triggering new upload queue operations.
  // They bypass repositories and write directly to the database.

  /// Get all pending operations from the upload queue
  Future<List<SyncQueueData>> getPendingOperations({int? limit}) async {
    final query = select(syncQueue)
      ..orderBy([(s) => OrderingTerm.asc(s.createdAt)]);
    if (limit != null) {
      query.limit(limit);
    }
    return query.get();
  }

  /// Remove an operation from the queue after successful upload
  Future<void> removeQueuedOperation(int id) async {
    await (delete(syncQueue)..where((s) => s.id.equals(id))).go();
  }

  /// Increment retry count and update error message for failed operation
  Future<void> markOperationFailed(int id, String errorMessage) async {
    final current =
        await (select(syncQueue)..where((s) => s.id.equals(id))).getSingle();
    await (update(syncQueue)..where((s) => s.id.equals(id))).write(
      SyncQueueCompanion(
        retryCount: Value(current.retryCount + 1),
        lastError: Value(errorMessage),
      ),
    );
  }

  /// Get count of pending operations
  Future<int> getPendingOperationCount() async {
    final query = selectOnly(syncQueue)..addColumns([syncQueue.id.count()]);
    final result = await query.getSingle();
    return result.read(syncQueue.id.count()) ?? 0;
  }
}
