// lib/features/auth/presentation/providers/sync_status_providers.dart
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:result_dart/result_dart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/logging/app_logger.dart';
import '../../data/services/firebase_auth_service.dart';
import 'auth_providers.dart';

part 'sync_status_providers.g.dart';

/// Provider for detailed sync status information
@riverpod
Future<SyncStatusInfo> syncStatus(SyncStatusRef ref) async {
  final authRepo = ref.watch(authRepositoryProvider);

  // Cast to FirebaseAuthService to access enhanced methods
  if (authRepo is FirebaseAuthService) {
    final result = await authRepo.getSyncStatus();
    return result.fold((syncStatus) => syncStatus, (error) {
      // Log error and return empty sync status
      final logger = ref.read(appLoggerProvider);
      logger.e('Failed to get sync status: $error');
      return SyncStatusInfo(
        unsyncedUsers: 0,
        unsyncedGroups: 0,
        unsyncedExpenses: 0,
        unsyncedGroupMembers: 0,
        unsyncedExpenseShares: 0,
      );
    });
  }

  // Fallback for other auth repository implementations
  return SyncStatusInfo(
    unsyncedUsers: 0,
    unsyncedGroups: 0,
    unsyncedExpenses: 0,
    unsyncedGroupMembers: 0,
    unsyncedExpenseShares: 0,
  );
}

/// Provider for sync status that updates automatically
@riverpod
class SyncStatusNotifier extends _$SyncStatusNotifier {
  Timer? _timer;

  @override
  Future<SyncStatusInfo> build() async {
    // Cancel existing timer if any
    _timer?.cancel();

    // Refresh sync status every 30 seconds
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      ref.invalidateSelf();
    });

    ref.onDispose(() {
      _timer?.cancel();
      _timer = null;
    });

    return ref.watch(syncStatusProvider.future);
  }

  /// Force refresh sync status
  void refresh() {
    ref.invalidateSelf();
  }

  /// Attempt to sync all unsynced data
  Future<Result<void>> forceSyncAll() async {
    final authRepo = ref.read(authRepositoryProvider);
    final logger = ref.read(appLoggerProvider);

    logger.i('🔄 Starting forced sync of all data...');

    if (authRepo is FirebaseAuthService) {
      final result = await authRepo.forceSyncAll();

      return result.fold(
        (success) {
          logger.i('✅ Forced sync completed successfully');
          // Refresh sync status after successful sync
          refresh();
          return Success.unit();
        },
        (error) {
          logger.e('❌ Forced sync failed: $error');
          return Failure(error);
        },
      );
    }

    return Failure(Exception('Sync not supported by current auth provider'));
  }
}

/// Convenience providers for specific sync status checks

/// Whether there's any unsynced data
@riverpod
Future<bool> hasUnsyncedData(Ref ref) async {
  final syncStatus = await ref.watch(syncStatusProvider.future);
  return syncStatus.hasUnsyncedData;
}

/// Total count of unsynced items
@riverpod
Future<int> totalUnsyncedItems(Ref ref) async {
  final syncStatus = await ref.watch(syncStatusProvider.future);
  return syncStatus.totalUnsyncedItems;
}

/// List of unsynced item descriptions for UI
@riverpod
Future<List<String>> unsyncedItemDescriptions(Ref ref) async {
  final syncStatus = await ref.watch(syncStatusProvider.future);
  return syncStatus.unsyncedItemDescriptions;
}

/// Whether sync is currently in progress
@riverpod
class SyncInProgress extends _$SyncInProgress {
  @override
  bool build() => false;

  void setSyncing(bool syncing) {
    state = syncing;
  }
}

/// Convenience provider to check if sync is available
@riverpod
bool isSyncAvailable(Ref ref) {
  final authRepo = ref.watch(authRepositoryProvider);
  return authRepo is FirebaseAuthService;
}

/// Provider for last sync time (placeholder for future implementation)
@riverpod
DateTime? lastSyncTime(Ref ref) {
  // TODO: Implement actual last sync time tracking
  // This would come from database or shared preferences
  return DateTime.now().subtract(const Duration(minutes: 15));
}

/// Sync status summary for UI display
@riverpod
Future<SyncStatusSummary> syncStatusSummary(Ref ref) async {
  final syncStatus = await ref.watch(syncStatusProvider.future);
  final lastSync = ref.watch(lastSyncTimeProvider);
  final hasUnsynced = await ref.watch(hasUnsyncedDataProvider.future);
  final isAvailable = ref.watch(isSyncAvailableProvider);

  return SyncStatusSummary(
    syncStatus: syncStatus,
    lastSyncTime: lastSync,
    hasUnsyncedData: hasUnsynced,
    isSyncAvailable: isAvailable,
  );
}

/// Summary class for sync status UI display
class SyncStatusSummary {
  final SyncStatusInfo syncStatus;
  final DateTime? lastSyncTime;
  final bool hasUnsyncedData;
  final bool isSyncAvailable;

  SyncStatusSummary({
    required this.syncStatus,
    required this.lastSyncTime,
    required this.hasUnsyncedData,
    required this.isSyncAvailable,
  });

  String get statusText {
    if (!isSyncAvailable) return 'Sync not available';
    if (hasUnsyncedData) return 'Sync needed';
    return 'All synced';
  }

  String get detailText {
    if (!isSyncAvailable) return 'Enable sync in settings';
    if (hasUnsyncedData) {
      final total = syncStatus.totalUnsyncedItems;
      return '$total item${total == 1 ? '' : 's'} need syncing';
    }
    if (lastSyncTime != null) {
      final duration = DateTime.now().difference(lastSyncTime!);
      if (duration.inMinutes < 1) return 'Synced just now';
      if (duration.inHours < 1) return 'Synced ${duration.inMinutes}m ago';
      if (duration.inDays < 1) return 'Synced ${duration.inHours}h ago';
      return 'Synced ${duration.inDays}d ago';
    }
    return 'Last sync unknown';
  }
}
