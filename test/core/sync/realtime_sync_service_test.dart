import 'dart:async';

import 'package:fairshare_app/core/database/app_database.dart';
import 'package:fairshare_app/core/sync/realtime_sync_service.dart';
import 'package:fairshare_app/features/expenses/data/services/firestore_expense_service.dart';
import 'package:fairshare_app/features/expenses/domain/entities/expense_entity.dart';
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
])
void main() {
  late MockAppDatabase mockDatabase;
  late MockFirestoreGroupService mockGroupService;
  late MockFirestoreExpenseService mockExpenseService;
  late RealtimeSyncService service;

  setUp(() {
    mockDatabase = MockAppDatabase();
    mockGroupService = MockFirestoreGroupService();
    mockExpenseService = MockFirestoreExpenseService();

    service = RealtimeSyncService(
      database: mockDatabase,
      groupService: mockGroupService,
      expenseService: mockExpenseService,
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
        when(mockGroupService.watchUserGroups('user123'))
            .thenAnswer((_) => controller.stream);

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
        when(mockGroupService.watchUserGroups('user123'))
            .thenAnswer((_) => controller.stream);

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

        when(mockGroupService.watchUserGroups('user123'))
            .thenAnswer((_) => groupsController.stream);
        when(mockExpenseService.watchGroupExpenses('group123'))
            .thenAnswer((_) => expensesController.stream);

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
        when(mockExpenseService.watchGroupExpenses('group123'))
            .thenAnswer((_) => controller.stream);

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

        when(mockExpenseService.watchGroupExpenses('group1'))
            .thenAnswer((_) => controller1.stream);
        when(mockExpenseService.watchGroupExpenses('group2'))
            .thenAnswer((_) => controller2.stream);

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
        when(mockExpenseService.watchGroupExpenses('group123'))
            .thenAnswer((_) => controller.stream);

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
      test('should upsert groups and sync members when groups change',
          () async {
        // Arrange
        final controller = StreamController<List<GroupEntity>>();
        when(mockGroupService.watchUserGroups('user123'))
            .thenAnswer((_) => controller.stream);
        when(mockDatabase.getGroupById('group123'))
            .thenAnswer((_) async => null);
        when(mockDatabase.upsertGroupFromSync(any))
            .thenAnswer((_) async {});
        when(mockGroupService.downloadGroupMembers('group123'))
            .thenAnswer((_) async => Success(<GroupMemberEntity>[]));

        // Act
        await service.startRealtimeSync('user123');
        controller.add([testGroup]);
        await Future.delayed(Duration(milliseconds: 100)); // Wait for processing

        // Assert
        verify(mockDatabase.upsertGroupFromSync(testGroup)).called(1);
        verify(mockGroupService.downloadGroupMembers('group123')).called(1);

        // Cleanup
        await controller.close();
      });

      test('should detect new activity on inactive groups', () async {
        // Arrange
        final oldGroup = testGroup;
        final newGroup = testGroup.copyWith(
          lastActivityAt: DateTime(2025, 1, 2), // New activity
        );

        final controller = StreamController<List<GroupEntity>>();
        when(mockGroupService.watchUserGroups('user123'))
            .thenAnswer((_) => controller.stream);
        when(mockDatabase.getGroupById('group123'))
            .thenAnswer((_) async => oldGroup);
        when(mockDatabase.upsertGroupFromSync(any))
            .thenAnswer((_) async {});
        when(mockGroupService.downloadGroupMembers('group123'))
            .thenAnswer((_) async => Success(<GroupMemberEntity>[]));
        when(mockExpenseService.downloadGroupExpenses('group123'))
            .thenAnswer((_) async => Success(<ExpenseEntity>[]));

        // Act
        await service.startRealtimeSync('user123');
        controller.add([newGroup]);
        await Future.delayed(Duration(milliseconds: 100));

        // Assert
        verify(mockExpenseService.downloadGroupExpenses('group123')).called(1);
        final status = service.getStatus();
        expect(status['groupsNeedingRefresh'], 0); // Should be removed after fetch

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
        when(mockDatabase.upsertExpenseFromSync(any))
            .thenAnswer((_) async {});
        when(mockExpenseService.downloadExpenseShares('group123', 'expense123'))
            .thenAnswer((_) async => Success([]));

        // Act
        service.listenToActiveGroup('group123');
        controller.add([testExpense]);
        await Future.delayed(Duration(milliseconds: 100));

        // Assert
        verify(mockDatabase.upsertExpenseFromSync(testExpense)).called(1);
        verify(mockExpenseService.downloadExpenseShares('group123', 'expense123'))
            .called(1);

        // Cleanup
        await controller.close();
      });
    });

    group('getStatus', () {
      test('should return correct status information', () async {
        // Arrange
        final groupsController = StreamController<List<GroupEntity>>();
        final expensesController = StreamController<List<ExpenseEntity>>();

        when(mockGroupService.watchUserGroups('user123'))
            .thenAnswer((_) => groupsController.stream);
        when(mockExpenseService.watchGroupExpenses('group456'))
            .thenAnswer((_) => expensesController.stream);

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
  });
}
