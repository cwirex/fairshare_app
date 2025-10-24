import 'dart:async';

import 'package:fairshare_app/core/database/app_database.dart';
import 'package:fairshare_app/core/events/event_broker_interface.dart';
import 'package:fairshare_app/core/logging/app_logger.dart';
import 'package:fairshare_app/core/monitoring/sync_metrics.dart';
import 'package:fairshare_app/core/sync/sync_service_interfaces.dart';
import 'package:fairshare_app/features/expenses/domain/entities/expense_entity.dart';
import 'package:fairshare_app/features/expenses/domain/services/remote_expense_service.dart';
import 'package:fairshare_app/features/groups/domain/entities/group_entity.dart';
import 'package:fairshare_app/features/groups/domain/services/remote_group_service.dart';

/// Manages real-time Firestore listeners for sync with hybrid strategy.
///
/// **Hybrid Listener Strategy:**
/// - **Tier 1 (Global):** Single listener for all user's groups (metadata only)
/// - **Tier 2 (Active):** Dedicated listener for currently viewed group (full real-time)
/// - **Tier 3 (On-Demand):** One-time fetch for inactive groups with new activity
///
/// This strategy minimizes Firestore listener count (1-2 max) while providing
/// premium real-time experience for the active view and smart refresh for others.
class RealtimeSyncService with LoggerMixin implements IRealtimeSyncService {
  final AppDatabase _database;
  final RemoteGroupService _groupService;
  final RemoteExpenseService _expenseService;
  final IEventBroker _eventBroker;

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
    required RemoteGroupService groupService,
    required RemoteExpenseService expenseService,
    required IEventBroker eventBroker,
  }) : _database = database,
       _groupService = groupService,
       _expenseService = expenseService,
       _eventBroker = eventBroker;

  /// Start real-time sync for user (Tier 1 - Global Listener)
  @override
  Future<void> startRealtimeSync(String userId) async {
    if (_currentUserId == userId && _globalGroupsListener != null) {
      log.d('Already syncing for user $userId');
      return;
    }

    await stopRealtimeSync();
    _currentUserId = userId;

    log.i('🔥 Starting real-time sync for user: $userId');

    // Perform initial fetch of all user data before starting listeners
    await _performInitialSync(userId);

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
  @override
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
  @override
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
  @override
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

  /// Perform initial sync of all user data (one-time fetch before listeners)
  Future<void> _performInitialSync(String userId) async {
    log.i('📦 Performing initial sync for user: $userId');

    try {
      // Fetch all groups the user is a member of
      final groupsResult = await _groupService.downloadUserGroups(userId);

      await groupsResult.fold(
        (groups) async {
          log.i('Initial sync: Found ${groups.length} groups');

          for (final group in groups) {
            try {
              // Upsert group to local DB
              await _database.groupsDao.upsertGroupFromSync(
                group,
                _eventBroker,
              );

              // Sync members for this group
              await _syncGroupMembers(group.id);

              // Fetch all expenses for this group
              await _fetchGroupExpenses(group.id);

              log.d('Initial sync completed for group: ${group.displayName}');
            } catch (e) {
              log.e('Failed to sync group ${group.id} during initial sync: $e');
            }
          }

          log.i('✅ Initial sync completed: ${groups.length} groups synced');
        },
        (error) {
          log.e('Initial sync failed: $error');
        },
      );
    } catch (e) {
      log.e('Initial sync error: $e');
    }
  }

  /// Handle groups changed (Tier 1 listener callback)
  Future<void> _onGroupsChanged(List<GroupEntity> remoteGroups) async {
    log.d('📥 Groups changed: ${remoteGroups.length} groups');

    for (final remoteGroup in remoteGroups) {
      try {
        final local = await _database.groupsDao.getGroupById(remoteGroup.id);

        // Determine if we need to fetch expenses for this group
        bool shouldFetchExpenses = false;

        if (local == null) {
          // New group - fetch expenses on first sync
          log.i('🆕 New group detected: ${remoteGroup.displayName}');
          shouldFetchExpenses = true;
        } else if (remoteGroup.lastActivityAt.isAfter(local.lastActivityAt) &&
            remoteGroup.id != _activeGroupId) {
          // Existing group with new activity - fetch expenses
          log.i('🔔 Group ${remoteGroup.displayName} has new activity');
          shouldFetchExpenses = true;
          // TODO: Emit event for UI badge
        }

        // Upsert group (bypasses queue) and fire event
        await _database.groupsDao.upsertGroupFromSync(
          remoteGroup,
          _eventBroker,
        );

        // Sync members
        await _syncGroupMembers(remoteGroup.id);

        // Fetch expenses if needed (Tier 3) - unless it's the active group
        if (shouldFetchExpenses && remoteGroup.id != _activeGroupId) {
          await _fetchGroupExpenses(remoteGroup.id);
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
        await _database.expensesDao.upsertExpenseFromSync(
          expense,
          _eventBroker,
        );
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
        await _database.groupsDao.upsertGroupMemberFromSync(
          member,
          _eventBroker,
        );
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
        await _database.expensesDao.upsertExpenseFromSync(
          expense,
          _eventBroker,
        );
        await _syncExpenseShares(groupId, expense.id);
      }
      log.i('Fetched ${expenses.length} expenses for group $groupId');
    }, (error) => log.w('Failed to fetch expenses for $groupId: $error'));
  }
}
