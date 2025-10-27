import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:fairshare_app/core/database/DAOs/sync_dao.dart';
import 'package:fairshare_app/core/database/app_database.dart';
import 'package:fairshare_app/core/events/event_broker.dart';
import 'package:fairshare_app/core/events/sync_events.dart';
import 'package:fairshare_app/core/sync/realtime_sync_service.dart';
import 'package:fairshare_app/core/sync/sync_service.dart';
import 'package:fairshare_app/core/sync/sync_service_interfaces.dart';
import 'package:fairshare_app/core/sync/upload_queue_service.dart';
import 'package:fairshare_app/features/groups/data/services/group_initialization_service.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'sync_service_test.mocks.dart';

@GenerateMocks([
  AppDatabase,
  SyncDao,
  UploadQueueService,
  RealtimeSyncService,
  GroupInitializationService,
  EventBroker,
  Connectivity,
])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockAppDatabase mockDatabase;
  late MockSyncDao mockSyncDao;
  late MockUploadQueueService mockUploadQueueService;
  late MockRealtimeSyncService mockRealtimeSyncService;
  late MockGroupInitializationService mockGroupInitializationService;
  late MockEventBroker mockEventBroker;
  late MockConnectivity mockConnectivity;
  late SyncService syncService;

  // Connectivity stream controller
  late StreamController<List<ConnectivityResult>> connectivityController;

  // Event stream controller for UploadQueueItemAdded
  late StreamController<UploadQueueItemAdded> uploadQueueEventController;

  const testUserId = 'testUser123';

  setUp(() {
    mockDatabase = MockAppDatabase();
    mockSyncDao = MockSyncDao();
    mockUploadQueueService = MockUploadQueueService();
    mockRealtimeSyncService = MockRealtimeSyncService();
    mockGroupInitializationService = MockGroupInitializationService();
    mockEventBroker = MockEventBroker();
    mockConnectivity = MockConnectivity();

    // Setup connectivity stream
    connectivityController =
        StreamController<List<ConnectivityResult>>.broadcast();
    when(
      mockConnectivity.onConnectivityChanged,
    ).thenAnswer((_) => connectivityController.stream);

    // Setup event stream for UploadQueueItemAdded
    uploadQueueEventController =
        StreamController<UploadQueueItemAdded>.broadcast();
    when(
      mockEventBroker.on<UploadQueueItemAdded>(),
    ).thenAnswer((_) => uploadQueueEventController.stream);

    // Wire up database DAOs
    when(mockDatabase.syncDao).thenReturn(mockSyncDao);

    // Default stubs
    when(
      mockGroupInitializationService.ensurePersonalGroupExists(any),
    ).thenAnswer((_) async {});
    when(
      mockRealtimeSyncService.startRealtimeSync(any),
    ).thenAnswer((_) async {});
    when(mockRealtimeSyncService.stopRealtimeSync()).thenAnswer((_) async {});
    when(mockUploadQueueService.processQueue()).thenAnswer(
      (_) async => UploadQueueResult(
        totalProcessed: 0,
        successCount: 0,
        failureCount: 0,
      ),
    );
    when(mockSyncDao.getPendingOperationCount(any)).thenAnswer((_) async => 0);

    syncService = SyncService(
      database: mockDatabase,
      uploadQueueService: mockUploadQueueService,
      realtimeSyncService: mockRealtimeSyncService,
      groupInitializationService: mockGroupInitializationService,
      eventBroker: mockEventBroker,
      connectivity: mockConnectivity,
    );
  });

  tearDown(() {
    connectivityController.close();
    uploadQueueEventController.close();
    syncService.dispose();
  });

  group('SyncService', () {
    group('startAutoSync', () {
      test('should do nothing if userId is null', () {
        // Act
        syncService.startAutoSync(null);

        // Assert
        verifyNever(
          mockGroupInitializationService.ensurePersonalGroupExists(any),
        );
        verifyNever(mockConnectivity.onConnectivityChanged);
      });

      test('should initialize personal group on start', () async {
        // Arrange
        when(
          mockConnectivity.checkConnectivity(),
        ).thenAnswer((_) async => [ConnectivityResult.wifi]);

        // Act
        syncService.startAutoSync(testUserId);
        await Future.delayed(Duration.zero); // Let async operations complete

        // Assert
        verify(
          mockGroupInitializationService.ensurePersonalGroupExists(testUserId),
        ).called(1);
      });

      test(
        'should setup connectivity listener and respond to changes',
        () async {
          // Arrange
          when(
            mockConnectivity.checkConnectivity(),
          ).thenAnswer((_) async => [ConnectivityResult.none]);

          // Act - start sync
          syncService.startAutoSync(testUserId);
          await Future.delayed(const Duration(milliseconds: 50));

          // Trigger connectivity change
          connectivityController.add([ConnectivityResult.wifi]);
          await Future.delayed(const Duration(milliseconds: 50));

          // Assert - should respond to connectivity changes
          verify(
            mockRealtimeSyncService.startRealtimeSync(testUserId),
          ).called(1);
        },
      );

      test('should setup event listeners for UploadQueueItemAdded', () async {
        // Arrange
        when(
          mockConnectivity.checkConnectivity(),
        ).thenAnswer((_) async => [ConnectivityResult.wifi]);

        // Act - start sync
        syncService.startAutoSync(testUserId);
        await Future.delayed(const Duration(milliseconds: 50));
        clearInteractions(mockUploadQueueService);

        // Fire event
        uploadQueueEventController.add(UploadQueueItemAdded('test'));
        await Future.delayed(const Duration(milliseconds: 50));

        // Assert - should process queue when event fires
        verify(mockUploadQueueService.processQueue()).called(1);
      });

      test('should check connectivity and start sync if online', () async {
        // Arrange
        when(
          mockConnectivity.checkConnectivity(),
        ).thenAnswer((_) async => [ConnectivityResult.wifi]);

        // Act
        syncService.startAutoSync(testUserId);
        await Future.delayed(
          const Duration(milliseconds: 100),
        ); // Wait for async

        // Assert
        verify(mockRealtimeSyncService.startRealtimeSync(testUserId)).called(1);
        verify(mockUploadQueueService.processQueue()).called(1);
      });

      test('should not start sync if offline initially', () async {
        // Arrange
        when(
          mockConnectivity.checkConnectivity(),
        ).thenAnswer((_) async => [ConnectivityResult.none]);

        // Act
        syncService.startAutoSync(testUserId);
        await Future.delayed(
          const Duration(milliseconds: 100),
        ); // Wait for async

        // Assert
        verifyNever(mockRealtimeSyncService.startRealtimeSync(any));
        verifyNever(mockUploadQueueService.processQueue());
      });
    });

    group('stopAutoSync', () {
      test('should cancel connectivity subscription', () {
        // Arrange
        when(
          mockConnectivity.checkConnectivity(),
        ).thenAnswer((_) async => [ConnectivityResult.wifi]);
        syncService.startAutoSync(testUserId);

        // Act
        syncService.stopAutoSync();

        // Assert - connectivity listener should be cancelled
        // (We can't directly verify this, but we can check side effects)
        verify(mockRealtimeSyncService.stopRealtimeSync()).called(1);
      });

      test('should cancel event subscriptions', () async {
        // Arrange
        when(
          mockConnectivity.checkConnectivity(),
        ).thenAnswer((_) async => [ConnectivityResult.wifi]);
        syncService.startAutoSync(testUserId);
        await Future.delayed(const Duration(milliseconds: 50));

        // Act
        syncService.stopAutoSync();

        // Fire event after stop - should not trigger queue
        uploadQueueEventController.add(UploadQueueItemAdded('test'));
        await Future.delayed(const Duration(milliseconds: 50));

        // Assert - queue should only be called during startup, not after stop
        verify(
          mockUploadQueueService.processQueue(),
        ).called(1); // Only from startup
      });

      test('should stop realtime sync', () {
        // Arrange
        when(
          mockConnectivity.checkConnectivity(),
        ).thenAnswer((_) async => [ConnectivityResult.wifi]);
        syncService.startAutoSync(testUserId);

        // Act
        syncService.stopAutoSync();

        // Assert
        verify(mockRealtimeSyncService.stopRealtimeSync()).called(1);
      });
    });

    group('connectivity changes', () {
      test('should resume sync when connection is restored', () async {
        // Arrange
        when(
          mockConnectivity.checkConnectivity(),
        ).thenAnswer((_) async => [ConnectivityResult.none]);
        syncService.startAutoSync(testUserId);
        await Future.delayed(const Duration(milliseconds: 50));

        // Act - simulate going online
        connectivityController.add([ConnectivityResult.wifi]);
        await Future.delayed(const Duration(milliseconds: 50));

        // Assert
        verify(mockRealtimeSyncService.startRealtimeSync(testUserId)).called(1);
        verify(mockUploadQueueService.processQueue()).called(1);
      });

      test('should stop sync when connection is lost', () async {
        // Arrange
        when(
          mockConnectivity.checkConnectivity(),
        ).thenAnswer((_) async => [ConnectivityResult.wifi]);
        syncService.startAutoSync(testUserId);
        await Future.delayed(const Duration(milliseconds: 50));

        // Act - simulate going offline
        connectivityController.add([ConnectivityResult.none]);
        await Future.delayed(const Duration(milliseconds: 50));

        // Assert
        verify(mockRealtimeSyncService.stopRealtimeSync()).called(1);
      });

      test('should not duplicate sync when connection stays online', () async {
        // Arrange
        when(
          mockConnectivity.checkConnectivity(),
        ).thenAnswer((_) async => [ConnectivityResult.wifi]);
        syncService.startAutoSync(testUserId);
        await Future.delayed(const Duration(milliseconds: 50));
        clearInteractions(mockRealtimeSyncService);
        clearInteractions(mockUploadQueueService);

        // Act - connection changes but stays online (wifi -> mobile)
        connectivityController.add([ConnectivityResult.mobile]);
        await Future.delayed(const Duration(milliseconds: 50));

        // Assert - should NOT trigger new sync (already online)
        verifyNever(mockRealtimeSyncService.startRealtimeSync(any));
        verifyNever(mockUploadQueueService.processQueue());
      });
    });

    group('app lifecycle', () {
      test('should resume sync when app comes to foreground', () async {
        // Arrange
        when(
          mockConnectivity.checkConnectivity(),
        ).thenAnswer((_) async => [ConnectivityResult.wifi]);
        syncService.startAutoSync(testUserId);
        await Future.delayed(const Duration(milliseconds: 50));

        // Simulate background
        syncService.didChangeAppLifecycleState(AppLifecycleState.paused);
        clearInteractions(mockRealtimeSyncService);
        clearInteractions(mockUploadQueueService);

        // Act - app comes to foreground
        syncService.didChangeAppLifecycleState(AppLifecycleState.resumed);
        await Future.delayed(const Duration(milliseconds: 50));

        // Assert
        verify(mockRealtimeSyncService.startRealtimeSync(testUserId)).called(1);
        verify(mockUploadQueueService.processQueue()).called(1);
      });

      test('should stop sync when app goes to background', () async {
        // Arrange
        when(
          mockConnectivity.checkConnectivity(),
        ).thenAnswer((_) async => [ConnectivityResult.wifi]);
        syncService.startAutoSync(testUserId);
        await Future.delayed(const Duration(milliseconds: 50));
        clearInteractions(mockRealtimeSyncService);

        // Act - app goes to background
        syncService.didChangeAppLifecycleState(AppLifecycleState.paused);

        // Assert
        verify(mockRealtimeSyncService.stopRealtimeSync()).called(1);
      });

      test('should not resume sync if offline when app resumes', () async {
        // Arrange - start offline
        when(
          mockConnectivity.checkConnectivity(),
        ).thenAnswer((_) async => [ConnectivityResult.none]);
        syncService.startAutoSync(testUserId);
        await Future.delayed(const Duration(milliseconds: 50));

        // Act - app comes to foreground while offline
        syncService.didChangeAppLifecycleState(AppLifecycleState.resumed);
        await Future.delayed(const Duration(milliseconds: 50));

        // Assert - should not sync while offline
        verifyNever(mockRealtimeSyncService.startRealtimeSync(any));
        verifyNever(mockUploadQueueService.processQueue());
      });
    });

    group('event-driven queue processing', () {
      test(
        'should process queue when UploadQueueItemAdded event fires',
        () async {
          // Arrange
          when(
            mockConnectivity.checkConnectivity(),
          ).thenAnswer((_) async => [ConnectivityResult.wifi]);
          syncService.startAutoSync(testUserId);
          await Future.delayed(const Duration(milliseconds: 50));
          clearInteractions(mockUploadQueueService);

          // Act - fire UploadQueueItemAdded event
          uploadQueueEventController.add(UploadQueueItemAdded('createExpense'));
          await Future.delayed(const Duration(milliseconds: 50));

          // Assert
          verify(mockUploadQueueService.processQueue()).called(1);
        },
      );

      test('should not process queue if offline when event fires', () async {
        // Arrange - start online then go offline
        when(
          mockConnectivity.checkConnectivity(),
        ).thenAnswer((_) async => [ConnectivityResult.wifi]);
        syncService.startAutoSync(testUserId);
        await Future.delayed(const Duration(milliseconds: 50));

        // Go offline
        connectivityController.add([ConnectivityResult.none]);
        await Future.delayed(const Duration(milliseconds: 50));
        clearInteractions(mockUploadQueueService);

        // Act - fire event while offline
        uploadQueueEventController.add(UploadQueueItemAdded('createExpense'));
        await Future.delayed(const Duration(milliseconds: 50));

        // Assert - should not process queue
        verifyNever(mockUploadQueueService.processQueue());
      });

      test(
        'should not process queue if app in background when event fires',
        () async {
          // Arrange - start in foreground then background
          when(
            mockConnectivity.checkConnectivity(),
          ).thenAnswer((_) async => [ConnectivityResult.wifi]);
          syncService.startAutoSync(testUserId);
          await Future.delayed(const Duration(milliseconds: 50));

          // Go to background
          syncService.didChangeAppLifecycleState(AppLifecycleState.paused);
          clearInteractions(mockUploadQueueService);

          // Act - fire event while in background
          uploadQueueEventController.add(UploadQueueItemAdded('createExpense'));
          await Future.delayed(const Duration(milliseconds: 50));

          // Assert - should not process queue
          verifyNever(mockUploadQueueService.processQueue());
        },
      );
    });

    group('manual sync', () {
      test(
        'should process queue and start realtime sync when online',
        () async {
          // Arrange
          when(
            mockConnectivity.checkConnectivity(),
          ).thenAnswer((_) async => [ConnectivityResult.wifi]);
          when(mockUploadQueueService.processQueue()).thenAnswer(
            (_) async => UploadQueueResult(
              totalProcessed: 5,
              successCount: 5,
              failureCount: 0,
            ),
          );
          syncService.startAutoSync(testUserId);
          await Future.delayed(const Duration(milliseconds: 50));
          clearInteractions(mockUploadQueueService);
          clearInteractions(mockRealtimeSyncService);

          // Act
          final result = await syncService.syncAll(testUserId);

          // Assert
          expect(result.isSuccess(), true);
          verify(mockUploadQueueService.processQueue()).called(1);
          verify(
            mockRealtimeSyncService.startRealtimeSync(testUserId),
          ).called(1);
        },
      );

      test('should not start realtime sync if offline', () async {
        // Arrange - offline
        when(
          mockConnectivity.checkConnectivity(),
        ).thenAnswer((_) async => [ConnectivityResult.none]);
        when(mockUploadQueueService.processQueue()).thenAnswer(
          (_) async => UploadQueueResult(
            totalProcessed: 0,
            successCount: 0,
            failureCount: 0,
          ),
        );
        syncService.startAutoSync(testUserId);
        await Future.delayed(const Duration(milliseconds: 50));

        // Act
        final result = await syncService.syncAll(testUserId);

        // Assert
        expect(result.isSuccess(), true);
        verify(mockUploadQueueService.processQueue()).called(1);
        verifyNever(mockRealtimeSyncService.startRealtimeSync(any));
      });

      test('should return failure if upload queue fails', () async {
        // Arrange - start offline to avoid processQueue during startup
        when(
          mockConnectivity.checkConnectivity(),
        ).thenAnswer((_) async => [ConnectivityResult.none]);
        syncService.startAutoSync(testUserId);
        await Future.delayed(const Duration(milliseconds: 50));

        // Now configure processQueue to throw
        when(
          mockUploadQueueService.processQueue(),
        ).thenThrow(Exception('Network error'));

        // Act - manual sync will call processQueue and throw
        final result = await syncService.syncAll(testUserId);

        // Assert
        expect(result.isError(), true);
      });
    });

    group('getPendingUploadCount', () {
      test('should return 0 if no current user', () async {
        // Act
        final count = await syncService.getPendingUploadCount();

        // Assert
        expect(count, 0);
        verifyNever(mockSyncDao.getPendingOperationCount(any));
      });

      test('should return pending count from database', () async {
        // Arrange
        when(
          mockConnectivity.checkConnectivity(),
        ).thenAnswer((_) async => [ConnectivityResult.wifi]);
        when(
          mockSyncDao.getPendingOperationCount(testUserId),
        ).thenAnswer((_) async => 5);
        syncService.startAutoSync(testUserId);
        await Future.delayed(const Duration(milliseconds: 50));

        // Act
        final count = await syncService.getPendingUploadCount();

        // Assert
        expect(count, 5);
        verify(mockSyncDao.getPendingOperationCount(testUserId)).called(1);
      });
    });
  });
}
