import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fairshare_app/core/database/DAOs/expense_shares_dao.dart';
import 'package:fairshare_app/core/database/DAOs/expenses_dao.dart';
import 'package:fairshare_app/core/database/DAOs/groups_dao.dart';
import 'package:fairshare_app/core/database/DAOs/sync_dao.dart';
import 'package:fairshare_app/core/database/app_database.dart';
import 'package:fairshare_app/core/sync/upload_queue_service.dart';
import 'package:fairshare_app/features/expenses/data/services/firestore_expense_service.dart';
import 'package:fairshare_app/features/expenses/domain/entities/expense_entity.dart';
import 'package:fairshare_app/features/groups/data/services/firestore_group_service.dart';
import 'package:fairshare_app/features/groups/domain/entities/group_entity.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:result_dart/result_dart.dart';

import 'upload_queue_service_test.mocks.dart';

@GenerateMocks(
  [
    AppDatabase,
    SyncDao,
    ExpensesDao,
    GroupsDao,
    ExpenseSharesDao,
    FirebaseFirestore,
    CollectionReference,
    DocumentReference,
    DocumentSnapshot,
  ],
  customMocks: [
    MockSpec<FirestoreExpenseService>(
      as: #MockFirestoreExpenseService,
      onMissingStub: OnMissingStub.returnDefault,
    ),
    MockSpec<FirestoreGroupService>(
      as: #MockFirestoreGroupService,
      onMissingStub: OnMissingStub.returnDefault,
    ),
  ],
)
void main() {
  late MockAppDatabase mockDatabase;
  late MockSyncDao mockSyncDao;
  late MockExpensesDao mockExpensesDao;
  late MockGroupsDao mockGroupsDao;
  late MockExpenseSharesDao mockExpenseSharesDao;
  late MockFirestoreExpenseService mockExpenseService;
  late MockFirestoreGroupService mockGroupService;
  late MockFirebaseFirestore mockFirestore;
  late UploadQueueService uploadQueueService;

  const testOwnerId = 'testUser123';

  setUpAll(() {
    // Provide dummy value for Result type that mockito needs
    // Mockito looks for ResultDart<void, Exception> which is Result<void> in result_dart
    // We provide Success(unit) since Unit is the void equivalent
    provideDummy<Result<void>>(const Success(unit));
  });

  setUp(() {
    mockDatabase = MockAppDatabase();
    mockSyncDao = MockSyncDao();
    mockExpensesDao = MockExpensesDao();
    mockGroupsDao = MockGroupsDao();
    mockExpenseSharesDao = MockExpenseSharesDao();
    mockExpenseService = MockFirestoreExpenseService();
    mockGroupService = MockFirestoreGroupService();
    mockFirestore = MockFirebaseFirestore();

    // Wire up database DAOs
    when(mockDatabase.syncDao).thenReturn(mockSyncDao);
    when(mockDatabase.expensesDao).thenReturn(mockExpensesDao);
    when(mockDatabase.groupsDao).thenReturn(mockGroupsDao);
    when(mockDatabase.expenseSharesDao).thenReturn(mockExpenseSharesDao);

    uploadQueueService = UploadQueueService(
      database: mockDatabase,
      expenseService: mockExpenseService,
      groupService: mockGroupService,
      firestore: mockFirestore,
      ownerId: testOwnerId,
    );
  });

  group('UploadQueueService', () {
    group('processQueue', () {
      test('should return empty result when queue is empty', () async {
        // Arrange
        when(
          mockSyncDao.getPendingOperations(
            ownerId: testOwnerId,
            limit: anyNamed('limit'),
          ),
        ).thenAnswer((_) async => []);

        // Act
        final result = await uploadQueueService.processQueue();

        // Assert
        expect(result.totalProcessed, 0);
        expect(result.successCount, 0);
        expect(result.failureCount, 0);
      });

      test('should process expense create operation successfully', () async {
        // Arrange
        final operation = SyncQueueData(
          id: 1,
          ownerId: testOwnerId,
          entityType: 'expense',
          entityId: 'expense123',
          operationType: 'create',
          retryCount: 0,
          lastError: null,
          createdAt: DateTime.now(),
          metadata: null,
        );

        final expense = ExpenseEntity(
          id: 'expense123',
          groupId: 'group123',
          title: 'Test expense',
          amount: 100.0,
          currency: 'USD',
          paidBy: testOwnerId,
          expenseDate: DateTime(2025, 1, 1),
          createdAt: DateTime(2025, 1, 1),
          updatedAt: DateTime(2025, 1, 1),
          deletedAt: null,
        );

        when(
          mockSyncDao.getPendingOperations(
            ownerId: testOwnerId,
            limit: anyNamed('limit'),
          ),
        ).thenAnswer((_) async => [operation]);

        when(
          mockExpensesDao.getExpenseById('expense123'),
        ).thenAnswer((_) async => expense);

        when(
          mockExpenseService.uploadExpense(expense),
        ).thenAnswer((_) async => const Success(unit));

        // Mock Firestore document fetch for timestamp
        final mockDoc = MockDocumentSnapshot<Map<String, dynamic>>();
        final mockDocRef = MockDocumentReference<Map<String, dynamic>>();
        final mockExpensesCollection =
            MockCollectionReference<Map<String, dynamic>>();
        final mockGroupsCollection =
            MockCollectionReference<Map<String, dynamic>>();
        final mockGroupDocRef = MockDocumentReference<Map<String, dynamic>>();

        when(
          mockFirestore.collection('groups'),
        ).thenReturn(mockGroupsCollection);
        when(mockGroupsCollection.doc('group123')).thenReturn(mockGroupDocRef);
        when(
          mockGroupDocRef.collection('expenses'),
        ).thenReturn(mockExpensesCollection);
        when(mockExpensesCollection.doc('expense123')).thenReturn(mockDocRef);
        when(mockDocRef.get()).thenAnswer((_) async => mockDoc);
        when(mockDoc.exists).thenReturn(true);
        when(mockDoc.data()).thenReturn({
          'updated_at': Timestamp.fromDate(DateTime(2025, 1, 1, 12, 0)),
        });

        when(
          mockExpensesDao.updateExpenseTimestamp(any, any),
        ).thenAnswer((_) async {});
        when(mockSyncDao.removeQueuedOperation(1)).thenAnswer((_) async {});
        when(
          mockSyncDao.getPendingOperationCount(testOwnerId),
        ).thenAnswer((_) async => 0);

        // Act
        final result = await uploadQueueService.processQueue();

        // Assert
        expect(result.totalProcessed, 1);
        expect(result.successCount, 1);
        expect(result.failureCount, 0);
        verify(mockExpenseService.uploadExpense(expense)).called(1);
        verify(mockSyncDao.removeQueuedOperation(1)).called(1);
      });

      test('should process expense delete operation successfully', () async {
        // Arrange
        final operation = SyncQueueData(
          id: 1,
          ownerId: testOwnerId,
          entityType: 'expense',
          entityId: 'expense123',
          operationType: 'delete',
          retryCount: 0,
          lastError: null,
          createdAt: DateTime.now(),
          metadata: null,
        );

        final expense = ExpenseEntity(
          id: 'expense123',
          groupId: 'group123',
          title: 'Test expense',
          amount: 100.0,
          currency: 'USD',
          paidBy: testOwnerId,
          expenseDate: DateTime(2025, 1, 1),
          createdAt: DateTime(2025, 1, 1),
          updatedAt: DateTime(2025, 1, 1),
          deletedAt: DateTime(2025, 1, 2), // Soft deleted
        );

        when(
          mockSyncDao.getPendingOperations(
            ownerId: testOwnerId,
            limit: anyNamed('limit'),
          ),
        ).thenAnswer((_) async => [operation]);

        when(
          mockExpensesDao.getExpenseById('expense123', includeDeleted: true),
        ).thenAnswer((_) async => expense);

        when(
          mockExpenseService.deleteExpense('group123', 'expense123'),
        ).thenAnswer((_) async => const Success(unit));

        when(
          mockExpensesDao.hardDeleteExpense('expense123'),
        ).thenAnswer((_) async {});
        when(mockSyncDao.removeQueuedOperation(1)).thenAnswer((_) async {});
        when(
          mockSyncDao.getPendingOperationCount(testOwnerId),
        ).thenAnswer((_) async => 0);

        // Act
        final result = await uploadQueueService.processQueue();

        // Assert
        expect(result.totalProcessed, 1);
        expect(result.successCount, 1);
        expect(result.failureCount, 0);
        verify(
          mockExpenseService.deleteExpense('group123', 'expense123'),
        ).called(1);
        verify(mockExpensesDao.hardDeleteExpense('expense123')).called(1);
        verify(mockSyncDao.removeQueuedOperation(1)).called(1);
      });

      test('should process group create operation successfully', () async {
        // Arrange
        final operation = SyncQueueData(
          id: 1,
          ownerId: testOwnerId,
          entityType: 'group',
          entityId: 'group123',
          operationType: 'create',
          retryCount: 0,
          lastError: null,
          createdAt: DateTime.now(),
          metadata: null,
        );

        final group = GroupEntity(
          id: 'group123',
          displayName: 'Test Group',
          avatarUrl: '',
          isPersonal: false, // Shared group
          defaultCurrency: 'USD',
          createdAt: DateTime(2025, 1, 1),
          updatedAt: DateTime(2025, 1, 1),
          lastActivityAt: DateTime(2025, 1, 1),
          deletedAt: null,
        );

        when(
          mockSyncDao.getPendingOperations(
            ownerId: testOwnerId,
            limit: anyNamed('limit'),
          ),
        ).thenAnswer((_) async => [operation]);

        when(
          mockGroupsDao.getGroupById('group123'),
        ).thenAnswer((_) async => group);

        when(
          mockGroupService.uploadGroup(group),
        ).thenAnswer((_) async => const Success(unit));

        // Mock Firestore document fetch for timestamp
        final mockDoc = MockDocumentSnapshot<Map<String, dynamic>>();
        final mockDocRef = MockDocumentReference<Map<String, dynamic>>();
        final mockGroupsCollection =
            MockCollectionReference<Map<String, dynamic>>();

        when(
          mockFirestore.collection('groups'),
        ).thenReturn(mockGroupsCollection);
        when(mockGroupsCollection.doc('group123')).thenReturn(mockDocRef);
        when(mockDocRef.get()).thenAnswer((_) async => mockDoc);
        when(mockDoc.exists).thenReturn(true);
        when(mockDoc.data()).thenReturn({
          'updated_at': Timestamp.fromDate(DateTime(2025, 1, 1, 12, 0)),
        });

        when(
          mockGroupsDao.updateGroupTimestamp(any, any),
        ).thenAnswer((_) async {});
        when(mockSyncDao.removeQueuedOperation(1)).thenAnswer((_) async {});
        when(
          mockSyncDao.getPendingOperationCount(testOwnerId),
        ).thenAnswer((_) async => 0);

        // Act
        final result = await uploadQueueService.processQueue();

        // Assert
        expect(result.totalProcessed, 1);
        expect(result.successCount, 1);
        expect(result.failureCount, 0);
        verify(mockGroupService.uploadGroup(group)).called(1);
        verify(mockSyncDao.removeQueuedOperation(1)).called(1);
      });

      test('should skip personal groups', () async {
        // Arrange
        final operation = SyncQueueData(
          id: 1,
          ownerId: testOwnerId,
          entityType: 'group',
          entityId: 'group123',
          operationType: 'create',
          retryCount: 0,
          lastError: null,
          createdAt: DateTime.now(),
          metadata: null,
        );

        final personalGroup = GroupEntity(
          id: 'group123',
          displayName: 'Personal Group',
          avatarUrl: '',
          isPersonal: true, // Personal group
          defaultCurrency: 'USD',
          createdAt: DateTime(2025, 1, 1),
          updatedAt: DateTime(2025, 1, 1),
          lastActivityAt: DateTime(2025, 1, 1),
          deletedAt: null,
        );

        when(
          mockSyncDao.getPendingOperations(
            ownerId: testOwnerId,
            limit: anyNamed('limit'),
          ),
        ).thenAnswer((_) async => [operation]);

        when(
          mockGroupsDao.getGroupById('group123'),
        ).thenAnswer((_) async => personalGroup);

        when(mockSyncDao.removeQueuedOperation(1)).thenAnswer((_) async {});
        when(
          mockSyncDao.getPendingOperationCount(testOwnerId),
        ).thenAnswer((_) async => 0);

        // Act
        final result = await uploadQueueService.processQueue();

        // Assert
        expect(result.totalProcessed, 1);
        expect(result.successCount, 1);
        expect(result.failureCount, 0);
        verifyNever(mockGroupService.uploadGroup(any));
        verify(mockSyncDao.removeQueuedOperation(1)).called(1);
      });

      test('should handle operation failure and mark as failed', () async {
        // Arrange
        final operation = SyncQueueData(
          id: 1,
          ownerId: testOwnerId,
          entityType: 'expense',
          entityId: 'expense123',
          operationType: 'create',
          retryCount: 0,
          lastError: null,
          createdAt: DateTime.now(),
          metadata: null,
        );

        final expense = ExpenseEntity(
          id: 'expense123',
          groupId: 'group123',
          title: 'Test expense',
          amount: 100.0,
          currency: 'USD',
          paidBy: testOwnerId,
          expenseDate: DateTime(2025, 1, 1),
          createdAt: DateTime(2025, 1, 1),
          updatedAt: DateTime(2025, 1, 1),
          deletedAt: null,
        );

        when(
          mockSyncDao.getPendingOperations(
            ownerId: testOwnerId,
            limit: anyNamed('limit'),
          ),
        ).thenAnswer((_) async => [operation]);

        when(
          mockExpensesDao.getExpenseById('expense123'),
        ).thenAnswer((_) async => expense);

        when(
          mockExpenseService.uploadExpense(expense),
        ).thenAnswer((_) async => Failure(Exception('Network error')));

        when(mockSyncDao.markOperationFailed(1, any)).thenAnswer((_) async {});
        when(
          mockSyncDao.getPendingOperationCount(testOwnerId),
        ).thenAnswer((_) async => 1);

        // Act
        final result = await uploadQueueService.processQueue();

        // Assert
        expect(result.totalProcessed, 1);
        expect(result.successCount, 0);
        expect(result.failureCount, 1);
        verify(mockSyncDao.markOperationFailed(1, any)).called(1);
        verifyNever(mockSyncDao.removeQueuedOperation(any));
      });

      test('should skip operations that exceeded max retries', () async {
        // Arrange
        final operation = SyncQueueData(
          id: 1,
          ownerId: testOwnerId,
          entityType: 'expense',
          entityId: 'expense123',
          operationType: 'create',
          retryCount: 10, // Exceeded max retries (assuming max is < 10)
          lastError: 'Previous error',
          createdAt: DateTime.now(),
          metadata: null,
        );

        when(
          mockSyncDao.getPendingOperations(
            ownerId: testOwnerId,
            limit: anyNamed('limit'),
          ),
        ).thenAnswer((_) async => [operation]);

        when(
          mockSyncDao.getPendingOperationCount(testOwnerId),
        ).thenAnswer((_) async => 1);

        // Act
        final result = await uploadQueueService.processQueue();

        // Assert
        expect(result.totalProcessed, 1);
        expect(result.successCount, 0);
        expect(result.failureCount, 1);
        verifyNever(mockExpensesDao.getExpenseById(any));
        verifyNever(mockSyncDao.removeQueuedOperation(any));
      });

      test('should process multiple operations in batch', () async {
        // Arrange
        final operation1 = SyncQueueData(
          id: 1,
          ownerId: testOwnerId,
          entityType: 'expense',
          entityId: 'expense1',
          operationType: 'create',
          retryCount: 0,
          lastError: null,
          createdAt: DateTime.now(),
          metadata: null,
        );

        final operation2 = SyncQueueData(
          id: 2,
          ownerId: testOwnerId,
          entityType: 'expense',
          entityId: 'expense2',
          operationType: 'create',
          retryCount: 0,
          lastError: null,
          createdAt: DateTime.now(),
          metadata: null,
        );

        final expense1 = ExpenseEntity(
          id: 'expense1',
          groupId: 'group123',
          title: 'Expense 1',
          amount: 100.0,
          currency: 'USD',
          paidBy: testOwnerId,
          expenseDate: DateTime(2025, 1, 1),
          createdAt: DateTime(2025, 1, 1),
          updatedAt: DateTime(2025, 1, 1),
          deletedAt: null,
        );

        final expense2 = ExpenseEntity(
          id: 'expense2',
          groupId: 'group123',
          title: 'Expense 2',
          amount: 200.0,
          currency: 'USD',
          paidBy: testOwnerId,
          expenseDate: DateTime(2025, 1, 2),
          createdAt: DateTime(2025, 1, 2),
          updatedAt: DateTime(2025, 1, 2),
          deletedAt: null,
        );

        when(
          mockSyncDao.getPendingOperations(
            ownerId: testOwnerId,
            limit: anyNamed('limit'),
          ),
        ).thenAnswer((_) async => [operation1, operation2]);

        when(
          mockExpensesDao.getExpenseById('expense1'),
        ).thenAnswer((_) async => expense1);
        when(
          mockExpensesDao.getExpenseById('expense2'),
        ).thenAnswer((_) async => expense2);

        when(
          mockExpenseService.uploadExpense(any),
        ).thenAnswer((_) async => const Success(unit));

        // Mock Firestore for both expenses
        final mockDoc = MockDocumentSnapshot<Map<String, dynamic>>();
        final mockDocRef = MockDocumentReference<Map<String, dynamic>>();
        final mockExpensesCollection =
            MockCollectionReference<Map<String, dynamic>>();
        final mockGroupsCollection =
            MockCollectionReference<Map<String, dynamic>>();
        final mockGroupDocRef = MockDocumentReference<Map<String, dynamic>>();

        when(
          mockFirestore.collection('groups'),
        ).thenReturn(mockGroupsCollection);
        when(mockGroupsCollection.doc('group123')).thenReturn(mockGroupDocRef);
        when(
          mockGroupDocRef.collection('expenses'),
        ).thenReturn(mockExpensesCollection);
        when(mockExpensesCollection.doc(any)).thenReturn(mockDocRef);
        when(mockDocRef.get()).thenAnswer((_) async => mockDoc);
        when(mockDoc.exists).thenReturn(true);
        when(mockDoc.data()).thenReturn({
          'updated_at': Timestamp.fromDate(DateTime(2025, 1, 1, 12, 0)),
        });

        when(
          mockExpensesDao.updateExpenseTimestamp(any, any),
        ).thenAnswer((_) async {});
        when(mockSyncDao.removeQueuedOperation(any)).thenAnswer((_) async {});
        when(
          mockSyncDao.getPendingOperationCount(testOwnerId),
        ).thenAnswer((_) async => 0);

        // Act
        final result = await uploadQueueService.processQueue();

        // Assert
        expect(result.totalProcessed, 2);
        expect(result.successCount, 2);
        expect(result.failureCount, 0);
        verify(mockSyncDao.removeQueuedOperation(1)).called(1);
        verify(mockSyncDao.removeQueuedOperation(2)).called(1);
      });

      test('should handle unknown entity type', () async {
        // Arrange
        final operation = SyncQueueData(
          id: 1,
          ownerId: testOwnerId,
          entityType: 'unknown_entity',
          entityId: 'entity123',
          operationType: 'create',
          retryCount: 0,
          lastError: null,
          createdAt: DateTime.now(),
          metadata: null,
        );

        when(
          mockSyncDao.getPendingOperations(
            ownerId: testOwnerId,
            limit: anyNamed('limit'),
          ),
        ).thenAnswer((_) async => [operation]);

        when(mockSyncDao.markOperationFailed(1, any)).thenAnswer((_) async {});
        when(
          mockSyncDao.getPendingOperationCount(testOwnerId),
        ).thenAnswer((_) async => 1);

        // Act
        final result = await uploadQueueService.processQueue();

        // Assert
        expect(result.totalProcessed, 1);
        expect(result.successCount, 0);
        expect(result.failureCount, 1);
        verify(
          mockSyncDao.markOperationFailed(
            1,
            argThat(contains('Unknown entity type')),
          ),
        ).called(1);
      });
    });

    group('getPendingCount', () {
      test('should return pending operation count for user', () async {
        // Arrange
        when(
          mockSyncDao.getPendingOperationCount(testOwnerId),
        ).thenAnswer((_) async => 5);

        // Act
        final count = await uploadQueueService.getPendingCount();

        // Assert
        expect(count, 5);
        verify(mockSyncDao.getPendingOperationCount(testOwnerId)).called(1);
      });
    });
  });

  group('UploadQueueResult', () {
    test('hasFailures should return true when there are failures', () {
      final result = UploadQueueResult(
        totalProcessed: 5,
        successCount: 3,
        failureCount: 2,
      );

      expect(result.hasFailures, true);
    });

    test('hasFailures should return false when there are no failures', () {
      final result = UploadQueueResult(
        totalProcessed: 5,
        successCount: 5,
        failureCount: 0,
      );

      expect(result.hasFailures, false);
    });

    test('allSucceeded should return true when all succeeded', () {
      final result = UploadQueueResult(
        totalProcessed: 5,
        successCount: 5,
        failureCount: 0,
      );

      expect(result.allSucceeded, true);
    });

    test('allSucceeded should return false when some failed', () {
      final result = UploadQueueResult(
        totalProcessed: 5,
        successCount: 3,
        failureCount: 2,
      );

      expect(result.allSucceeded, false);
    });

    test('allSucceeded should return false when nothing was processed', () {
      final result = UploadQueueResult(
        totalProcessed: 0,
        successCount: 0,
        failureCount: 0,
      );

      expect(result.allSucceeded, false);
    });
  });
}
