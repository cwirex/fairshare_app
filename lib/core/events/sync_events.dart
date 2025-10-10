import 'package:fairshare_app/core/events/app_event.dart';

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
