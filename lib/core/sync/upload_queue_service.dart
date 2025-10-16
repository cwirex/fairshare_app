import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fairshare_app/core/config/feature_flags.dart';
import 'package:fairshare_app/core/constants/firestore_collections.dart';
import 'package:fairshare_app/core/database/app_database.dart';
import 'package:fairshare_app/core/logging/app_logger.dart';
import 'package:fairshare_app/core/monitoring/sync_metrics.dart';
import 'package:fairshare_app/features/expenses/domain/entities/expense_entity.dart';
import 'package:fairshare_app/features/expenses/data/services/firestore_expense_service.dart';
import 'package:fairshare_app/features/groups/domain/entities/group_entity.dart';
import 'package:fairshare_app/features/groups/data/services/firestore_group_service.dart';

/// Service responsible for processing the upload queue.
///
/// Processes queued operations, handles retries, server timestamps, and hard deletes.
/// User-scoped: Only processes operations for the specified owner.
class UploadQueueService with LoggerMixin {
  final AppDatabase _database;
  final FirestoreExpenseService _expenseService;
  final FirestoreGroupService _groupService;
  final FirebaseFirestore _firestore;
  final String ownerId; // ID of the user whose queue to process

  UploadQueueService({
    required AppDatabase database,
    required FirestoreExpenseService expenseService,
    required FirestoreGroupService groupService,
    required FirebaseFirestore firestore,
    required this.ownerId,
  }) : _database = database,
       _expenseService = expenseService,
       _groupService = groupService,
       _firestore = firestore;

  /// Process all pending operations in the queue for this user
  Future<UploadQueueResult> processQueue() async {
    final operations = await _database.syncDao.getPendingOperations(
      ownerId: ownerId,
      limit: FeatureFlags.uploadBatchSize,
    );

    if (operations.isEmpty) {
      SyncMetrics.instance.updateQueueDepth(0);
      return UploadQueueResult(
        totalProcessed: 0,
        successCount: 0,
        failureCount: 0,
      );
    }

    log.i('⬆️ Processing ${operations.length} queued operations');

    int successCount = 0;
    int failureCount = 0;

    for (final operation in operations) {
      // Skip if exceeded max retries
      if (operation.retryCount >= FeatureFlags.maxSyncRetries) {
        log.w(
          'Operation exceeded max retries: ${operation.entityType}/${operation.entityId}',
        );
        failureCount++;
        continue;
      }

      try {
        await _processOperation(operation);
        await _database.syncDao.removeQueuedOperation(operation.id);
        successCount++;
        SyncMetrics.instance.recordSyncSuccess();
      } catch (e) {
        log.e(
          'Operation failed: ${operation.entityType}/${operation.entityId}: $e',
        );
        await _database.syncDao.markOperationFailed(operation.id, e.toString());
        failureCount++;
        SyncMetrics.instance.recordSyncError('upload_${operation.entityType}');
      }
    }

    final remaining = await _database.syncDao.getPendingOperationCount(ownerId);
    SyncMetrics.instance.updateQueueDepth(remaining);

    log.i('✅ Queue processed for user $ownerId: $successCount succeeded, $failureCount failed');

    return UploadQueueResult(
      totalProcessed: operations.length,
      successCount: successCount,
      failureCount: failureCount,
    );
  }

  /// Process a single operation from the queue
  Future<void> _processOperation(SyncQueueData operation) async {
    log.d(
      'Processing: ${operation.entityType}/${operation.entityId} (${operation.operationType}) for owner $ownerId',
    );

    switch (operation.entityType) {
      case 'expense':
        await _processExpenseOperation(operation);
        break;
      case 'group':
        await _processGroupOperation(operation);
        break;
      case 'group_member':
        await _processGroupMemberOperation(operation);
        break;
      case 'expense_share':
        await _processExpenseShareOperation(operation);
        break;
      default:
        throw Exception('Unknown entity type: ${operation.entityType}');
    }
  }

  /// Process an expense operation with server timestamp handling
  Future<void> _processExpenseOperation(SyncQueueData operation) async {
    switch (operation.operationType) {
      case 'create':
      case 'update':
        final expense = await _database.expensesDao.getExpenseById(
          operation.entityId,
        );
        if (expense == null) {
          throw Exception('Expense not found: ${operation.entityId}');
        }

        // Upload to Firestore (server timestamp added by service)
        final uploadResult = await _expenseService.uploadExpense(expense);
        uploadResult.fold((_) => null, (error) => throw error);

        // Fetch server timestamp and update local DB
        final doc =
            await _firestore
                .collection(FirestoreCollections.groups)
                .doc(expense.groupId)
                .collection(FirestoreCollections.expenses)
                .doc(expense.id)
                .get();

        if (doc.exists) {
          final data = doc.data()!;
          final serverTimestamp = (data[ExpenseFields.updatedAt] as Timestamp).toDate();
          await _database.expensesDao.updateExpenseTimestamp(
            expense.id,
            serverTimestamp,
          );
          log.d('Updated expense timestamp from server: ${expense.id}');
        }
        break;

      case 'delete':
        // Get expense with deleted flag to retrieve groupId
        final expense = await _database.expensesDao.getExpenseById(
          operation.entityId,
          includeDeleted: true,
        );
        if (expense == null) {
          throw Exception('Expense not found: ${operation.entityId}');
        }

        // Delete from Firestore
        final deleteResult = await _expenseService.deleteExpense(
          expense.groupId,
          operation.entityId,
        );
        deleteResult.fold((_) => null, (error) => throw error);

        // Hard delete from local DB after successful Firestore deletion
        await _database.expensesDao.hardDeleteExpense(operation.entityId);
        log.d('Hard deleted expense: ${operation.entityId}');
        break;

      default:
        throw Exception('Unknown operation type: ${operation.operationType}');
    }
  }

  /// Process a group operation with server timestamp handling
  Future<void> _processGroupOperation(SyncQueueData operation) async {
    switch (operation.operationType) {
      case 'create':
      case 'update':
        final group = await _database.groupsDao.getGroupById(
          operation.entityId,
        );
        if (group == null) {
          throw Exception('Group not found: ${operation.entityId}');
        }

        // Upload to Firestore (server timestamp added by service)
        final uploadResult = await _groupService.uploadGroup(group);
        uploadResult.fold((_) => null, (error) => throw error);

        // Fetch server timestamp and update local DB
        final doc = await _firestore.collection(FirestoreCollections.groups).doc(group.id).get();

        if (doc.exists) {
          final data = doc.data()!;
          final serverTimestamp = (data[GroupFields.updatedAt] as Timestamp).toDate();
          await _database.groupsDao.updateGroupTimestamp(
            group.id,
            serverTimestamp,
          );
          log.d('Updated group timestamp from server: ${group.id}');
        }
        break;

      case 'delete':
        // Delete from Firestore
        final deleteResult = await _groupService.deleteGroup(
          operation.entityId,
        );
        deleteResult.fold((_) => null, (error) => throw error);

        // Hard delete from local DB after successful Firestore deletion
        await _database.groupsDao.hardDeleteGroup(operation.entityId);
        log.d('Hard deleted group: ${operation.entityId}');
        break;

      default:
        throw Exception('Unknown operation type: ${operation.operationType}');
    }
  }

  /// Process a group member operation
  Future<void> _processGroupMemberOperation(SyncQueueData operation) async {
    // entityId format: "groupId_userId"
    final parts = operation.entityId.split('_');
    if (parts.length != 2) {
      throw Exception(
        'Invalid group member entityId format: ${operation.entityId}',
      );
    }

    final groupId = parts[0];
    final userId = parts[1];

    switch (operation.operationType) {
      case 'create':
        // Get the member from local DB
        final members = await _database.groupsDao.getAllGroupMembers(groupId);
        final member = members.firstWhere(
          (m) => m.userId == userId,
          orElse:
              () => throw Exception('Group member not found: $groupId/$userId'),
        );

        // Upload to Firestore
        final result = await _groupService.uploadGroupMember(member);
        result.fold((_) => null, (error) => throw error);
        break;

      case 'delete':
        final result = await _groupService.removeGroupMember(groupId, userId);
        result.fold((_) => null, (error) => throw error);
        break;

      default:
        throw Exception('Unknown operation type: ${operation.operationType}');
    }
  }

  /// Process an expense share operation
  Future<void> _processExpenseShareOperation(SyncQueueData operation) async {
    // entityId format: "expenseId_userId"
    final parts = operation.entityId.split('_');
    if (parts.length != 2) {
      throw Exception(
        'Invalid expense share entityId format: ${operation.entityId}',
      );
    }

    final expenseId = parts[0];
    final userId = parts[1];

    switch (operation.operationType) {
      case 'create':
        // Get the share from local DB
        final shares = await _database.expenseSharesDao.getExpenseShares(
          expenseId,
        );
        final share = shares.firstWhere(
          (s) => s.userId == userId,
          orElse:
              () =>
                  throw Exception(
                    'Expense share not found: $expenseId/$userId',
                  ),
        );

        // Upload to Firestore
        final result = await _expenseService.uploadExpenseShare(share);
        result.fold((_) => null, (error) => throw error);
        break;

      default:
        throw Exception('Unknown operation type: ${operation.operationType}');
    }
  }

  /// Get count of pending operations for this user
  Future<int> getPendingCount() async {
    return _database.syncDao.getPendingOperationCount(ownerId);
  }
}

/// Result of processing the upload queue
class UploadQueueResult {
  final int totalProcessed;
  final int successCount;
  final int failureCount;

  UploadQueueResult({
    required this.totalProcessed,
    required this.successCount,
    required this.failureCount,
  });

  bool get hasFailures => failureCount > 0;
  bool get allSucceeded => failureCount == 0 && totalProcessed > 0;
}
