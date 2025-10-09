import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:fairshare_app/core/database/app_database.dart';
import 'package:fairshare_app/core/logging/app_logger.dart';
import 'package:fairshare_app/core/sync/upload_queue_service.dart';
import 'package:fairshare_app/features/expenses/data/services/firestore_expense_service.dart';
import 'package:fairshare_app/features/groups/data/services/firestore_group_service.dart';
import 'package:result_dart/result_dart.dart';

/// Service that coordinates syncing data between local database and Firestore.
/// Separate Upload Queue Table strategy.
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
  }) : _database = database,
       _groupService = groupService,
       _expenseService = expenseService,
       _uploadQueueService = uploadQueueService,
       _connectivity = connectivity ?? Connectivity();

  /// Start monitoring connectivity and auto-sync when online.
  /// Note: This will be called with userId from the provider
  void startAutoSync(String? userId) {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((
      results,
    ) {
      final wasOnline = _isOnline;
      _isOnline = results.any((result) => result != ConnectivityResult.none);

      if (_isOnline && !wasOnline && userId != null) {
        // Just came online
        log.i('Device came online, triggering sync...');
        syncAll(userId);
      }

      // Start/stop queue watching based on connectivity
      if (_isOnline) {
        _startQueueWatcher(userId);
      } else {
        _stopQueueWatcher();
      }
    });

    // Initial sync check
    if (userId != null) {
      _checkConnectivityAndSync(userId);
    }
  }

  /// Stop auto-sync monitoring.
  void stopAutoSync() {
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
    _stopQueueWatcher();
  }

  /// Start watching the queue for new operations (when online)
  void _startQueueWatcher(String? userId) {
    if (_queueWatchTimer != null) return; // Already watching
    if (userId == null) return;

    log.d('Starting queue watcher...');
    _queueWatchTimer = Timer.periodic(const Duration(seconds: 30), (
      timer,
    ) async {
      if (!_isOnline) {
        _stopQueueWatcher();
        return;
      }

      final pendingCount = await _uploadQueueService.getPendingCount();
      if (pendingCount > 0) {
        log.d('Queue watcher found $pendingCount pending operations');
        await syncAll(userId);
      }
    });
  }

  /// Stop watching the queue
  void _stopQueueWatcher() {
    _queueWatchTimer?.cancel();
    _queueWatchTimer = null;
    log.d('Stopped queue watcher');
  }

  Future<void> _checkConnectivityAndSync(String userId) async {
    final results = await _connectivity.checkConnectivity();
    _isOnline = results.any((result) => result != ConnectivityResult.none);

    if (_isOnline) {
      await syncAll(userId);
      _startQueueWatcher(userId);
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
  Future<Result<void>> syncAll(String userId) async {
    if (_isSyncing) {
      log.d('Sync already in progress, skipping...');
      return Success.unit();
    }

    _isSyncing = true;
    log.i('Starting bidirectional sync for user: $userId...');

    try {
      // PHASE 0: Enqueue any unsynced local data (migration support)
      await _enqueueUnsyncedData(userId);

      // PHASE 1: Upload local changes to Firestore
      final pendingCount = await _uploadQueueService.getPendingCount();
      log.i('Upload queue has $pendingCount pending operations');

      if (pendingCount > 0) {
        log.i(
          'Processing $pendingCount pending operations from upload queue...',
        );
        final result = await _uploadQueueService.processQueue();
        log.i(
          'Upload queue processed: ${result.successCount} succeeded, ${result.failureCount} failed',
        );
      } else {
        log.d('Upload queue is empty, skipping upload phase');
      }

      // PHASE 2: Download remote changes from Firestore
      // Note: We use upsertFromSync methods which bypass the upload queue
      // and implement Last Write Wins conflict resolution
      await _downloadRemoteChanges(userId);

      // PHASE 3: Verify data consistency
      await _verifyDataConsistency(userId);

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
  Future<void> _downloadRemoteChanges(String userId) async {
    log.i('Downloading remote changes for user: $userId');

    try {
      // Download user's groups
      final groupsResult = _groupService.downloadUserGroups(userId);

      await groupsResult.fold((groups) async {
        log.d('Downloaded ${groups.length} groups from Firestore');

        for (final group in groups) {
          // Use upsertGroupFromSync to bypass upload queue and handle conflicts
          await _database.upsertGroupFromSync(group);

          // Download members for this group
          final membersResult = _groupService.downloadGroupMembers(group.id);
          await membersResult.fold(
            (members) async {
              for (final member in members) {
                // Check if member already exists to avoid duplicates
                final existingMembers = await _database.getGroupMembers(
                  group.id,
                );
                if (!existingMembers.contains(member.userId)) {
                  await _database.addGroupMember(member);
                }
              }
            },
            (error) => log.w(
              'Failed to download members for group ${group.id}: $error',
            ),
          );

          // Download expenses for this group
          final expensesResult = _expenseService.downloadGroupExpenses(
            group.id,
          );
          await expensesResult.fold(
            (expenses) async {
              log.d(
                'Downloaded ${expenses.length} expenses for group ${group.id}',
              );

              for (final expense in expenses) {
                // Use upsertExpenseFromSync to bypass upload queue and handle conflicts
                await _database.upsertExpenseFromSync(expense);

                // Download shares for this expense
                final sharesResult = _expenseService.downloadExpenseShares(
                  group.id,
                  expense.id,
                );
                await sharesResult.fold(
                  (shares) async {
                    // Delete existing shares and insert new ones to ensure consistency
                    await _database.deleteExpenseShares(expense.id);
                    for (final share in shares) {
                      await _database.insertExpenseShare(share);
                    }
                  },
                  (error) => log.w(
                    'Failed to download shares for expense ${expense.id}: $error',
                  ),
                );
              }
            },
            (error) => log.w(
              'Failed to download expenses for group ${group.id}: $error',
            ),
          );
        }
      }, (error) => log.e('Failed to download groups: $error'));

      log.i('Remote changes download completed');
    } catch (e) {
      log.e('Error during remote changes download: $e');
      rethrow;
    }
  }

  /// Download user's groups from Firestore and merge with local database.
  Future<Result<void>> downloadUserGroups(String userId) async {
    try {
      log.i('Downloading groups for user: $userId');
      final result = await _groupService.downloadUserGroups(userId);

      return result.fold((groups) async {
        for (final group in groups) {
          // Use upsertGroupFromSync to bypass upload queue
          await _database.upsertGroupFromSync(group);
          log.d('Synced group from server: ${group.id}');

          // Download members for this group
          final membersResult = await _groupService.downloadGroupMembers(
            group.id,
          );
          await membersResult.fold((members) async {
            for (final member in members) {
              // Members don't trigger queue, safe to use directly
              await _database.addGroupMember(member);
            }
          }, (_) async {});
        }

        return Success.unit();
      }, (error) => Failure(error));
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

      return result.fold((expenses) async {
        for (final expense in expenses) {
          // Use upsertExpenseFromSync to bypass upload queue
          await _database.upsertExpenseFromSync(expense);
          log.d('Synced expense from server: ${expense.id}');

          // Download shares for this expense
          final sharesResult = await _expenseService.downloadExpenseShares(
            expense.groupId,
            expense.id,
          );
          await sharesResult.fold((shares) async {
            for (final share in shares) {
              // Shares don't trigger queue, safe to use directly
              await _database.insertExpenseShare(share);
            }
          }, (_) async {});
        }

        return Success.unit();
      }, (error) => Failure(error));
    } catch (e) {
      log.e('Error downloading group expenses: $e');
      return Failure(Exception('Failed to download group expenses: $e'));
    }
  }

  /// Enqueue unsynced local data (for migration and recovery)
  Future<void> _enqueueUnsyncedData(String userId) async {
    log.i('🔄 Checking for unsynced local data to enqueue...');

    try {
      // Get all user's groups from local DB
      final localGroups = await _database.getUserGroups(userId);

      for (final group in localGroups) {
        // Enqueue group
        await _database.enqueueOperation(
          entityType: 'group',
          entityId: group.id,
          operationType: 'create',
        );

        // Enqueue members
        final members = await _database.getAllGroupMembers(group.id);
        for (final member in members) {
          await _database.enqueueOperation(
            entityType: 'group_member',
            entityId: '${member.groupId}_${member.userId}',
            operationType: 'create',
            metadata: member.groupId,
          );
        }

        // Enqueue expenses
        final expenses = await _database.getExpensesByGroup(group.id);
        for (final expense in expenses) {
          await _database.enqueueOperation(
            entityType: 'expense',
            entityId: expense.id,
            operationType: 'create',
            metadata: expense.groupId,
          );
        }
      }

      log.i('✅ Finished enqueueing unsynced data');
    } catch (e) {
      log.e('Failed to enqueue unsynced data: $e');
    }
  }

  /// Verify data consistency between Firestore and Local DB
  Future<void> _verifyDataConsistency(String userId) async {
    log.i('🔍 Verifying data consistency...');

    try {
      // Get local groups
      final localGroups = await _database.getUserGroups(userId);
      log.i('📱 Local DB has ${localGroups.length} groups');

      // Get Firestore groups
      final firestoreResult = _groupService.downloadUserGroups(userId);
      await firestoreResult.fold((firestoreGroups) async {
        log.i('☁️ Firestore has ${firestoreGroups.length} groups');

        // Compare groups
        for (final localGroup in localGroups) {
          final firestoreGroup = firestoreGroups.firstWhere(
            (g) => g.id == localGroup.id,
            orElse: () => localGroup, // Fallback to local if not found
          );

          if (firestoreGroup.id == localGroup.id) {
            log.d(
              '✅ Group ${localGroup.displayName} (${localGroup.id}): synced',
            );

            // Check members
            final localMembers = await _database.getGroupMembers(localGroup.id);
            final firestoreMembersResult = _groupService.downloadGroupMembers(
              localGroup.id,
            );

            await firestoreMembersResult.fold((firestoreMembers) async {
              log.d(
                '   Members: Local=${localMembers.length}, Firestore=${firestoreMembers.length}',
              );

              // Check expenses
              final localExpenses = await _database.getExpensesByGroup(
                localGroup.id,
              );
              final firestoreExpensesResult = _expenseService
                  .downloadGroupExpenses(localGroup.id);

              await firestoreExpensesResult.fold((firestoreExpenses) {
                log.d(
                  '   Expenses: Local=${localExpenses.length}, Firestore=${firestoreExpenses.length}',
                );
              }, (error) => log.w('   Failed to get Firestore expenses: $error'));
            }, (error) => log.w('   Failed to get Firestore members: $error'));
          } else {
            log.w(
              '⚠️ Group ${localGroup.displayName} (${localGroup.id}): NOT in Firestore',
            );
          }
        }

        // Check for Firestore groups not in local
        for (final firestoreGroup in firestoreGroups) {
          final localGroup = localGroups.firstWhere(
            (g) => g.id == firestoreGroup.id,
            orElse: () => firestoreGroup,
          );

          if (localGroup.id != firestoreGroup.id) {
            log.w(
              '⚠️ Group ${firestoreGroup.displayName} (${firestoreGroup.id}): In Firestore but NOT in Local DB',
            );
          }
        }
      }, (error) => log.e('Failed to verify Firestore data: $error'));

      log.i('🔍 Data verification completed');
    } catch (e) {
      log.e('Data verification failed: $e');
    }
  }

  /// Dispose resources.
  void dispose() {
    stopAutoSync();
  }
}
