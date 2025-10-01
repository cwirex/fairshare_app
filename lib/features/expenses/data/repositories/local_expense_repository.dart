import 'package:result_dart/result_dart.dart';

import 'package:fairshare_app/core/database/app_database.dart';
import 'package:fairshare_app/features/expenses/domain/entities/expense_entity.dart';
import 'package:fairshare_app/features/expenses/domain/repositories/expense_repository.dart';

/// Local implementation of ExpenseRepository using Drift database.
class LocalExpenseRepository implements ExpenseRepository {
  final AppDatabase _database;

  LocalExpenseRepository(this._database);

  @override
  Future<Result<ExpenseEntity>> createExpense(ExpenseEntity expense) async {
    try {
      await _database.insertExpense(expense);
      return Success(expense);
    } catch (e) {
      return Failure(Exception('Failed to create expense: $e'));
    }
  }

  @override
  Future<Result<ExpenseEntity>> getExpenseById(String id) async {
    try {
      final expense = await _database.getExpenseById(id);
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
      final expenses = await _database.getExpensesByGroup(groupId);
      return Success(expenses);
    } catch (e) {
      return Failure(Exception('Failed to get expenses by group: $e'));
    }
  }

  @override
  Future<Result<List<ExpenseEntity>>> getAllExpenses() async {
    try {
      final expenses = await _database.getAllExpenses();
      return Success(expenses);
    } catch (e) {
      return Failure(Exception('Failed to get all expenses: $e'));
    }
  }

  @override
  Future<Result<ExpenseEntity>> updateExpense(ExpenseEntity expense) async {
    try {
      await _database.updateExpense(expense);
      return Success(expense);
    } catch (e) {
      return Failure(Exception('Failed to update expense: $e'));
    }
  }

  @override
  Future<Result<void>> deleteExpense(String id) async {
    try {
      await _database.deleteExpense(id);
      return Success.unit();
    } catch (e) {
      return Failure(Exception('Failed to delete expense: $e'));
    }
  }

  @override
  Future<Result<List<ExpenseEntity>>> getUnsyncedExpenses() async {
    try {
      final expenses = await _database.getUnsyncedExpenses();
      return Success(expenses);
    } catch (e) {
      return Failure(Exception('Failed to get unsynced expenses: $e'));
    }
  }

  @override
  Future<Result<void>> markAsSynced(String id) async {
    try {
      await _database.markExpenseAsSynced(id);
      return Success.unit();
    } catch (e) {
      return Failure(Exception('Failed to mark expense as synced: $e'));
    }
  }

  @override
  Stream<List<ExpenseEntity>> watchExpensesByGroup(String groupId) {
    return _database.watchExpensesByGroup(groupId);
  }

  @override
  Stream<List<ExpenseEntity>> watchAllExpenses() {
    return _database.watchAllExpenses();
  }
}