import 'package:fairshare_app/core/database/app_database.dart';
import 'package:fairshare_app/core/events/event_broker.dart';
import 'package:fairshare_app/features/auth/domain/entities/user.dart';
import 'package:fairshare_app/features/expenses/domain/entities/expense_entity.dart';
import 'package:fairshare_app/features/expenses/domain/entities/expense_share_entity.dart';
import 'package:fairshare_app/features/groups/domain/entities/group_entity.dart';
import 'package:fairshare_app/features/groups/domain/entities/group_member_entity.dart';

/// Interface for ExpensesDao - Data access layer for expense operations.
///
/// Provides methods for CRUD operations on expenses with support for:
/// - Soft deletion (marking as deleted without removal)
/// - Streaming queries for reactive UI updates
/// - Sync integration with Firestore
abstract class IExpensesDao {
  /// Insert a new expense into the database.
  Future<void> insertExpense(ExpenseEntity expense);

  /// Get an expense by ID.
  ///
  /// [includeDeleted] - If true, returns expense even if soft-deleted.
  /// Returns null if expense not found.
  Future<ExpenseEntity?> getExpenseById(String id, {bool includeDeleted = false});

  /// Get all expenses for a specific group.
  /// Only returns non-deleted expenses.
  Future<List<ExpenseEntity>> getExpensesByGroup(String groupId);

  /// Get all expenses across all groups.
  /// Only returns non-deleted expenses.
  Future<List<ExpenseEntity>> getAllExpenses();

  /// Update the server timestamp for an expense (used during sync).
  Future<void> updateExpenseTimestamp(String id, DateTime serverTimestamp);

  /// Update an existing expense.
  Future<void> updateExpense(ExpenseEntity expense);

  /// Delete an expense (hard delete - immediate removal).
  Future<void> deleteExpense(String id);

  /// Watch expenses for a group - returns a stream that emits on changes.
  /// Used for reactive UI updates.
  Stream<List<ExpenseEntity>> watchExpensesByGroup(String groupId);

  /// Watch all expenses - returns a stream that emits on changes.
  /// Used for reactive UI updates.
  Stream<List<ExpenseEntity>> watchAllExpenses();

  /// Upsert (insert or update) an expense from Firestore sync.
  /// Fires events via eventBroker to notify UI of changes.
  Future<void> upsertExpenseFromSync(ExpenseEntity expense, EventBroker eventBroker);

  /// Soft delete an expense (marks as deleted without removal).
  /// Allows recovery and maintains referential integrity.
  Future<void> softDeleteExpense(String id);

  /// Restore a soft-deleted expense.
  Future<void> restoreExpense(String id);

  /// Hard delete an expense (permanent removal from database).
  Future<void> hardDeleteExpense(String id);
}

/// Interface for GroupsDao - Data access layer for group operations.
///
/// Provides methods for:
/// - Group CRUD operations with soft deletion support
/// - Group member management
/// - Streaming queries for reactive UI updates
/// - Sync integration with Firestore
abstract class IGroupsDao {
  /// Insert a new group into the database.
  Future<void> insertGroup(GroupEntity group);

  /// Get a group by ID.
  ///
  /// [includeDeleted] - If true, returns group even if soft-deleted.
  /// Returns null if group not found.
  Future<GroupEntity?> getGroupById(String id, {bool includeDeleted = false});

  /// Get all groups.
  /// Only returns non-deleted groups.
  Future<List<GroupEntity>> getAllGroups();

  /// Update an existing group.
  Future<void> updateGroup(GroupEntity group);

  /// Delete a group (hard delete - immediate removal).
  Future<void> deleteGroup(String id);

  /// Add a member to a group.
  Future<void> addGroupMember(GroupMemberEntity member);

  /// Remove a member from a group.
  Future<void> removeGroupMember(String groupId, String userId);

  /// Get all member IDs for a group.
  Future<List<String>> getGroupMembers(String groupId);

  /// Get all groups for a specific user.
  Future<List<GroupEntity>> getUserGroups(String userId);

  /// Watch all groups - returns a stream that emits on changes.
  /// Used for reactive UI updates.
  Stream<List<GroupEntity>> watchAllGroups();

  /// Watch groups for a specific user - returns a stream that emits on changes.
  /// Used for reactive UI updates.
  Stream<List<GroupEntity>> watchUserGroups(String userId);

  /// Get all group member entities for a group (not just IDs).
  Future<List<GroupMemberEntity>> getAllGroupMembers(String groupId);

  /// Update the server timestamp for a group (used during sync).
  Future<void> updateGroupTimestamp(String id, DateTime serverTimestamp);

  /// Update the last activity timestamp for a group.
  Future<void> updateGroupActivity(String groupId);

  /// Upsert (insert or update) a group member from Firestore sync.
  /// Fires events via eventBroker to notify UI of changes.
  Future<void> upsertGroupMemberFromSync(GroupMemberEntity member, EventBroker eventBroker);

  /// Upsert (insert or update) a group from Firestore sync.
  /// Fires events via eventBroker to notify UI of changes.
  Future<void> upsertGroupFromSync(GroupEntity group, EventBroker eventBroker);

  /// Soft delete a group (marks as deleted without removal).
  /// Allows recovery and maintains referential integrity.
  Future<void> softDeleteGroup(String id);

  /// Restore a soft-deleted group.
  Future<void> restoreGroup(String id);

  /// Hard delete a group (permanent removal from database).
  Future<void> hardDeleteGroup(String id);
}

/// Interface for ExpenseSharesDao - Data access layer for expense share operations.
///
/// Manages how expenses are split between group members.
abstract class IExpenseSharesDao {
  /// Insert a new expense share (one user's portion of an expense).
  Future<void> insertExpenseShare(ExpenseShareEntity share);

  /// Get all shares for a specific expense.
  Future<List<ExpenseShareEntity>> getExpenseShares(String expenseId);

  /// Delete all shares for an expense (used when expense is deleted).
  Future<void> deleteExpenseShares(String expenseId);
}

/// Interface for UserDao - Data access layer for user operations.
///
/// Stores locally-cached user profile information.
abstract class IUserDao {
  /// Insert a new user into local cache.
  Future<void> insertUser(User user);

  /// Get a user by ID from local cache.
  /// Returns null if user not found.
  Future<User?> getUserById(String id);

  /// Update user information in local cache.
  Future<void> updateUser(User user);

  /// Delete a user from local cache.
  Future<void> deleteUser(String id);
}

/// Interface for SyncDao - Data access layer for sync queue operations.
///
/// Manages the upload queue for offline-first sync.
/// Operations are queued locally and processed when online.
abstract class ISyncDao {
  /// Enqueue an operation for upload to Firestore.
  ///
  /// [ownerId] - ID of user who owns this operation
  /// [entityType] - Type of entity (expense, group, etc.)
  /// [entityId] - ID of the entity
  /// [operationType] - Operation type (create, update, delete)
  /// [metadata] - Optional metadata (e.g., groupId for expenses)
  Future<void> enqueueOperation({
    required String ownerId,
    required String entityType,
    required String entityId,
    required String operationType,
    String? metadata,
  });

  /// Get pending operations from queue for a specific user.
  ///
  /// [ownerId] - ID of user whose operations to retrieve
  /// [limit] - Optional limit on number of operations to retrieve
  Future<List<SyncQueueData>> getPendingOperations({
    required String ownerId,
    int? limit,
  });

  /// Remove an operation from queue (after successful upload).
  Future<void> removeQueuedOperation(int id);

  /// Mark an operation as failed with error message.
  Future<void> markOperationFailed(int id, String errorMessage);

  /// Get count of pending operations for a user.
  Future<int> getPendingOperationCount(String ownerId);
}
