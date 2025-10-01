import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:result_dart/result_dart.dart';

import 'package:fairshare_app/core/database/app_database.dart';
import 'package:fairshare_app/core/logging/app_logger.dart';
import 'package:fairshare_app/core/sync/upload_queue_service.dart';
import 'package:fairshare_app/features/expenses/data/services/firestore_expense_service.dart';
import 'package:fairshare_app/features/groups/data/services/firestore_group_service.dart';

/// Service that coordinates syncing data between local database and Firestore.
/// Implements Option D: Separate Upload Queue Table strategy.
class SyncService with LoggerMixin {
  final AppDatabase _database;
  final FirestoreGroupService _groupService;
  final FirestoreExpenseService _expenseService;
  final UploadQueueService _uploadQueueService;
  final Connectivity _connectivity;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  Timer? _queueWatchTimer;
  bool _isSyncing = false;
  bool _isOnline = false;

  SyncService({
    required AppDatabase database,
    required FirestoreGroupService groupService,
    required FirestoreExpenseService expenseService,
    required UploadQueueService uploadQueueService,
    Connectivity? connectivity,
  })  : _database = database,
        _groupService = groupService,
        _expenseService = expenseService,
        _uploadQueueService = uploadQueueService,
        _connectivity = connectivity ?? Connectivity();

  /// Start monitoring connectivity and auto-sync when online.
  void startAutoSync() {
    _connectivitySubscription =
        _connectivity.onConnectivityChanged.listen((results) {
      final wasOnline = _isOnline;
      _isOnline = results.any((result) => result != ConnectivityResult.none);

      if (_isOnline && !wasOnline) {
        // Just came online
        log.i('Device came online, triggering sync...');
        syncAll();
      }

      // Start/stop queue watching based on connectivity
      if (_isOnline) {
        _startQueueWatcher();
      } else {
        _stopQueueWatcher();
      }
    });

    // Initial sync check
    _checkConnectivityAndSync();
  }

  /// Stop auto-sync monitoring.
  void stopAutoSync() {
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
    _stopQueueWatcher();
  }

  /// Start watching the queue for new operations (when online)
  void _startQueueWatcher() {
    if (_queueWatchTimer != null) return; // Already watching

    log.d('Starting queue watcher...');
    _queueWatchTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      if (!_isOnline) {
        _stopQueueWatcher();
        return;
      }

      final pendingCount = await _uploadQueueService.getPendingCount();
      if (pendingCount > 0) {
        log.d('Queue watcher found $pendingCount pending operations');
        await syncAll();
      }
    });
  }

  /// Stop watching the queue
  void _stopQueueWatcher() {
    _queueWatchTimer?.cancel();
    _queueWatchTimer = null;
    log.d('Stopped queue watcher');
  }

  Future<void> _checkConnectivityAndSync() async {
    final results = await _connectivity.checkConnectivity();
    _isOnline = results.any((result) => result != ConnectivityResult.none);

    if (_isOnline) {
      await syncAll();
      _startQueueWatcher();
    }
  }

  /// Sync all unsynced data to Firestore (bidirectional).
  ///
  /// Process order:
  /// 1. Upload: Process local changes from upload queue → Firestore
  /// 2. Download: Fetch remote changes from Firestore → Local DB
  ///
  /// This ensures local changes are pushed before pulling remote changes,
  /// minimizing conflicts with Last Write Wins strategy.
  Future<Result<void>> syncAll() async {
    if (_isSyncing) {
      log.d('Sync already in progress, skipping...');
      return Success.unit();
    }

    _isSyncing = true;
    log.i('Starting bidirectional sync...');

    try {
      // PHASE 1: Upload local changes to Firestore
      final pendingCount = await _uploadQueueService.getPendingCount();
      if (pendingCount > 0) {
        log.i('Processing $pendingCount pending operations from upload queue...');
        final result = await _uploadQueueService.processQueue();
        log.i(
            'Upload queue processed: ${result.successCount} succeeded, ${result.failureCount} failed');
      }

      // PHASE 2: Download remote changes from Firestore
      // Note: We use upsertFromSync methods which bypass the upload queue
      // and implement Last Write Wins conflict resolution
      await _downloadRemoteChanges();

      log.i('Full sync completed successfully');
      return Success.unit();
    } catch (e) {
      log.e('Sync failed: $e');
      return Failure(Exception('Sync failed: $e'));
    } finally {
      _isSyncing = false;
    }
  }


  /// Download remote changes from Firestore (internal method for bidirectional sync)
  Future<void> _downloadRemoteChanges() async {
    // TODO: Get current user ID from auth state
    // For now, this method is a placeholder
    // In a real implementation, you'd:
    // 1. Get the current user's ID
    // 2. Download their groups using _groupService.downloadUserGroups(userId)
    // 3. For each group, download expenses using _expenseService.downloadGroupExpenses(groupId)
    // 4. Use upsertGroupFromSync() and upsertExpenseFromSync() to apply changes
    log.d('Downloading remote changes (not yet fully implemented)');
  }

  /// Download user's groups from Firestore and merge with local database.
  Future<Result<void>> downloadUserGroups(String userId) async {
    try {
      log.i('Downloading groups for user: $userId');
      final result = await _groupService.downloadUserGroups(userId);

      return result.fold(
        (groups) async {
          for (final group in groups) {
            // Use upsertGroupFromSync to bypass upload queue
            await _database.upsertGroupFromSync(group);
            log.d('Synced group from server: ${group.id}');

            // Download members for this group
            final membersResult =
                await _groupService.downloadGroupMembers(group.id);
            await membersResult.fold(
              (members) async {
                for (final member in members) {
                  // Members don't trigger queue, safe to use directly
                  await _database.addGroupMember(member);
                }
              },
              (_) async {},
            );
          }

          return Success.unit();
        },
        (error) => Failure(error),
      );
    } catch (e) {
      log.e('Error downloading user groups: $e');
      return Failure(Exception('Failed to download user groups: $e'));
    }
  }

  /// Download group's expenses from Firestore and merge with local database.
  Future<Result<void>> downloadGroupExpenses(String groupId) async {
    try {
      log.i('Downloading expenses for group: $groupId');
      final result = await _expenseService.downloadGroupExpenses(groupId);

      return result.fold(
        (expenses) async {
          for (final expense in expenses) {
            // Use upsertExpenseFromSync to bypass upload queue
            await _database.upsertExpenseFromSync(expense);
            log.d('Synced expense from server: ${expense.id}');

            // Download shares for this expense
            final sharesResult =
                await _expenseService.downloadExpenseShares(expense.groupId, expense.id);
            await sharesResult.fold(
              (shares) async {
                for (final share in shares) {
                  // Shares don't trigger queue, safe to use directly
                  await _database.insertExpenseShare(share);
                }
              },
              (_) async {},
            );
          }

          return Success.unit();
        },
        (error) => Failure(error),
      );
    } catch (e) {
      log.e('Error downloading group expenses: $e');
      return Failure(Exception('Failed to download group expenses: $e'));
    }
  }

  /// Dispose resources.
  void dispose() {
    stopAutoSync();
  }
}
