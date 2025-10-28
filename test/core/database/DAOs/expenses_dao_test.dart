import 'package:drift/native.dart';
import 'package:fairshare_app/core/database/app_database.dart';
import 'package:fairshare_app/core/events/event_broker.dart';
import 'package:fairshare_app/features/expenses/domain/entities/expense_entity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late EventBroker eventBroker;

  setUp(() {
    // Create in-memory database for testing
    database = AppDatabase.forTesting(NativeDatabase.memory());
    eventBroker = EventBroker();
  });

  tearDown(() async {
    await database.close();
    eventBroker.dispose();
  });

  group('ExpensesDao', () {
    test('insertExpense should insert expense into database', () async {
      // Arrange
      final expense = ExpenseEntity(
        id: 'exp1',
        groupId: 'group1',
        title: 'Test Expense',
        amount: 100.0,
        currency: 'USD',
        paidBy: 'user1',
        shareWithEveryone: true,
        expenseDate: DateTime(2025, 1, 1),
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 1),
      );

      // Act
      await database.expensesDao.insertExpense(expense);

      // Assert
      final retrieved = await database.expensesDao.getExpenseById('exp1');
      expect(retrieved, isNotNull);
      expect(retrieved!.id, 'exp1');
      expect(retrieved.title, 'Test Expense');
      expect(retrieved.amount, 100.0);
    });

    test('getExpenseById should return null for non-existent expense',
        () async {
      // Act
      final result = await database.expensesDao.getExpenseById('nonexistent');

      // Assert
      expect(result, isNull);
    });

    test('getExpenseById should exclude soft-deleted expenses by default',
        () async {
      // Arrange
      final expense = ExpenseEntity(
        id: 'exp1',
        groupId: 'group1',
        title: 'Deleted Expense',
        amount: 50.0,
        currency: 'USD',
        paidBy: 'user1',
        shareWithEveryone: true,
        expenseDate: DateTime(2025, 1, 1),
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 1),
      );
      await database.expensesDao.insertExpense(expense);
      await database.expensesDao.softDeleteExpense('exp1');

      // Act
      final result = await database.expensesDao.getExpenseById('exp1');

      // Assert
      expect(result, isNull);
    });

    test('getExpenseById should include soft-deleted when includeDeleted=true',
        () async {
      // Arrange
      final expense = ExpenseEntity(
        id: 'exp1',
        groupId: 'group1',
        title: 'Deleted Expense',
        amount: 50.0,
        currency: 'USD',
        paidBy: 'user1',
        shareWithEveryone: true,
        expenseDate: DateTime(2025, 1, 1),
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 1),
      );
      await database.expensesDao.insertExpense(expense);
      await database.expensesDao.softDeleteExpense('exp1');

      // Act
      final result =
          await database.expensesDao.getExpenseById('exp1', includeDeleted: true);

      // Assert
      expect(result, isNotNull);
      expect(result!.deletedAt, isNotNull);
    });

    test('getExpensesByGroup should return expenses for specific group',
        () async {
      // Arrange
      final expense1 = ExpenseEntity(
        id: 'exp1',
        groupId: 'group1',
        title: 'Group 1 Expense',
        amount: 100.0,
        currency: 'USD',
        paidBy: 'user1',
        shareWithEveryone: true,
        expenseDate: DateTime(2025, 1, 1),
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 1),
      );
      final expense2 = ExpenseEntity(
        id: 'exp2',
        groupId: 'group2',
        title: 'Group 2 Expense',
        amount: 50.0,
        currency: 'USD',
        paidBy: 'user1',
        shareWithEveryone: true,
        expenseDate: DateTime(2025, 1, 2),
        createdAt: DateTime(2025, 1, 2),
        updatedAt: DateTime(2025, 1, 2),
      );
      await database.expensesDao.insertExpense(expense1);
      await database.expensesDao.insertExpense(expense2);

      // Act
      final results = await database.expensesDao.getExpensesByGroup('group1');

      // Assert
      expect(results.length, 1);
      expect(results[0].id, 'exp1');
      expect(results[0].groupId, 'group1');
    });

    test('getAllExpenses should return all non-deleted expenses', () async {
      // Arrange
      final expense1 = ExpenseEntity(
        id: 'exp1',
        groupId: 'group1',
        title: 'Expense 1',
        amount: 100.0,
        currency: 'USD',
        paidBy: 'user1',
        shareWithEveryone: true,
        expenseDate: DateTime(2025, 1, 1),
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 1),
      );
      final expense2 = ExpenseEntity(
        id: 'exp2',
        groupId: 'group1',
        title: 'Expense 2',
        amount: 50.0,
        currency: 'USD',
        paidBy: 'user1',
        shareWithEveryone: true,
        expenseDate: DateTime(2025, 1, 2),
        createdAt: DateTime(2025, 1, 2),
        updatedAt: DateTime(2025, 1, 2),
      );
      await database.expensesDao.insertExpense(expense1);
      await database.expensesDao.insertExpense(expense2);

      // Act
      final results = await database.expensesDao.getAllExpenses();

      // Assert
      expect(results.length, 2);
    });

    test('updateExpense should update existing expense', () async {
      // Arrange
      final expense = ExpenseEntity(
        id: 'exp1',
        groupId: 'group1',
        title: 'Original Title',
        amount: 100.0,
        currency: 'USD',
        paidBy: 'user1',
        shareWithEveryone: true,
        expenseDate: DateTime(2025, 1, 1),
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 1),
      );
      await database.expensesDao.insertExpense(expense);

      final updated = expense.copyWith(
        title: 'Updated Title',
        amount: 200.0,
      );

      // Act
      await database.expensesDao.updateExpense(updated);

      // Assert
      final retrieved = await database.expensesDao.getExpenseById('exp1');
      expect(retrieved!.title, 'Updated Title');
      expect(retrieved.amount, 200.0);
    });

    test('deleteExpense should remove expense from database', () async {
      // Arrange
      final expense = ExpenseEntity(
        id: 'exp1',
        groupId: 'group1',
        title: 'To Delete',
        amount: 100.0,
        currency: 'USD',
        paidBy: 'user1',
        shareWithEveryone: true,
        expenseDate: DateTime(2025, 1, 1),
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 1),
      );
      await database.expensesDao.insertExpense(expense);

      // Act
      await database.expensesDao.deleteExpense('exp1');

      // Assert
      final retrieved =
          await database.expensesDao.getExpenseById('exp1', includeDeleted: true);
      expect(retrieved, isNull);
    });

    test('softDeleteExpense should mark expense as deleted', () async {
      // Arrange
      final expense = ExpenseEntity(
        id: 'exp1',
        groupId: 'group1',
        title: 'To Soft Delete',
        amount: 100.0,
        currency: 'USD',
        paidBy: 'user1',
        shareWithEveryone: true,
        expenseDate: DateTime(2025, 1, 1),
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 1),
      );
      await database.expensesDao.insertExpense(expense);

      // Act
      await database.expensesDao.softDeleteExpense('exp1');

      // Assert
      final retrieved =
          await database.expensesDao.getExpenseById('exp1', includeDeleted: true);
      expect(retrieved, isNotNull);
      expect(retrieved!.deletedAt, isNotNull);
    });

    test('restoreExpense should restore soft-deleted expense', () async {
      // Arrange
      final expense = ExpenseEntity(
        id: 'exp1',
        groupId: 'group1',
        title: 'To Restore',
        amount: 100.0,
        currency: 'USD',
        paidBy: 'user1',
        shareWithEveryone: true,
        expenseDate: DateTime(2025, 1, 1),
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 1),
      );
      await database.expensesDao.insertExpense(expense);
      await database.expensesDao.softDeleteExpense('exp1');

      // Act
      await database.expensesDao.restoreExpense('exp1');

      // Assert
      final retrieved = await database.expensesDao.getExpenseById('exp1');
      expect(retrieved, isNotNull);
      expect(retrieved!.deletedAt, isNull);
    });

    test('upsertExpenseFromSync should insert new expense', () async {
      // Arrange
      final expense = ExpenseEntity(
        id: 'exp1',
        groupId: 'group1',
        title: 'From Sync',
        amount: 100.0,
        currency: 'USD',
        paidBy: 'user1',
        shareWithEveryone: true,
        expenseDate: DateTime(2025, 1, 1),
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 1),
      );

      // Act
      await database.expensesDao.upsertExpenseFromSync(expense, eventBroker);

      // Assert
      final retrieved = await database.expensesDao.getExpenseById('exp1');
      expect(retrieved, isNotNull);
      expect(retrieved!.title, 'From Sync');
    });

    test('upsertExpenseFromSync should update if remote is newer', () async {
      // Arrange
      final oldExpense = ExpenseEntity(
        id: 'exp1',
        groupId: 'group1',
        title: 'Old Title',
        amount: 100.0,
        currency: 'USD',
        paidBy: 'user1',
        shareWithEveryone: true,
        expenseDate: DateTime(2025, 1, 1),
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 1),
      );
      await database.expensesDao.insertExpense(oldExpense);

      final newExpense = oldExpense.copyWith(
        title: 'New Title',
        updatedAt: DateTime(2025, 1, 2), // Newer timestamp
      );

      // Act
      await database.expensesDao.upsertExpenseFromSync(newExpense, eventBroker);

      // Assert
      final retrieved = await database.expensesDao.getExpenseById('exp1');
      expect(retrieved!.title, 'New Title');
    });

    test('upsertExpenseFromSync should not update if remote is older', () async {
      // Arrange
      final newExpense = ExpenseEntity(
        id: 'exp1',
        groupId: 'group1',
        title: 'New Title',
        amount: 100.0,
        currency: 'USD',
        paidBy: 'user1',
        shareWithEveryone: true,
        expenseDate: DateTime(2025, 1, 1),
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 2),
      );
      await database.expensesDao.insertExpense(newExpense);

      final oldExpense = newExpense.copyWith(
        title: 'Old Title',
        updatedAt: DateTime(2025, 1, 1), // Older timestamp
      );

      // Act
      await database.expensesDao.upsertExpenseFromSync(oldExpense, eventBroker);

      // Assert
      final retrieved = await database.expensesDao.getExpenseById('exp1');
      expect(retrieved!.title, 'New Title'); // Should keep newer local version
    });

    test('watchExpensesByGroup should return stream of expenses', () async {
      // Arrange
      final expense = ExpenseEntity(
        id: 'exp1',
        groupId: 'group1',
        title: 'Watch Test',
        amount: 100.0,
        currency: 'USD',
        paidBy: 'user1',
        shareWithEveryone: true,
        expenseDate: DateTime(2025, 1, 1),
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 1),
      );
      await database.expensesDao.insertExpense(expense);

      // Act
      final stream = database.expensesDao.watchExpensesByGroup('group1');
      final result = await stream.first;

      // Assert
      expect(result.length, 1);
      expect(result[0].id, 'exp1');
    });
  });
}
