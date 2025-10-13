import 'dart:async';

import 'package:drift/native.dart';
import 'package:fairshare_app/core/database/app_database.dart';
import 'package:fairshare_app/core/events/event_broker.dart';
import 'package:fairshare_app/core/events/expense_events.dart';
import 'package:fairshare_app/features/expenses/data/repositories/synced_expense_repository.dart';
import 'package:fairshare_app/features/expenses/domain/entities/expense_entity.dart';
import 'package:fairshare_app/features/expenses/domain/use_cases/create_expense_use_case.dart';
import 'package:fairshare_app/features/expenses/domain/use_cases/delete_expense_use_case.dart';
import 'package:fairshare_app/features/expenses/domain/use_cases/get_expense_use_case.dart';
import 'package:fairshare_app/features/expenses/domain/use_cases/update_expense_use_case.dart';
import 'package:flutter_test/flutter_test.dart';

/// Integration test for complete expense flow:
/// Use Case → Repository → Database → Events
void main() {
  late AppDatabase database;
  late EventBroker eventBroker;
  late SyncedExpenseRepository repository;
  late CreateExpenseUseCase createUseCase;
  late GetExpenseUseCase getUseCase;
  late UpdateExpenseUseCase updateUseCase;
  late DeleteExpenseUseCase deleteUseCase;
  StreamSubscription<ExpenseCreated>? createdSub;
  StreamSubscription<ExpenseUpdated>? updatedSub;
  StreamSubscription<ExpenseDeleted>? deletedSub;

  setUp(() async {
    // Create in-memory database for testing
    database = AppDatabase.forTesting(NativeDatabase.memory());
    eventBroker = EventBroker(); // Singleton instance

    // Create repository
    repository = SyncedExpenseRepository(database, eventBroker);

    // Create use cases
    createUseCase = CreateExpenseUseCase(repository);
    getUseCase = GetExpenseUseCase(repository);
    updateUseCase = UpdateExpenseUseCase(repository);
    deleteUseCase = DeleteExpenseUseCase(repository);
  });

  tearDown(() async {
    await createdSub?.cancel();
    await updatedSub?.cancel();
    await deletedSub?.cancel();
    await database.close();
    // Don't dispose EventBroker - it's a singleton shared across tests
  });

  group('Expense Flow Integration', () {
    test(
      'should create expense, store in DB, enqueue sync, and fire event',
      () async {
        // Arrange
        final expense = ExpenseEntity(
          id: 'test-expense-1',
          groupId: 'test-group-1',
          title: 'Test Expense',
          amount: 100.0,
          currency: 'USD',
          paidBy: 'user1',
          shareWithEveryone: true,
          expenseDate: DateTime(2025, 1, 1),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          deletedAt: null,
        );

        final eventFired = Completer<ExpenseCreated>();
        createdSub = eventBroker.on<ExpenseCreated>().listen((event) {
          if (!eventFired.isCompleted) {
            eventFired.complete(event);
          }
        });
        updatedSub = eventBroker.on<ExpenseUpdated>().listen((_) {});
        deletedSub = eventBroker.on<ExpenseDeleted>().listen((_) {});

        // Act
        final result = await createUseCase(expense);

        // Assert
        expect(result.isSuccess(), true);
        expect(result.getOrNull()!.id, expense.id);

        // Verify stored in database
        final storedExpense = await database.expensesDao.getExpenseById(
          expense.id,
        );
        expect(storedExpense, isNotNull);
        expect(storedExpense!.title, expense.title);
        expect(storedExpense.amount, expense.amount);

        // Verify sync operation was enqueued
        final syncOps = await database.syncDao.getPendingOperations();
        expect(syncOps.length, greaterThan(0));
        expect(
          syncOps.any((op) =>
            op.entityId == expense.id && op.operationType == 'create'),
          true,
        );

        // Verify event was fired
        final event = await eventFired.future
            .timeout(const Duration(seconds: 1));
        expect(event.expense.id, expense.id);
        expect(event.expense.title, expense.title);
      },
    );

    test(
      'should retrieve expense from database through use case',
      () async {
        // Arrange - Create expense first
        final expense = ExpenseEntity(
          id: 'test-expense-2',
          groupId: 'test-group-1',
          title: 'Retrieve Test',
          amount: 50.0,
          currency: 'USD',
          paidBy: 'user1',
          shareWithEveryone: true,
          expenseDate: DateTime(2025, 1, 2),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          deletedAt: null,
        );

        createdSub = eventBroker.on<ExpenseCreated>().listen((_) {});
        updatedSub = eventBroker.on<ExpenseUpdated>().listen((_) {});
        deletedSub = eventBroker.on<ExpenseDeleted>().listen((_) {});

        await createUseCase(expense);

        // Act
        final result = await getUseCase(expense.id);

        // Assert
        expect(result.isSuccess(), true);
        expect(result.getOrNull()!.id, expense.id);
        expect(result.getOrNull()!.title, expense.title);
      },
    );

    test(
      'should update expense, persist to DB, enqueue sync, and fire event',
      () async {
        // Arrange - Create expense first
        final expense = ExpenseEntity(
          id: 'test-expense-3',
          groupId: 'test-group-1',
          title: 'Original Title',
          amount: 75.0,
          currency: 'USD',
          paidBy: 'user1',
          shareWithEveryone: true,
          expenseDate: DateTime(2025, 1, 3),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          deletedAt: null,
        );

        createdSub = eventBroker.on<ExpenseCreated>().listen((_) {});
        deletedSub = eventBroker.on<ExpenseDeleted>().listen((_) {});

        final eventFired = Completer<ExpenseUpdated>();
        updatedSub = eventBroker.on<ExpenseUpdated>().listen((event) {
          if (!eventFired.isCompleted) {
            eventFired.complete(event);
          }
        });

        await createUseCase(expense);

        // Act - Update the expense
        final updatedExpense = expense.copyWith(title: 'Updated Title');
        final result = await updateUseCase(updatedExpense);

        // Assert
        expect(result.isSuccess(), true);

        // Verify updated in database
        final storedExpense = await database.expensesDao.getExpenseById(
          expense.id,
        );
        expect(storedExpense!.title, 'Updated Title');

        // Verify sync operation was enqueued
        final syncOps = await database.syncDao.getPendingOperations();
        expect(
          syncOps.any((op) =>
            op.entityId == expense.id && op.operationType == 'update'),
          true,
        );

        // Verify event was fired
        final event = await eventFired.future
            .timeout(const Duration(seconds: 1));
        expect(event.expense.id, expense.id);
        expect(event.expense.title, 'Updated Title');
      },
    );

    test(
      'should delete expense (soft delete), enqueue sync, and fire event',
      () async {
        // Arrange - Create expense first
        final expense = ExpenseEntity(
          id: 'test-expense-4',
          groupId: 'test-group-1',
          title: 'To Be Deleted',
          amount: 25.0,
          currency: 'USD',
          paidBy: 'user1',
          shareWithEveryone: true,
          expenseDate: DateTime(2025, 1, 4),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          deletedAt: null,
        );

        createdSub = eventBroker.on<ExpenseCreated>().listen((_) {});
        updatedSub = eventBroker.on<ExpenseUpdated>().listen((_) {});

        final eventFired = Completer<ExpenseDeleted>();
        deletedSub = eventBroker.on<ExpenseDeleted>().listen((event) {
          if (!eventFired.isCompleted) {
            eventFired.complete(event);
          }
        });

        await createUseCase(expense);

        // Act
        final result = await deleteUseCase(expense.id);

        // Assert
        expect(result.isSuccess(), true);

        // Verify soft deleted in database (deletedAt is set)
        final storedExpense = await database.expensesDao.getExpenseById(
          expense.id,
          includeDeleted: true,
        );
        expect(storedExpense, isNotNull);
        expect(storedExpense!.deletedAt, isNotNull);

        // Verify not returned in normal queries
        final normalQuery = await database.expensesDao.getExpenseById(
          expense.id,
        );
        expect(normalQuery, isNull);

        // Verify sync operation was enqueued
        final syncOps = await database.syncDao.getPendingOperations();
        expect(
          syncOps.any((op) =>
            op.entityId == expense.id && op.operationType == 'delete'),
          true,
        );

        // Verify event was fired
        final event = await eventFired.future
            .timeout(const Duration(seconds: 1));
        expect(event.expenseId, expense.id);
        expect(event.groupId, expense.groupId);
      },
    );

    test('should handle validation errors in use case', () async {
      // Arrange
      final invalidExpense = ExpenseEntity(
        id: 'test-expense-5',
        groupId: 'test-group-1',
        title: '', // Invalid: empty title
        amount: 100.0,
        currency: 'USD',
        paidBy: 'user1',
        shareWithEveryone: true,
        expenseDate: DateTime(2025, 1, 5),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        deletedAt: null,
      );

      createdSub = eventBroker.on<ExpenseCreated>().listen((_) {});
      updatedSub = eventBroker.on<ExpenseUpdated>().listen((_) {});
      deletedSub = eventBroker.on<ExpenseDeleted>().listen((_) {});

      // Act
      final result = await createUseCase(invalidExpense);

      // Assert
      expect(result.isError(), true);
      expect(
        result.exceptionOrNull()!.toString(),
        contains('Title is required'),
      );

      // Verify NOT stored in database
      final storedExpense = await database.expensesDao.getExpenseById(
        invalidExpense.id,
      );
      expect(storedExpense, isNull);

      // Verify NO sync operation was enqueued
      final syncOps = await database.syncDao.getPendingOperations();
      expect(
        syncOps.any((op) => op.entityId == invalidExpense.id),
        false,
      );
    });

    test(
      'should handle multiple expenses in same group',
      () async {
        // Arrange
        const groupId = 'test-group-multi';
        final expenses = List.generate(
          5,
          (i) => ExpenseEntity(
            id: 'expense-$i',
            groupId: groupId,
            title: 'Expense $i',
            amount: (i + 1) * 10.0,
            currency: 'USD',
            paidBy: 'user1',
            shareWithEveryone: true,
            expenseDate: DateTime(2025, 1, i + 1),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            deletedAt: null,
          ),
        );

        createdSub = eventBroker.on<ExpenseCreated>().listen((_) {});
        updatedSub = eventBroker.on<ExpenseUpdated>().listen((_) {});
        deletedSub = eventBroker.on<ExpenseDeleted>().listen((_) {});

        // Act - Create all expenses
        for (final expense in expenses) {
          final result = await createUseCase(expense);
          expect(result.isSuccess(), true);
        }

        // Assert - Retrieve all expenses for the group
        final storedExpenses = await database.expensesDao.getExpensesByGroup(
          groupId,
        );
        expect(storedExpenses.length, 5);
        expect(storedExpenses.map((e) => e.title).toList(), [
          'Expense 4',
          'Expense 3',
          'Expense 2',
          'Expense 1',
          'Expense 0',
        ]); // Ordered by date desc
      },
    );
  });
}
