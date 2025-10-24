import 'package:drift/drift.dart';
import 'package:fairshare_app/core/database/app_database.dart';
import 'package:fairshare_app/core/database/interfaces/dao_interfaces.dart';
import 'package:fairshare_app/core/database/tables/sync_table.dart';
import 'package:fairshare_app/core/logging/app_logger.dart';

part 'sync_dao.g.dart';

@DriftAccessor(tables: [SyncQueue])
class SyncDao extends DatabaseAccessor<AppDatabase>
    with _$SyncDaoMixin, LoggerMixin
    implements ISyncDao {
  final AppDatabase db;

  SyncDao(this.db) : super(db);

  /// Enqueue an operation to the upload queue
  /// Uses INSERT OR REPLACE to ensure only one operation per entity per user
  ///
  /// [ownerId] is the ID of the user who initiated this sync operation
  @override
  Future<void> enqueueOperation({
    required String ownerId,
    required String entityType,
    required String entityId,
    required String operationType,
    String? metadata,
  }) async {
    log.d(
      '📤 Enqueueing: $entityType/$entityId ($operationType) for user $ownerId',
    );

    // Check if already exists for this user
    final existing =
        await (select(syncQueue)..where(
          (q) =>
              q.ownerId.equals(ownerId) &
              q.entityType.equals(entityType) &
              q.entityId.equals(entityId),
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
          ownerId: Value(ownerId),
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

  /// Get all pending operations from the upload queue for a specific user
  ///
  /// [ownerId] is the ID of the user whose operations to retrieve
  @override
  Future<List<SyncQueueData>> getPendingOperations({
    required String ownerId,
    int? limit,
  }) async {
    final query =
        select(syncQueue)
          ..where((s) => s.ownerId.equals(ownerId))
          ..orderBy([(s) => OrderingTerm.asc(s.createdAt)]);
    if (limit != null) {
      query.limit(limit);
    }
    return query.get();
  }

  /// Remove an operation from the queue after successful upload
  @override
  Future<void> removeQueuedOperation(int id) async {
    await (delete(syncQueue)..where((s) => s.id.equals(id))).go();
  }

  /// Increment retry count and update error message for failed operation
  @override
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

  /// Get count of pending operations for a specific user
  ///
  /// [ownerId] is the ID of the user whose operation count to retrieve
  @override
  Future<int> getPendingOperationCount(String ownerId) async {
    final query =
        selectOnly(syncQueue)
          ..addColumns([syncQueue.id.count()])
          ..where(syncQueue.ownerId.equals(ownerId));
    final result = await query.getSingle();
    return result.read(syncQueue.id.count()) ?? 0;
  }
}
