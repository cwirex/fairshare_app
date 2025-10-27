import 'dart:async';

import 'package:fairshare_app/core/database/app_database.dart';
import 'package:fairshare_app/core/database/DAOs/expenses_dao.dart';
import 'package:fairshare_app/core/database/DAOs/expense_shares_dao.dart';
import 'package:fairshare_app/core/database/DAOs/groups_dao.dart';
import 'package:fairshare_app/core/database/database_provider.dart';
import 'package:fairshare_app/core/events/app_event.dart';
import 'package:fairshare_app/core/events/event_broker.dart';
import 'package:fairshare_app/core/events/event_providers.dart';
import 'package:fairshare_app/core/events/expense_events.dart';
import 'package:fairshare_app/features/balances/domain/entities/settlement_entity.dart';
import 'package:fairshare_app/features/balances/domain/services/balance_calculation_service.dart';
import 'package:fairshare_app/features/balances/presentation/providers/balance_providers.dart';
import 'package:fairshare_app/features/expenses/domain/entities/expense_entity.dart';
import 'package:fairshare_app/features/expenses/domain/entities/expense_share_entity.dart';
import 'package:fairshare_app/features/groups/domain/entities/group_member_entity.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'balance_providers_test.mocks.dart';

@GenerateMocks([
  AppDatabase,
  GroupsDao,
  ExpensesDao,
  ExpenseSharesDao,
  EventBroker,
])
void main() {
  late MockAppDatabase mockDatabase;
  late MockGroupsDao mockGroupsDao;
  late MockExpensesDao mockExpensesDao;
  late MockExpenseSharesDao mockExpenseSharesDao;
  late MockEventBroker mockEventBroker;
  late StreamController<AppEvent> eventController;
  late ProviderContainer container;

  // Test data
  final groupId = 'group123';
  final user1 = 'user1';
  final user2 = 'user2';

  final testMembers = [
    GroupMemberEntity(
      groupId: groupId,
      userId: user1,
      joinedAt: DateTime(2025, 1, 1),
    ),
    GroupMemberEntity(
      groupId: groupId,
      userId: user2,
      joinedAt: DateTime(2025, 1, 1),
    ),
  ];

  final testExpense = ExpenseEntity(
    id: 'exp1',
    groupId: groupId,
    title: 'Test Expense',
    amount: 100.0,
    currency: 'USD',
    paidBy: user1,
    expenseDate: DateTime(2025, 1, 1),
    createdAt: DateTime(2025, 1, 1),
    updatedAt: DateTime(2025, 1, 1),
  );

  final testShares = [
    ExpenseShareEntity(
      expenseId: 'exp1',
      userId: user1,
      shareAmount: 50.0,
    ),
    ExpenseShareEntity(
      expenseId: 'exp1',
      userId: user2,
      shareAmount: 50.0,
    ),
  ];

  setUp(() {
    mockDatabase = MockAppDatabase();
    mockGroupsDao = MockGroupsDao();
    mockExpensesDao = MockExpensesDao();
    mockExpenseSharesDao = MockExpenseSharesDao();
    mockEventBroker = MockEventBroker();
    eventController = StreamController<AppEvent>.broadcast();

    // Setup database mocks
    when(mockDatabase.groupsDao).thenReturn(mockGroupsDao);
    when(mockDatabase.expensesDao).thenReturn(mockExpensesDao);
    when(mockDatabase.expenseSharesDao).thenReturn(mockExpenseSharesDao);

    // Setup event broker mock
    when(mockEventBroker.stream).thenAnswer((_) => eventController.stream);

    // Setup default responses
    when(mockGroupsDao.getAllGroupMembers(any))
        .thenAnswer((_) async => testMembers);
    when(mockExpensesDao.getExpensesByGroup(any))
        .thenAnswer((_) async => [testExpense]);
    when(mockExpenseSharesDao.getSharesByGroup(any))
        .thenAnswer((_) async => testShares);

    // Create provider container with overrides
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(mockDatabase),
        eventBrokerProvider.overrideWithValue(mockEventBroker),
      ],
    );
  });

  tearDown(() {
    container.dispose();
    eventController.close();
  });

  group('GroupBalanceProvider', () {
    test('should calculate initial balances correctly', () async {
      // Arrange
      final provider = groupBalanceProvider(groupId);

      // Act - Read the provider and wait for first value
      final balancesFuture = container.read(provider.future);
      final balances = await balancesFuture;

      // Assert
      expect(balances, isA<Map<String, double>>());
      expect(balances.length, 2);
      expect(balances[user1], 50.0); // Paid 100, owes 50 = +50
      expect(balances[user2], -50.0); // Paid 0, owes 50 = -50

      // Verify DAOs were called
      verify(mockGroupsDao.getAllGroupMembers(groupId)).called(1);
      verify(mockExpensesDao.getExpensesByGroup(groupId)).called(1);
      verify(mockExpenseSharesDao.getSharesByGroup(groupId)).called(1);
    });

    test('should recalculate when ExpenseCreated event fires', () async {
      // Arrange
      final provider = groupBalanceProvider(groupId);

      // Wait for initial load
      final initial = await container.read(provider.future);
      expect(initial[user1], 50.0);

      // Update mock to return new expense
      final newExpense = testExpense.copyWith(
        id: 'exp2',
        amount: 60.0,
        paidBy: user2,
      );
      final newShares = [
        ExpenseShareEntity(expenseId: 'exp2', userId: user1, shareAmount: 30.0),
        ExpenseShareEntity(expenseId: 'exp2', userId: user2, shareAmount: 30.0),
      ];

      when(mockExpensesDao.getExpensesByGroup(groupId))
          .thenAnswer((_) async => [testExpense, newExpense]);
      when(mockExpenseSharesDao.getSharesByGroup(groupId))
          .thenAnswer((_) async => [...testShares, ...newShares]);

      // Act - Fire event
      eventController.add(ExpenseCreated(newExpense));

      // Wait for update to propagate
      await Future.delayed(Duration(milliseconds: 150));

      // Invalidate and re-read to get updated value
      container.invalidate(provider);
      await Future.delayed(Duration(milliseconds: 50));

      // Assert - Read updated value
      final updated = await container.read(provider.future);
      expect(updated[user1], 20.0); // Paid 100, owes 80 = +20
      expect(updated[user2], -20.0); // Paid 60, owes 80 = -20

      // Verify DAO was called again
      verify(mockExpensesDao.getExpensesByGroup(groupId)).called(greaterThanOrEqualTo(2));
    });

    test('should NOT recalculate for events from different group', () async {
      // Arrange
      final provider = groupBalanceProvider(groupId);

      await container.read(provider.future); // Get initial value

      // Clear verification
      clearInteractions(mockExpensesDao);

      // Act - Fire event for different group
      final differentExpense = testExpense.copyWith(
        groupId: 'different-group',
        id: 'exp-different',
      );
      eventController.add(ExpenseCreated(differentExpense));

      // Wait a bit to ensure no update
      await Future.delayed(Duration(milliseconds: 100));

      // Assert - Should not have called DAOs again
      verifyNever(mockExpensesDao.getExpensesByGroup(groupId));
    });

    test('should handle empty expenses list', () async {
      // Arrange
      when(mockExpensesDao.getExpensesByGroup(groupId))
          .thenAnswer((_) async => []);
      when(mockExpenseSharesDao.getSharesByGroup(groupId))
          .thenAnswer((_) async => []);

      final provider = groupBalanceProvider(groupId);

      // Act
      final balances = await container.read(provider.future);

      // Assert
      expect(balances[user1], 0.0);
      expect(balances[user2], 0.0);
    });
  });

  group('GroupSettlementsProvider', () {
    test('should calculate initial settlements correctly', () async {
      // Arrange
      final provider = groupSettlementsProvider(groupId);

      // Act
      final settlements = await container.read(provider.future);

      // Assert
      expect(settlements, isA<List<SettlementEntity>>());
      expect(settlements.length, 1);
      expect(settlements[0].from, user2);
      expect(settlements[0].to, user1);
      expect(settlements[0].amount, 50.0);
    });

    test('should return empty list when group is settled', () async {
      // Arrange - Setup balanced scenario
      when(mockExpensesDao.getExpensesByGroup(groupId))
          .thenAnswer((_) async => []);
      when(mockExpenseSharesDao.getSharesByGroup(groupId))
          .thenAnswer((_) async => []);

      final provider = groupSettlementsProvider(groupId);

      // Act
      final settlements = await container.read(provider.future);

      // Assert
      expect(settlements, isEmpty);
    });
  });

  group('GroupIsSettledProvider', () {
    test('should return false when balances exist', () async {
      // Arrange
      final provider = groupIsSettledProvider(groupId);

      // Act
      final isSettled = await container.read(provider.future);

      // Assert
      expect(isSettled, false);
    });

    test('should return true when all balances are zero', () async {
      // Arrange - No expenses
      when(mockExpensesDao.getExpensesByGroup(groupId))
          .thenAnswer((_) async => []);
      when(mockExpenseSharesDao.getSharesByGroup(groupId))
          .thenAnswer((_) async => []);

      final provider = groupIsSettledProvider(groupId);

      // Act
      final isSettled = await container.read(provider.future);

      // Assert
      expect(isSettled, true);
    });

    test('should handle floating point precision (epsilon)', () async {
      // Arrange - Setup near-zero balances
      final smallExpense = testExpense.copyWith(amount: 0.005);
      final smallShares = [
        ExpenseShareEntity(
          expenseId: 'exp1',
          userId: user1,
          shareAmount: 0.0025,
        ),
        ExpenseShareEntity(
          expenseId: 'exp1',
          userId: user2,
          shareAmount: 0.0025,
        ),
      ];

      when(mockExpensesDao.getExpensesByGroup(groupId))
          .thenAnswer((_) async => [smallExpense]);
      when(mockExpenseSharesDao.getSharesByGroup(groupId))
          .thenAnswer((_) async => smallShares);

      final provider = groupIsSettledProvider(groupId);

      // Act
      final isSettled = await container.read(provider.future);

      // Assert - Should be true because difference < epsilon (0.01)
      expect(isSettled, true);
    });
  });

  group('BalanceCalculationServiceProvider', () {
    test('should provide BalanceCalculationService instance', () {
      // Act
      final service = container.read(balanceCalculationServiceProvider);

      // Assert
      expect(service, isA<BalanceCalculationService>());
    });
  });
}
