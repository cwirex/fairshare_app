import 'dart:async';

import 'package:result_dart/result_dart.dart';

/// Interface for the main sync orchestration service.
///
/// Coordinates syncing data between local database and Firestore,
/// managing connectivity, app lifecycle, and event-driven sync triggers.
abstract class ISyncService {
  /// Start auto-sync monitoring for the given user
  void startAutoSync(String? userId);

  /// Stop all sync operations
  void stopAutoSync();

  /// Manually trigger a full sync for the user
  Future<Result<void>> syncAll(String userId);

  /// Get count of pending upload operations
  Future<int> getPendingUploadCount();

  /// Dispose resources and clean up
  void dispose();
}

/// Interface for the upload queue processing service.
///
/// Processes queued local changes and uploads them to Firestore.
/// User-scoped: Only processes operations for the specified owner.
abstract class IUploadQueueService {
  /// Process all pending operations in the queue for this user
  Future<UploadQueueResult> processQueue();

  /// Get count of pending operations for this user
  Future<int> getPendingCount();
}

/// Interface for the real-time sync service.
///
/// Manages Firestore listeners for downloading remote changes to local database.
/// Uses hybrid listener strategy (global + active group) to minimize Firestore costs.
abstract class IRealtimeSyncService {
  /// Start real-time sync for user (Tier 1 - Global Listener)
  Future<void> startRealtimeSync(String userId);

  /// Stop all listeners
  Future<void> stopRealtimeSync();

  /// Start listening to specific group (Tier 2 - Active Group Listener)
  void listenToActiveGroup(String groupId);

  /// Stop listening to the active group
  void stopListeningToActiveGroup();
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
