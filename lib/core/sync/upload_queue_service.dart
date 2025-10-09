import 'dart:async';
import 'dart:convert';

import 'package:fairshare_app/core/database/app_database.dart';
import 'package:fairshare_app/features/expenses/data/services/firestore_expense_service.dart';
import 'package:fairshare_app/features/groups/data/services/firestore_group_service.dart';

/// Service responsible for processing the upload queue.
///
/// Implements Option D: Separate Upload Queue Table strategy.
/// Processes queued operations, handles retries, and manages failure recovery.
class UploadQueueService {
  final AppDatabase _database;
  final FirestoreExpenseService _expenseService;
  final FirestoreGroupService _groupService;

  static const int maxRetries = 3;
  static const int batchSize = 10;

  UploadQueueService({
    required AppDatabase database,
    required FirestoreExpenseService expenseService,
    required FirestoreGroupService groupService,
  })  : _database = database,
        _expenseService = expenseService,
        _groupService = groupService;

  /// Process all pending operations in the queue
  Future<UploadQueueResult> processQueue() async {
    final operations = await _database.getPendingOperations(limit: batchSize);

    if (operations.isEmpty) {
      return UploadQueueResult(
        totalProcessed: 0,
        successCount: 0,
        failureCount: 0,
      );
    }

    int successCount = 0;
    int failureCount = 0;

    for (final operation in operations) {
      // Skip if exceeded max retries
      if (operation.retryCount >= maxRetries) {
        failureCount++;
        continue;
      }

      try {
        await _processOperation(operation);
        await _database.removeQueuedOperation(operation.id);
        successCount++;
      } catch (e) {
        await _database.markOperationFailed(operation.id, e.toString());
        failureCount++;
      }
    }

    return UploadQueueResult(
      totalProcessed: operations.length,
      successCount: successCount,
      failureCount: failureCount,
    );
  }

  /// Process a single operation from the queue
  Future<void> _processOperation(SyncQueueData operation) async {
    print('⚙️ Processing: ${operation.entityType}/${operation.entityId} (${operation.operationType})');

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
      default:
        throw Exception('Unknown entity type: ${operation.entityType}');
    }

    print('✅ Processed successfully: ${operation.entityType}/${operation.entityId}');
  }

  /// Process an expense operation
  Future<void> _processExpenseOperation(SyncQueueData operation) async {
    switch (operation.operationType) {
      case 'create':
      case 'update':
        final expense = await _database.getExpenseById(operation.entityId);
        if (expense == null) {
          throw Exception('Expense not found: ${operation.entityId}');
        }
        final result = await _expenseService.uploadExpense(expense);
        result.fold(
          (_) => null,
          (error) => throw error,
        );
        break;
      case 'delete':
        // Parse metadata to get groupId
        if (operation.metadata == null) {
          throw Exception('Delete operation missing metadata for expense: ${operation.entityId}');
        }
        final metadata = jsonDecode(operation.metadata!) as Map<String, dynamic>;
        final groupId = metadata['groupId'] as String?;
        if (groupId == null) {
          throw Exception('Delete operation missing groupId in metadata for expense: ${operation.entityId}');
        }
        final result = await _expenseService.deleteExpense(groupId, operation.entityId);
        result.fold(
          (_) => null,
          (error) => throw error,
        );
        break;
      default:
        throw Exception('Unknown operation type: ${operation.operationType}');
    }
  }

  /// Process a group operation
  Future<void> _processGroupOperation(SyncQueueData operation) async {
    switch (operation.operationType) {
      case 'create':
      case 'update':
        final group = await _database.getGroupById(operation.entityId);
        if (group == null) {
          throw Exception('Group not found: ${operation.entityId}');
        }
        final result = await _groupService.uploadGroup(group);
        result.fold(
          (_) => null,
          (error) => throw error,
        );
        break;
      case 'delete':
        final result = await _groupService.deleteGroup(operation.entityId);
        result.fold(
          (_) => null,
          (error) => throw error,
        );
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
      throw Exception('Invalid group member entityId format: ${operation.entityId}');
    }

    final groupId = parts[0];
    final userId = parts[1];

    switch (operation.operationType) {
      case 'create':
        // Get the member from local DB
        final members = await _database.getAllGroupMembers(groupId);
        final member = members.firstWhere(
          (m) => m.userId == userId,
          orElse: () => throw Exception('Group member not found: $groupId/$userId'),
        );

        // Upload to Firestore
        final result = await _groupService.uploadGroupMember(member);
        result.fold(
          (_) => null,
          (error) => throw error,
        );
        break;

      case 'delete':
        final result = await _groupService.removeGroupMember(groupId, userId);
        result.fold(
          (_) => null,
          (error) => throw error,
        );
        break;

      default:
        throw Exception('Unknown operation type: ${operation.operationType}');
    }
  }

  /// Get count of pending operations
  Future<int> getPendingCount() async {
    return _database.getPendingOperationCount();
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
