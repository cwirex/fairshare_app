import 'package:fairshare_app/core/events/app_event.dart';

/// Event fired when an item is added to the upload queue.
/// This is a domain-agnostic sync event that triggers queue processing.
class UploadQueueItemAdded extends AppEvent {
  final String? message;

  UploadQueueItemAdded(this.message);

  @override
  String toString() => 'UploadQueueItemAdded($message)';
}

/// Event fired when sync queue is processed.
class SyncQueueProcessed extends AppEvent {
  final int successCount;
  final int failureCount;

  SyncQueueProcessed({required this.successCount, required this.failureCount});

  @override
  String toString() =>
      'SyncQueueProcessed(success: $successCount, failed: $failureCount)';
}

/// Event fired when realtime sync connects/disconnects.
class SyncStatusChanged extends AppEvent {
  final bool isConnected;

  SyncStatusChanged(this.isConnected);

  @override
  String toString() =>
      'SyncStatusChanged(${isConnected ? "connected" : "disconnected"})';
}
