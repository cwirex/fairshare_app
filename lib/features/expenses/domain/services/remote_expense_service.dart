import 'package:fairshare_app/features/expenses/domain/entities/expense_entity.dart';
import 'package:fairshare_app/features/expenses/domain/entities/expense_share_entity.dart';
import 'package:result_dart/result_dart.dart';

/// Abstract interface for remote expense operations.
///
/// This service handles all network-based expense operations (e.g., Firestore).
/// It abstracts the remote data source implementation from the domain layer,
/// following clean architecture and dependency inversion principles.
///
/// Implementations should handle:
/// - Network operations (upload, download, delete)
/// - Real-time streaming (watch operations)
/// - Error handling and logging
///
/// This interface is used by sync services to coordinate remote + local operations.
abstract class RemoteExpenseService {
  /// Upload an expense to the remote database.
  Future<Result<void>> uploadExpense(ExpenseEntity expense);

  /// Upload an expense share to the remote database.
  Future<Result<void>> uploadExpenseShare(ExpenseShareEntity share);

  /// Download a specific expense by ID from the remote database.
  Future<Result<ExpenseEntity>> downloadExpense(String groupId, String expenseId);

  /// Download all expenses for a specific group.
  Future<Result<List<ExpenseEntity>>> downloadGroupExpenses(String groupId);

  /// Download all expense shares for a specific expense.
  Future<Result<List<ExpenseShareEntity>>> downloadExpenseShares(
    String groupId,
    String expenseId,
  );

  /// Delete an expense from the remote database.
  Future<Result<void>> deleteExpense(String groupId, String expenseId);

  /// Watch real-time changes to all expenses in a group.
  Stream<List<ExpenseEntity>> watchGroupExpenses(String groupId);

  /// Watch real-time changes to a specific expense.
  Stream<ExpenseEntity> watchExpense(String groupId, String expenseId);

  /// Watch real-time changes to expense shares.
  Stream<List<ExpenseShareEntity>> watchExpenseShares(
    String groupId,
    String expenseId,
  );
}
