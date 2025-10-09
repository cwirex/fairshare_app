import 'dart:async';

import 'package:fairshare_app/core/database/app_database.dart';
import 'package:fairshare_app/core/logging/app_logger.dart';
import 'package:fairshare_app/core/monitoring/sync_metrics.dart';
import 'package:fairshare_app/features/expenses/data/services/firestore_expense_service.dart';
import 'package:fairshare_app/features/expenses/domain/entities/expense_entity.dart';
import 'package:fairshare_app/features/groups/data/services/firestore_group_service.dart';
import 'package:fairshare_app/features/groups/domain/entities/group_entity.dart';

/// Manages real-time Firestore listeners for sync with hybrid strategy.
///
/// **Hybrid Listener Strategy:**
/// - **Tier 1 (Global):** Single listener for all user's groups (metadata only)
/// - **Tier 2 (Active):** Dedicated listener for currently viewed group (full real-time)
/// - **Tier 3 (On-Demand):** One-time fetch for inactive groups with new activity
///
/// This strategy minimizes Firestore listener count (1-2 max) while providing
/// premium real-time experience for the active view and smart refresh for others.
class RealtimeSyncService with LoggerMixin {
  final AppDatabase _database;
  final FirestoreGroupService _groupService;
  final FirestoreExpenseService _expenseService;

  String? _currentUserId;

  // Tier 1: Global listener for all groups
  StreamSubscription? _globalGroupsListener;

  // Tier 2: Active group listener
  StreamSubscription? _activeGroupExpensesListener;
  String? _activeGroupId;

  // Tier 3: Track groups with new activity
  final Set<String> _groupsNeedingRefresh = {};

  RealtimeSyncService({
    required AppDatabase database,
    required FirestoreGroupService groupService,
    required FirestoreExpenseService expenseService,
  }) : _database = database,
       _groupService = groupService,
       _expenseService = expenseService;

  /// Start real-time sync for user (Tier 1 - Global Listener)
  Future<void> startRealtimeSync(String userId) async {
    if (_currentUserId == userId && _globalGroupsListener != null) {
      log.d('Already syncing for user $userId');
      return;
    }

    await stopRealtimeSync();
    _currentUserId = userId;

    log.i('🔥 Starting real-time sync for user: $userId');

    _globalGroupsListener = _groupService
        .watchUserGroups(userId)
        .listen(
          _onGroupsChanged,
          onError: (e) {
            log.e('Groups listener error: $e');
            SyncMetrics.instance.recordSyncError('groups_listener');
          },
        );

    SyncMetrics.instance.recordListenerStarted();
  }

  /// Stop all listeners
  Future<void> stopRealtimeSync() async {
    if (_currentUserId == null) return;

    log.i('🛑 Stopping real-time sync');

    await _globalGroupsListener?.cancel();
    await _activeGroupExpensesListener?.cancel();

    if (_globalGroupsListener != null) {
      SyncMetrics.instance.recordListenerStopped();
    }
    if (_activeGroupExpensesListener != null) {
      SyncMetrics.instance.recordListenerStopped();
    }

    _globalGroupsListener = null;
    _activeGroupExpensesListener = null;
    _currentUserId = null;
    _activeGroupId = null;
  }

  /// Start listening to specific group (Tier 2 - Active Group Listener)
  void listenToActiveGroup(String groupId) {
    if (_activeGroupId == groupId && _activeGroupExpensesListener != null) {
      log.d('Already listening to group $groupId');
      return;
    }

    log.i('👁️ Activating real-time listener for group: $groupId');

    // Cancel previous listener
    _activeGroupExpensesListener?.cancel();
    if (_activeGroupExpensesListener != null) {
      SyncMetrics.instance.recordListenerStopped();
    }

    _activeGroupId = groupId;

    _activeGroupExpensesListener = _expenseService
        .watchGroupExpenses(groupId)
        .listen(
          (expenses) => _onExpensesChanged(groupId, expenses),
          onError: (e) {
            log.e('Expenses listener error for group $groupId: $e');
            SyncMetrics.instance.recordSyncError('expenses_listener');
          },
        );

    SyncMetrics.instance.recordListenerStarted();

    // Remove from refresh queue since we're now actively listening
    _groupsNeedingRefresh.remove(groupId);
  }

  /// Stop listening to active group
  void stopListeningToActiveGroup() {
    if (_activeGroupExpensesListener == null) return;

    log.i('⏸️ Deactivating group listener for: $_activeGroupId');

    _activeGroupExpensesListener?.cancel();
    if (_activeGroupExpensesListener != null) {
      SyncMetrics.instance.recordListenerStopped();
    }

    _activeGroupExpensesListener = null;
    _activeGroupId = null;
  }

  /// Handle groups changed (Tier 1 listener callback)
  Future<void> _onGroupsChanged(List<GroupEntity> remoteGroups) async {
    log.d('📥 Groups changed: ${remoteGroups.length} groups');

    for (final remoteGroup in remoteGroups) {
      try {
        final local = await _database.groupsDao.getGroupById(remoteGroup.id);

        // Check if lastActivityAt changed for inactive groups (Tier 3 detection)
        if (local != null &&
            remoteGroup.lastActivityAt.isAfter(local.lastActivityAt) &&
            remoteGroup.id != _activeGroupId) {
          log.i('🔔 Group ${remoteGroup.displayName} has new activity');
          _groupsNeedingRefresh.add(remoteGroup.id);
          // TODO: Emit event for UI badge
        }

        // Upsert group (bypasses queue)
        await _database.groupsDao.upsertGroupFromSync(remoteGroup);

        // Sync members
        await _syncGroupMembers(remoteGroup.id);

        // If this group needs refresh and it's not active, fetch expenses (Tier 3)
        if (_groupsNeedingRefresh.contains(remoteGroup.id) &&
            remoteGroup.id != _activeGroupId) {
          await _fetchGroupExpenses(remoteGroup.id);
          _groupsNeedingRefresh.remove(remoteGroup.id);
        }

        SyncMetrics.instance.recordSyncSuccess();
      } catch (e) {
        log.e('Failed to process group ${remoteGroup.id}: $e');
        SyncMetrics.instance.recordSyncError('group_processing');
      }
    }
  }

  /// Handle expenses changed (Tier 2 listener callback)
  Future<void> _onExpensesChanged(
    String groupId,
    List<ExpenseEntity> remoteExpenses,
  ) async {
    log.d('📥 Expenses changed for group $groupId: ${remoteExpenses.length}');

    for (final expense in remoteExpenses) {
      try {
        await _database.expensesDao.upsertExpenseFromSync(expense);
        await _syncExpenseShares(groupId, expense.id);
        SyncMetrics.instance.recordSyncSuccess();
      } catch (e) {
        log.e('Failed to process expense ${expense.id}: $e');
        SyncMetrics.instance.recordSyncError('expense_processing');
      }
    }
  }

  /// Sync group members
  Future<void> _syncGroupMembers(String groupId) async {
    final result = await _groupService.downloadGroupMembers(groupId);
    result.fold((members) async {
      for (final member in members) {
        await _database.groupsDao.upsertGroupMemberFromSync(member);
      }
      log.d('Synced ${members.length} members for group $groupId');
    }, (error) => log.w('Failed to sync members for $groupId: $error'));
  }

  /// Sync expense shares
  Future<void> _syncExpenseShares(String groupId, String expenseId) async {
    final result = await _expenseService.downloadExpenseShares(
      groupId,
      expenseId,
    );
    result.fold((shares) async {
      // Delete existing shares and insert new ones to ensure consistency
      _database.expenseSharesDao.deleteExpenseShares(expenseId);
      for (final share in shares) {
        await _database.expenseSharesDao.insertExpenseShare(share);
      }
      log.d('Synced ${shares.length} shares for expense $expenseId');
    }, (error) => log.w('Failed to sync shares for $expenseId: $error'));
  }

  /// Tier 3: One-time fetch for inactive group with new activity
  Future<void> _fetchGroupExpenses(String groupId) async {
    log.i('📦 Fetching expenses for inactive group: $groupId');
    final result = await _expenseService.downloadGroupExpenses(groupId);
    result.fold((expenses) async {
      for (final expense in expenses) {
        await _database.expensesDao.upsertExpenseFromSync(expense);
        await _syncExpenseShares(groupId, expense.id);
      }
      log.i('Fetched ${expenses.length} expenses for group $groupId');
    }, (error) => log.w('Failed to fetch expenses for $groupId: $error'));
  }

  /// Get current listener status (for debugging)
  Map<String, dynamic> getStatus() {
    return {
      'userId': _currentUserId,
      'globalListenerActive': _globalGroupsListener != null,
      'activeGroupId': _activeGroupId,
      'activeGroupListenerActive': _activeGroupExpensesListener != null,
      'groupsNeedingRefresh': _groupsNeedingRefresh.length,
    };
  }
}
