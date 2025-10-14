import 'dart:async';

import 'package:fairshare_app/core/database/DAOs/expense_shares_dao.dart';
import 'package:fairshare_app/core/database/DAOs/expenses_dao.dart';
import 'package:fairshare_app/core/database/DAOs/groups_dao.dart';
import 'package:fairshare_app/core/database/DAOs/user_dao.dart';
import 'package:fairshare_app/core/database/app_database.dart';
import 'package:fairshare_app/core/events/event_broker.dart';
import 'package:fairshare_app/core/sync/realtime_sync_service.dart';
import 'package:fairshare_app/features/expenses/data/services/firestore_expense_service.dart';
import 'package:fairshare_app/features/expenses/domain/entities/expense_entity.dart';
import 'package:fairshare_app/features/expenses/domain/entities/expense_share_entity.dart';
import 'package:fairshare_app/features/groups/data/services/firestore_group_service.dart';
import 'package:fairshare_app/features/groups/domain/entities/group_entity.dart';
import 'package:fairshare_app/features/groups/domain/entities/group_member_entity.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:result_dart/result_dart.dart';

import 'realtime_sync_service_test.mocks.dart';

@GenerateMocks([
  AppDatabase,
  FirestoreGroupService,
  FirestoreExpenseService,
  GroupsDao,
  ExpensesDao,
  ExpenseSharesDao,
  UserDao,
  EventBroker,
])
void main() {
  late MockAppDatabase mockDatabase;
  late MockFirestoreGroupService mockGroupService;
  late MockFirestoreExpenseService mockExpenseService;
  late MockGroupsDao mockGroupsDao;
  late MockExpensesDao mockExpensesDao;
  late MockExpenseSharesDao mockExpenseSharesDao;
  late MockUserDao mockUserDao;
  late MockEventBroker mockEventBroker;
  late RealtimeSyncService service;

  setUp(() {
    mockDatabase = MockAppDatabase();
    mockGroupService = MockFirestoreGroupService();
    mockExpenseService = MockFirestoreExpenseService();
    mockGroupsDao = MockGroupsDao();
    mockExpensesDao = MockExpensesDao();
    mockExpenseSharesDao = MockExpenseSharesDao();
    mockUserDao = MockUserDao();
    mockEventBroker = MockEventBroker();

    // Provide dummy values for Result types
    provideDummy<ResultDart<List<GroupMemberEntity>, Exception>>(
        Success(<GroupMemberEntity>[]));
    provideDummy<ResultDart<List<ExpenseEntity>, Exception>>(
        Success(<ExpenseEntity>[]));
    provideDummy<ResultDart<List<ExpenseShareEntity>, Exception>>(Success([]));

    // Stub the DAO getters on the database mock - this must be done BEFORE any method calls
    when(mockDatabase.groupsDao).thenReturn(mockGroupsDao);
    when(mockDatabase.expensesDao).thenReturn(mockExpensesDao);
    when(mockDatabase.expenseSharesDao).thenReturn(mockExpenseSharesDao);
    when(mockDatabase.userDao).thenReturn(mockUserDao);

    service = RealtimeSyncService(
      database: mockDatabase,
      groupService: mockGroupService,
      expenseService: mockExpenseService,
      eventBroker: mockEventBroker,
    );
  });

  tearDown(() async {
    await service.stopRealtimeSync();
  });

  group('RealtimeSyncService', () {
    final testGroup = GroupEntity(
      id: 'group123',
      displayName: 'Test Group',
      avatarUrl: '',
      isPersonal: false,
      defaultCurrency: 'USD',
      createdAt: DateTime(2025, 1, 1),
      updatedAt: DateTime(2025, 1, 1),
      lastActivityAt: DateTime(2025, 1, 1),
      deletedAt: null,
    );

    group('startRealtimeSync', () {
      test('should start global listener for user groups', () async {
        // Arrange
        final controller = StreamController<List<GroupEntity>>();
        when(
          mockGroupService.watchUserGroups('user123'),
        ).thenAnswer((_) => controller.stream);

        // Act
        await service.startRealtimeSync('user123');

        // Assert
        verify(mockGroupService.watchUserGroups('user123')).called(1);
        final status = service.getStatus();
        expect(status['userId'], 'user123');
        expect(status['globalListenerActive'], true);

        // Cleanup
        await controller.close();
      });

      test('should not start duplicate listener for same user', () async {
        // Arrange
        final controller = StreamController<List<GroupEntity>>();
        when(
          mockGroupService.watchUserGroups('user123'),
        ).thenAnswer((_) => controller.stream);

        // Act
        await service.startRealtimeSync('user123');
        await service.startRealtimeSync('user123'); // Second call

        // Assert
        verify(mockGroupService.watchUserGroups('user123')).called(1);

        // Cleanup
        await controller.close();
      });
    });

    group('stopRealtimeSync', () {
      test('should cancel all active listeners', () async {
        // Arrange
        final groupsController = StreamController<List<GroupEntity>>();
        final expensesController = StreamController<List<ExpenseEntity>>();

        when(
          mockGroupService.watchUserGroups('user123'),
        ).thenAnswer((_) => groupsController.stream);
        when(
          mockExpenseService.watchGroupExpenses('group123'),
        ).thenAnswer((_) => expensesController.stream);

        await service.startRealtimeSync('user123');
        service.listenToActiveGroup('group123');

        // Act
        await service.stopRealtimeSync();

        // Assert
        final status = service.getStatus();
        expect(status['globalListenerActive'], false);
        expect(status['activeGroupListenerActive'], false);
        expect(status['userId'], null);

        // Cleanup
        await groupsController.close();
        await expensesController.close();
      });
    });

    group('listenToActiveGroup', () {
      test('should start expense listener for active group', () async {
        // Arrange
        final controller = StreamController<List<ExpenseEntity>>();
        when(
          mockExpenseService.watchGroupExpenses('group123'),
        ).thenAnswer((_) => controller.stream);

        // Act
        service.listenToActiveGroup('group123');

        // Assert
        verify(mockExpenseService.watchGroupExpenses('group123')).called(1);
        final status = service.getStatus();
        expect(status['activeGroupId'], 'group123');
        expect(status['activeGroupListenerActive'], true);

        // Cleanup
        await controller.close();
      });

      test('should cancel previous listener when switching groups', () async {
        // Arrange
        final controller1 = StreamController<List<ExpenseEntity>>();
        final controller2 = StreamController<List<ExpenseEntity>>();

        when(
          mockExpenseService.watchGroupExpenses('group1'),
        ).thenAnswer((_) => controller1.stream);
        when(
          mockExpenseService.watchGroupExpenses('group2'),
        ).thenAnswer((_) => controller2.stream);

        // Act
        service.listenToActiveGroup('group1');
        service.listenToActiveGroup('group2');

        // Assert
        verify(mockExpenseService.watchGroupExpenses('group1')).called(1);
        verify(mockExpenseService.watchGroupExpenses('group2')).called(1);
        final status = service.getStatus();
        expect(status['activeGroupId'], 'group2');

        // Cleanup
        await controller1.close();
        await controller2.close();
      });
    });

    group('stopListeningToActiveGroup', () {
      test('should cancel active group listener', () async {
        // Arrange
        final controller = StreamController<List<ExpenseEntity>>();
        when(
          mockExpenseService.watchGroupExpenses('group123'),
        ).thenAnswer((_) => controller.stream);

        service.listenToActiveGroup('group123');

        // Act
        service.stopListeningToActiveGroup();

        // Assert
        final status = service.getStatus();
        expect(status['activeGroupListenerActive'], false);
        expect(status['activeGroupId'], null);

        // Cleanup
        await controller.close();
      });
    });

    group('group sync processing', () {
      test(
        'should upsert groups and sync members when groups change',
        () async {
          // Arrange
          final controller = StreamController<List<GroupEntity>>();
          when(mockGroupService.watchUserGroups('user123'))
              .thenAnswer((_) => controller.stream);
          when(mockGroupsDao.getGroupById(any))
              .thenAnswer((_) async => null);
          when(mockGroupsDao.upsertGroupFromSync(any, any))
              .thenAnswer((_) async {});
          when(mockGroupService.downloadGroupMembers(any))
              .thenAnswer((_) async => Success(<GroupMemberEntity>[]));

          // Act
          await service.startRealtimeSync('user123');
          controller.add([testGroup]);
          await Future.delayed(
            Duration(milliseconds: 100),
          ); // Wait for processing

          // Assert
          verify(mockGroupsDao.upsertGroupFromSync(testGroup, any)).called(1);
          verify(mockGroupService.downloadGroupMembers('group123')).called(1);

          // Cleanup
          await controller.close();
        },
      );

      test('should detect new activity on inactive groups', () async {
        // Arrange
        final oldGroup = testGroup;
        final newGroup = testGroup.copyWith(
          lastActivityAt: DateTime(2025, 1, 2), // New activity
        );

        final controller = StreamController<List<GroupEntity>>();
        when(mockGroupService.watchUserGroups('user123'))
            .thenAnswer((_) => controller.stream);
        when(mockGroupsDao.getGroupById(any))
            .thenAnswer((_) async => oldGroup);
        when(mockGroupsDao.upsertGroupFromSync(any, any))
            .thenAnswer((_) async {});
        when(mockGroupService.downloadGroupMembers(any))
            .thenAnswer((_) async => Success(<GroupMemberEntity>[]));
        when(mockExpenseService.downloadGroupExpenses(any))
            .thenAnswer((_) async => Success(<ExpenseEntity>[]));

        // Act
        await service.startRealtimeSync('user123');
        controller.add([newGroup]);
        await Future.delayed(Duration(milliseconds: 100));

        // Assert
        verify(mockExpenseService.downloadGroupExpenses('group123')).called(1);
        final status = service.getStatus();
        expect(
          status['groupsNeedingRefresh'],
          0,
        ); // Should be removed after fetch

        // Cleanup
        await controller.close();
      });
    });

    group('expense sync processing', () {
      final testExpense = ExpenseEntity(
        id: 'expense123',
        groupId: 'group123',
        title: 'Test Expense',
        amount: 100.0,
        currency: 'USD',
        paidBy: 'user1',
        shareWithEveryone: true,
        expenseDate: DateTime(2025, 1, 1),
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 1),
        deletedAt: null,
      );

      test('should upsert expenses when active group changes', () async {
        // Arrange
        final controller = StreamController<List<ExpenseEntity>>();
        when(mockExpenseService.watchGroupExpenses('group123'))
            .thenAnswer((_) => controller.stream);
        when(mockExpensesDao.upsertExpenseFromSync(any, any))
            .thenAnswer((_) async {});
        when(mockExpenseService.downloadExpenseShares(any, any))
            .thenAnswer((_) async => Success([]));

        // Act
        service.listenToActiveGroup('group123');
        controller.add([testExpense]);
        await Future.delayed(Duration(milliseconds: 100));

        // Assert
        verify(mockExpensesDao.upsertExpenseFromSync(testExpense, any)).called(1);
        verify(
          mockExpenseService.downloadExpenseShares('group123', 'expense123'),
        ).called(1);

        // Cleanup
        await controller.close();
      });
    });

    group('getStatus', () {
      test('should return correct status information', () async {
        // Arrange
        final groupsController = StreamController<List<GroupEntity>>();
        final expensesController = StreamController<List<ExpenseEntity>>();

        when(
          mockGroupService.watchUserGroups('user123'),
        ).thenAnswer((_) => groupsController.stream);
        when(
          mockExpenseService.watchGroupExpenses('group456'),
        ).thenAnswer((_) => expensesController.stream);

        // Act
        await service.startRealtimeSync('user123');
        service.listenToActiveGroup('group456');

        final status = service.getStatus();

        // Assert
        expect(status['userId'], 'user123');
        expect(status['globalListenerActive'], true);
        expect(status['activeGroupId'], 'group456');
        expect(status['activeGroupListenerActive'], true);

        // Cleanup
        await groupsController.close();
        await expensesController.close();
      });
    });

    group('Integration scenarios', () {
      test(
        'should handle complete flow: user creates group and adds expense',
        () async {
          // Arrange - User creates account
          final user1 = GroupMemberEntity(
            groupId: 'group789',
            userId: 'user1',
            joinedAt: DateTime(2025, 1, 1),
          );

          final newGroup = GroupEntity(
            id: 'group789',
            displayName: 'Trip to Paris',
            avatarUrl: '',
            isPersonal: false,
            defaultCurrency: 'EUR',
            createdAt: DateTime(2025, 1, 1),
            updatedAt: DateTime(2025, 1, 1),
            lastActivityAt: DateTime(2025, 1, 1),
            deletedAt: null,
          );

          final newExpense = ExpenseEntity(
            id: 'expense789',
            groupId: 'group789',
            title: 'Hotel Booking',
            amount: 300.0,
            currency: 'EUR',
            paidBy: 'user1',
            shareWithEveryone: true,
            expenseDate: DateTime(2025, 1, 2),
            createdAt: DateTime(2025, 1, 2),
            updatedAt: DateTime(2025, 1, 2),
            deletedAt: null,
          );

          final groupsController = StreamController<List<GroupEntity>>();
          final expensesController = StreamController<List<ExpenseEntity>>();

          when(mockGroupService.watchUserGroups('user1'))
              .thenAnswer((_) => groupsController.stream);
          when(mockExpenseService.watchGroupExpenses('group789'))
              .thenAnswer((_) => expensesController.stream);
          when(mockGroupsDao.getGroupById(any))
              .thenAnswer((_) async => null);
          when(mockGroupsDao.upsertGroupFromSync(any, any))
              .thenAnswer((_) async {});
          when(mockGroupService.downloadGroupMembers(any))
              .thenAnswer((_) async => Success([user1]));
          when(mockExpensesDao.upsertExpenseFromSync(any, any))
              .thenAnswer((_) async {});
          when(mockExpenseService.downloadExpenseShares(any, any))
              .thenAnswer((_) async => Success([]));

          // Act - Start sync and simulate group creation
          await service.startRealtimeSync('user1');
          groupsController.add([newGroup]);
          await Future.delayed(Duration(milliseconds: 100));

          // User activates the group
          service.listenToActiveGroup('group789');

          // User adds an expense
          expensesController.add([newExpense]);
          await Future.delayed(Duration(milliseconds: 100));

          // Assert
          verify(mockGroupsDao.upsertGroupFromSync(newGroup, any)).called(1);
          verify(mockGroupService.downloadGroupMembers('group789')).called(1);
          verify(mockExpensesDao.upsertExpenseFromSync(newExpense, any)).called(1);
          verify(
            mockExpenseService.downloadExpenseShares('group789', 'expense789'),
          ).called(1);

          final status = service.getStatus();
          expect(status['userId'], 'user1');
          expect(status['activeGroupId'], 'group789');
          expect(status['globalListenerActive'], true);
          expect(status['activeGroupListenerActive'], true);

          // Cleanup
          await groupsController.close();
          await expensesController.close();
        },
      );

      test(
        'should handle two users joining a group and adding expenses',
        () async {
          // Arrange - Two users
          final user1Member = GroupMemberEntity(
            groupId: 'group999',
            userId: 'user1',
            joinedAt: DateTime(2025, 1, 1),
          );

          final user2Member = GroupMemberEntity(
            groupId: 'group999',
            userId: 'user2',
            joinedAt: DateTime(2025, 1, 2),
          );

          final sharedGroup = GroupEntity(
            id: 'group999',
            displayName: 'Shared Expenses',
            avatarUrl: '',
            isPersonal: false,
            defaultCurrency: 'USD',
            createdAt: DateTime(2025, 1, 1),
            updatedAt: DateTime(2025, 1, 1),
            lastActivityAt: DateTime(2025, 1, 1),
            deletedAt: null,
          );

          final expense1 = ExpenseEntity(
            id: 'expense1',
            groupId: 'group999',
            title: 'Groceries',
            amount: 50.0,
            currency: 'USD',
            paidBy: 'user1',
            shareWithEveryone: true,
            expenseDate: DateTime(2025, 1, 3),
            createdAt: DateTime(2025, 1, 3),
            updatedAt: DateTime(2025, 1, 3),
            deletedAt: null,
          );

          final expense2 = ExpenseEntity(
            id: 'expense2',
            groupId: 'group999',
            title: 'Gas',
            amount: 40.0,
            currency: 'USD',
            paidBy: 'user2',
            shareWithEveryone: true,
            expenseDate: DateTime(2025, 1, 4),
            createdAt: DateTime(2025, 1, 4),
            updatedAt: DateTime(2025, 1, 4),
            deletedAt: null,
          );

          final groupsController1 = StreamController<List<GroupEntity>>();
          final groupsController2 = StreamController<List<GroupEntity>>();
          final expensesController1 = StreamController<List<ExpenseEntity>>.broadcast();

          // Setup mocks for both users
          when(mockGroupService.watchUserGroups('user1'))
              .thenAnswer((_) => groupsController1.stream);
          when(mockGroupService.watchUserGroups('user2'))
              .thenAnswer((_) => groupsController2.stream);
          when(mockExpenseService.watchGroupExpenses('group999'))
              .thenAnswer((_) => expensesController1.stream);
          when(mockGroupsDao.getGroupById(any))
              .thenAnswer((_) async => null);
          when(mockGroupsDao.upsertGroupFromSync(any, any))
              .thenAnswer((_) async {});
          when(mockGroupService.downloadGroupMembers(any))
              .thenAnswer((_) async => Success([user1Member, user2Member]));
          when(mockExpensesDao.upsertExpenseFromSync(any, any))
              .thenAnswer((_) async {});
          when(mockExpenseService.downloadExpenseShares(any, any))
              .thenAnswer((_) async => Success([]));

          // Act - User1 starts sync and creates group
          await service.startRealtimeSync('user1');
          groupsController1.add([sharedGroup]);
          await Future.delayed(Duration(milliseconds: 50));

          // User1 activates the group and adds expense
          service.listenToActiveGroup('group999');
          expensesController1.add([expense1]);
          await Future.delayed(Duration(milliseconds: 50));

          // Stop user1's sync
          await service.stopRealtimeSync();

          // User2 starts sync - should see the group and expense
          await service.startRealtimeSync('user2');
          groupsController2.add([sharedGroup]);
          await Future.delayed(Duration(milliseconds: 50));

          // User2 activates the group
          service.listenToActiveGroup('group999');

          // User2 adds another expense - both expenses visible
          expensesController1.add([expense1, expense2]);
          await Future.delayed(Duration(milliseconds: 50));

          // Assert
          // Group was synced for both users
          verify(mockGroupsDao.upsertGroupFromSync(sharedGroup, any)).called(2);

          // Members were downloaded when group synced
          verify(mockGroupService.downloadGroupMembers('group999'))
              .called(greaterThanOrEqualTo(2));

          // Both expenses were synced
          verify(mockExpensesDao.upsertExpenseFromSync(expense1, any)).called(2);
          verify(mockExpensesDao.upsertExpenseFromSync(expense2, any)).called(1);

          // Expense shares were downloaded
          verify(mockExpenseService.downloadExpenseShares('group999', any))
              .called(greaterThanOrEqualTo(2));

          final status = service.getStatus();
          expect(status['userId'], 'user2');
          expect(status['activeGroupId'], 'group999');

          // Cleanup
          await groupsController1.close();
          await groupsController2.close();
          await expensesController1.close();
        },
      );
    });
  });
}
