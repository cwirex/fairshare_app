import 'package:result_dart/result_dart.dart';

import 'package:fairshare_app/features/expenses/domain/entities/expense_entity.dart';

/// Repository interface for expense data operations.
///
/// Abstracts the data source (local database, remote API, etc.)
/// to keep the domain layer independent of implementation details.
abstract class ExpenseRepository {
  /// Create a new expense
  Future<Result<ExpenseEntity>> createExpense(ExpenseEntity expense);

  /// Get expense by ID
  Future<Result<ExpenseEntity>> getExpenseById(String id);

  /// Get all expenses for a specific group
  Future<Result<List<ExpenseEntity>>> getExpensesByGroup(String groupId);

  /// Get all expenses (across all groups)
  Future<Result<List<ExpenseEntity>>> getAllExpenses();

  /// Update an existing expense
  Future<Result<ExpenseEntity>> updateExpense(ExpenseEntity expense);

  /// Delete an expense
  Future<Result<void>> deleteExpense(String id);

  /// Watch expense changes (stream)
  Stream<List<ExpenseEntity>> watchExpensesByGroup(String groupId);

  /// Watch all expenses (stream)
  Stream<List<ExpenseEntity>> watchAllExpenses();
}