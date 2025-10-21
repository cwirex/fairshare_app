import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:fairshare_app/core/database/app_database.dart';
import 'package:fairshare_app/core/events/event_broker.dart';
import 'package:fairshare_app/core/events/sync_events.dart';
import 'package:fairshare_app/core/logging/app_logger.dart';
import 'package:fairshare_app/core/monitoring/sync_metrics.dart';
import 'package:fairshare_app/core/sync/realtime_sync_service.dart';
import 'package:fairshare_app/core/sync/upload_queue_service.dart';
import 'package:fairshare_app/features/groups/data/services/group_initialization_service.dart';
import 'package:flutter/widgets.dart';
import 'package:result_dart/result_dart.dart';

/// Service that coordinates syncing data between local database and Firestore.
///
/// **Architecture:**
/// - Upload: Queue-based, reliable, retryable
/// - Download: Real-time via Firestore snapshot listeners
/// - Lifecycle: Foreground-only listeners to save battery
///
/// **Components:**
/// - [UploadQueueService]: Processes local changes → Firestore
/// - [RealtimeSyncService]: Manages Firestore listeners → Local DB
/// - [GroupInitializationService]: Ensures personal group exists
/// - Connectivity monitoring: Start/stop sync based on network
/// - App lifecycle: Start/stop listeners based on foreground/background
class SyncService with LoggerMixin, WidgetsBindingObserver {
  final AppDatabase _database;
  final UploadQueueService _uploadQueueService;
  final RealtimeSyncService _realtimeSyncService;
  final GroupInitializationService _groupInitializationService;
  final EventBroker _eventBroker;
  final Connectivity _connectivity;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  final List<StreamSubscription<void>> _eventSubscriptions = [];
  bool _isOnline = false;
  bool _isAppInForeground = true;
  String? _currentUserId;

  SyncService({
    required AppDatabase database,
    required UploadQueueService uploadQueueService,
    required RealtimeSyncService realtimeSyncService,
    required GroupInitializationService groupInitializationService,
    required EventBroker eventBroker,
    Connectivity? connectivity,
  }) : _database = database,
       _uploadQueueService = uploadQueueService,
       _realtimeSyncService = realtimeSyncService,
       _groupInitializationService = groupInitializationService,
       _eventBroker = eventBroker,
       _connectivity = connectivity ?? Connectivity();

  /// Start auto-sync monitoring
  void startAutoSync(String? userId) {
    if (userId == null) {
      log.w('Cannot start sync: no user ID provided');
      return;
    }

    _currentUserId = userId;
    log.i('🚀 Starting auto-sync for user: $userId');

    // 1. Ensure personal group exists FIRST (before any sync operations)
    _groupInitializationService.ensurePersonalGroupExists(userId);

    // 2. Listen to app lifecycle
    WidgetsBinding.instance.addObserver(this);

    // 3. Listen to domain events to trigger immediate upload
    _setupEventListeners();

    // 4. Listen to connectivity changes
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((
      results,
    ) {
      final wasOnline = _isOnline;
      _isOnline = results.any((r) => r != ConnectivityResult.none);

      if (_isOnline && !wasOnline) {
        log.i('📶 Device came online');
        _onConnectionRestored();
      } else if (!_isOnline && wasOnline) {
        log.i('📴 Device went offline');
        _onConnectionLost();
      }
    });

    // 5. Initial sync check
    _checkConnectivityAndSync(userId);
  }

  /// Setup event listeners to trigger immediate sync when data changes
  void _setupEventListeners() {
    // Listen to the single UploadQueueItemAdded event
    // This is domain-agnostic and fired by repositories whenever they enqueue an item
    _eventSubscriptions.add(
      _eventBroker.on<UploadQueueItemAdded>().listen((event) {
        log.d('📤 Queue item added: ${event.toString()})');
        _triggerUploadQueue();
      }),
    );

    log.d('Event listeners setup for automatic upload queue processing');
  }

  /// Trigger upload queue processing if online
  void _triggerUploadQueue() {
    if (_isOnline && _isAppInForeground) {
      log.d('📤 Triggering upload queue processing due to data change');
      _uploadQueueService.processQueue();
    } else {
      log.d(
        '⏳ Upload queued (offline=${!_isOnline}, background=${!_isAppInForeground})',
      );
    }
  }

  /// Stop auto-sync monitoring
  void stopAutoSync() {
    log.i('🛑 Stopping auto-sync');

    WidgetsBinding.instance.removeObserver(this);
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;

    // Cancel all event subscriptions
    for (final subscription in _eventSubscriptions) {
      subscription.cancel();
    }
    _eventSubscriptions.clear();

    _realtimeSyncService.stopRealtimeSync();
    _currentUserId = null;

    SyncMetrics.instance.printSummary();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        log.i('📱 App resumed (foreground)');
        _isAppInForeground = true;
        if (_isOnline && _currentUserId != null) {
          _realtimeSyncService.startRealtimeSync(_currentUserId!);
          _uploadQueueService.processQueue();
        }
        break;

      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        log.i('⏸️ App backgrounded');
        _isAppInForeground = false;
        // Stop listeners to save battery
        _realtimeSyncService.stopRealtimeSync();
        break;
    }
  }

  /// Check connectivity and start sync if online
  Future<void> _checkConnectivityAndSync(String userId) async {
    final results = await _connectivity.checkConnectivity();
    _isOnline = results.any((r) => r != ConnectivityResult.none);

    log.d('Initial connectivity check: ${_isOnline ? "online" : "offline"}');

    if (_isOnline) {
      await _realtimeSyncService.startRealtimeSync(userId);
      await _uploadQueueService.processQueue();
    }
  }

  /// Handle connection restored
  void _onConnectionRestored() {
    if (_currentUserId != null && _isAppInForeground) {
      log.i('🔄 Resuming sync after connection restored');
      _realtimeSyncService.startRealtimeSync(_currentUserId!);
      _uploadQueueService.processQueue();
    }
  }

  /// Handle connection lost
  void _onConnectionLost() {
    log.i('⚠️ Connection lost, stopping real-time sync');
    _realtimeSyncService.stopRealtimeSync();
  }

  /// Manual sync trigger (for pull-to-refresh)
  Future<Result<void>> syncAll(String userId) async {
    log.i('🔄 Manual sync triggered');

    try {
      // Process upload queue
      final result = await _uploadQueueService.processQueue();
      log.i(
        'Upload queue processed: ${result.successCount} succeeded, ${result.failureCount} failed',
      );

      // Ensure real-time sync is active
      if (_isOnline && _isAppInForeground) {
        await _realtimeSyncService.startRealtimeSync(userId);
      }

      return Success.unit();
    } catch (e) {
      log.e('Manual sync failed: $e');
      return Failure(Exception('Manual sync failed: $e'));
    }
  }

  /// Get pending upload count (for UI badges)
  Future<int> getPendingUploadCount() async {
    if (_currentUserId == null) return 0;
    return await _database.syncDao.getPendingOperationCount(_currentUserId!);
  }

  /// Get sync status (for debugging)
  Map<String, dynamic> getSyncStatus() {
    return {
      'isOnline': _isOnline,
      'isAppInForeground': _isAppInForeground,
      'currentUserId': _currentUserId,
      'realtimeSyncStatus': _realtimeSyncService.getStatus(),
      'metrics': SyncMetrics.instance.getSnapshot(),
    };
  }

  /// Dispose resources
  void dispose() {
    stopAutoSync();
  }
}
