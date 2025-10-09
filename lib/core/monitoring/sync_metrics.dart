import 'package:fairshare_app/core/logging/app_logger.dart';

/// Tracks sync performance metrics for monitoring and debugging
class SyncMetrics with LoggerMixin {
  static final SyncMetrics instance = SyncMetrics._();
  SyncMetrics._();

  int _activeListenerCount = 0;
  int _queueDepth = 0;
  DateTime? _lastSyncTime;
  int _syncSuccessCount = 0;
  int _syncErrorCount = 0;
  final Map<String, int> _errorsByType = {};

  /// Record that a listener was started
  void recordListenerStarted() {
    _activeListenerCount++;
    log.d('Listener started. Active: $_activeListenerCount');
  }

  /// Record that a listener was stopped
  void recordListenerStopped() {
    if (_activeListenerCount > 0) {
      _activeListenerCount--;
    }
    log.d('Listener stopped. Active: $_activeListenerCount');
  }

  /// Update current queue depth
  void updateQueueDepth(int depth) {
    _queueDepth = depth;
    if (depth > 0) {
      log.d('Queue depth: $depth');
    }
  }

  /// Record successful sync operation
  void recordSyncSuccess() {
    _syncSuccessCount++;
    _lastSyncTime = DateTime.now();
  }

  /// Record sync error
  void recordSyncError(String errorType) {
    _syncErrorCount++;
    _errorsByType[errorType] = (_errorsByType[errorType] ?? 0) + 1;
    log.w('Sync error: $errorType (total: $_syncErrorCount)');
  }

  /// Get current metrics snapshot
  Map<String, dynamic> getSnapshot() {
    return {
      'activeListeners': _activeListenerCount,
      'queueDepth': _queueDepth,
      'lastSyncTime': _lastSyncTime?.toIso8601String(),
      'syncSuccessCount': _syncSuccessCount,
      'syncErrorCount': _syncErrorCount,
      'errorsByType': Map.from(_errorsByType),
    };
  }

  /// Print metrics summary to logs
  void printSummary() {
    final snapshot = getSnapshot();
    log.i('=== Sync Metrics ===');
    log.i('Active Listeners: ${snapshot['activeListeners']}');
    log.i('Queue Depth: ${snapshot['queueDepth']}');
    log.i('Success: ${snapshot['syncSuccessCount']}, Errors: ${snapshot['syncErrorCount']}');
    if (_errorsByType.isNotEmpty) {
      log.i('Errors by type: $_errorsByType');
    }
    log.i('===================');
  }

  /// Reset all metrics (useful for testing)
  void reset() {
    _activeListenerCount = 0;
    _queueDepth = 0;
    _lastSyncTime = null;
    _syncSuccessCount = 0;
    _syncErrorCount = 0;
    _errorsByType.clear();
    log.d('Metrics reset');
  }
}
