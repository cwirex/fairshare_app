/// Feature flags for controlling app behavior
class FeatureFlags {
  /// Enable real-time sync with Firestore listeners
  /// When enabled: Uses Firestore snapshot listeners for < 1s sync latency
  /// When disabled: Falls back to manual sync only
  static const bool realtimeSyncEnabled = true;

  /// Enable detailed sync logging
  static const bool verboseSyncLogging = true;

  /// Maximum retry count for failed sync operations
  static const int maxSyncRetries = 3;

  /// Batch size for upload queue processing
  static const int uploadBatchSize = 10;
}
