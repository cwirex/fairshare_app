import 'package:result_dart/result_dart.dart';

import 'package:fairshare_app/core/database/app_database.dart';
import 'package:fairshare_app/features/expenses/data/services/firestore_expense_service.dart';
import 'package:fairshare_app/features/expenses/domain/entities/expense_entity.dart';
import 'package:fairshare_app/features/expenses/domain/repositories/expense_repository.dart';

/// Expense repository that syncs with both local database and Firestore.
class SyncedExpenseRepository implements ExpenseRepository {
  final AppDatabase _database;
  final FirestoreExpenseService _firestoreService;

  SyncedExpenseRepository(this._database, this._firestoreService);

  @override
  Future<Result<ExpenseEntity>> createExpense(ExpenseEntity expense) async {
    try {
      // Save to local database first (offline-first)
      await _database.insertExpense(expense);

      // Try to sync to Firestore in the background
      _firestoreService.uploadExpense(expense);

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
      // Update local database first
      await _database.updateExpense(expense);

      // Try to sync to Firestore in the background
      _firestoreService.uploadExpense(expense);

      return Success(expense);
    } catch (e) {
      return Failure(Exception('Failed to update expense: $e'));
    }
  }

  @override
  Future<Result<void>> deleteExpense(String id) async {
    try {
      // Get the expense to find its groupId
      final expense = await _database.getExpenseById(id);

      // Delete from local database first
      await _database.deleteExpense(id);

      // Try to delete from Firestore in the background
      if (expense != null) {
        _firestoreService.deleteExpense(expense.groupId, id);
      }

      return Success.unit();
    } catch (e) {
      return Failure(Exception('Failed to delete expense: $e'));
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
