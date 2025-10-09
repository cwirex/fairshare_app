import 'package:fairshare_app/core/database/app_database.dart';
import 'package:fairshare_app/features/expenses/domain/entities/expense_entity.dart';
import 'package:fairshare_app/features/expenses/domain/repositories/expense_repository.dart';
import 'package:result_dart/result_dart.dart';

/// Local implementation of ExpenseRepository using Drift database.
class LocalExpenseRepository implements ExpenseRepository {
  final AppDatabase _database;

  LocalExpenseRepository(this._database);

  @override
  Future<Result<ExpenseEntity>> createExpense(ExpenseEntity expense) async {
    try {
      await _database.transaction(() async {
        await _database.expensesDao.insertExpense(expense);

        // All expenses are synced (personal group expenses too - for backup)
        await _database.syncDao.enqueueOperation(
          entityType: 'expense',
          entityId: expense.id,
          operationType: 'create',
        );
      });
      return Success(expense);
    } catch (e) {
      return Failure(Exception('Failed to create expense: $e'));
    }
  }

  @override
  Future<Result<ExpenseEntity>> getExpenseById(String id) async {
    try {
      final expense = await _database.expensesDao.getExpenseById(id);
      if (expense == null) {
        return Failure(Exception('Expense not found: $id'));
      }
      return Success(expense);
    } catch (e) {
      return Failure(Exception('Failed to get expense: $e'));
    }
  }

  @override
  Future<Result<List<ExpenseEntity>>> getExpensesByGroup(String groupId) async {
    try {
      final expenses = await _database.expensesDao.getExpensesByGroup(groupId);
      return Success(expenses);
    } catch (e) {
      return Failure(Exception('Failed to get expenses by group: $e'));
    }
  }

  @override
  Future<Result<List<ExpenseEntity>>> getAllExpenses() async {
    try {
      final expenses = await _database.expensesDao.getAllExpenses();
      return Success(expenses);
    } catch (e) {
      return Failure(Exception('Failed to get all expenses: $e'));
    }
  }

  @override
  Future<Result<ExpenseEntity>> updateExpense(ExpenseEntity expense) async {
    try {
      await _database.transaction(() async {
        await _database.expensesDao.updateExpense(expense);

        // All expenses are synced (personal group expenses too - for backup)
        await _database.syncDao.enqueueOperation(
          entityType: 'expense',
          entityId: expense.id,
          operationType: 'update',
        );
      });
      return Success(expense);
    } catch (e) {
      return Failure(Exception('Failed to update expense: $e'));
    }
  }

  @override
  Future<Result<void>> deleteExpense(String id) async {
    try {
      await _database.transaction(() async {
        // Get expense to retrieve groupId before deleting
        final expense = await _database.expensesDao.getExpenseById(id);
        final metadata =
            expense != null ? '{"groupId":"${expense.groupId}"}' : null;

        // All expenses are synced (personal group expenses too - for backup)
        await _database.syncDao.enqueueOperation(
          entityType: 'expense',
          entityId: id,
          operationType: 'delete',
          metadata: metadata,
        );

        await _database.expensesDao.deleteExpense(id);
      });
      return Success.unit();
    } catch (e) {
      return Failure(Exception('Failed to delete expense: $e'));
    }
  }

  @override
  Stream<List<ExpenseEntity>> watchExpensesByGroup(String groupId) {
    return _database.expensesDao.watchExpensesByGroup(groupId);
  }

  @override
  Stream<List<ExpenseEntity>> watchAllExpenses() {
    return _database.expensesDao.watchAllExpenses();
  }
}
