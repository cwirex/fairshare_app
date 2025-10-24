import 'package:fairshare_app/core/database/app_database.dart';
import 'package:fairshare_app/core/events/event_broker.dart';
import 'package:fairshare_app/features/auth/domain/entities/user.dart';
import 'package:fairshare_app/features/expenses/domain/entities/expense_entity.dart';
import 'package:fairshare_app/features/expenses/domain/entities/expense_share_entity.dart';
import 'package:fairshare_app/features/groups/domain/entities/group_entity.dart';
import 'package:fairshare_app/features/groups/domain/entities/group_member_entity.dart';

/// Interface for ExpensesDao
abstract class IExpensesDao {
  Future<void> insertExpense(ExpenseEntity expense);
  Future<ExpenseEntity?> getExpenseById(String id, {bool includeDeleted = false});
  Future<List<ExpenseEntity>> getExpensesByGroup(String groupId);
  Future<List<ExpenseEntity>> getAllExpenses();
  Future<void> updateExpenseTimestamp(String id, DateTime serverTimestamp);
  Future<void> updateExpense(ExpenseEntity expense);
  Future<void> deleteExpense(String id);
  Stream<List<ExpenseEntity>> watchExpensesByGroup(String groupId);
  Stream<List<ExpenseEntity>> watchAllExpenses();
  Future<void> upsertExpenseFromSync(ExpenseEntity expense, EventBroker eventBroker);
  Future<void> softDeleteExpense(String id);
  Future<void> restoreExpense(String id);
  Future<void> hardDeleteExpense(String id);
}

/// Interface for GroupsDao
abstract class IGroupsDao {
  Future<void> insertGroup(GroupEntity group);
  Future<GroupEntity?> getGroupById(String id, {bool includeDeleted = false});
  Future<List<GroupEntity>> getAllGroups();
  Future<void> updateGroup(GroupEntity group);
  Future<void> deleteGroup(String id);
  Future<void> addGroupMember(GroupMemberEntity member);
  Future<void> removeGroupMember(String groupId, String userId);
  Future<List<String>> getGroupMembers(String groupId);
  Future<List<GroupEntity>> getUserGroups(String userId);
  Stream<List<GroupEntity>> watchAllGroups();
  Stream<List<GroupEntity>> watchUserGroups(String userId);
  Future<List<GroupMemberEntity>> getAllGroupMembers(String groupId);
  Future<void> updateGroupTimestamp(String id, DateTime serverTimestamp);
  Future<void> updateGroupActivity(String groupId);
  Future<void> upsertGroupMemberFromSync(GroupMemberEntity member, EventBroker eventBroker);
  Future<void> upsertGroupFromSync(GroupEntity group, EventBroker eventBroker);
  Future<void> softDeleteGroup(String id);
  Future<void> restoreGroup(String id);
  Future<void> hardDeleteGroup(String id);
}

/// Interface for ExpenseSharesDao
abstract class IExpenseSharesDao {
  Future<void> insertExpenseShare(ExpenseShareEntity share);
  Future<List<ExpenseShareEntity>> getExpenseShares(String expenseId);
  Future<void> deleteExpenseShares(String expenseId);
}

/// Interface for UserDao
abstract class IUserDao {
  Future<void> insertUser(User user);
  Future<User?> getUserById(String id);
  Future<void> updateUser(User user);
  Future<void> deleteUser(String id);
}

/// Interface for SyncDao
abstract class ISyncDao {
  Future<void> enqueueOperation({
    required String ownerId,
    required String entityType,
    required String entityId,
    required String operationType,
    String? metadata,
  });
  Future<List<SyncQueueData>> getPendingOperations({
    required String ownerId,
    int? limit,
  });
  Future<void> removeQueuedOperation(int id);
  Future<void> markOperationFailed(int id, String errorMessage);
  Future<int> getPendingOperationCount(String ownerId);
}
