import 'package:fairshare_app/features/expenses/domain/entities/expense_entity.dart';
import 'package:result_dart/result_dart.dart';

/// Interface for creating a new expense.
///
/// Validates the expense (amount > 0, title not empty, group exists)
/// and creates it in the repository. The operation is queued for Firestore sync.
///
/// Returns [Result<ExpenseEntity>] with the created expense on success,
/// or a failure with validation/repository errors.
abstract class ICreateExpenseUseCase {
  /// Create a new expense.
  ///
  /// [expense] - The expense entity to create.
  /// Returns the created expense or a failure.
  Future<Result<ExpenseEntity>> call(ExpenseEntity expense);
}

/// Interface for updating an existing expense.
///
/// Validates the expense (ID exists, amount > 0, title not empty)
/// and updates it in the repository. The operation is queued for Firestore sync.
///
/// Returns [Result<ExpenseEntity>] with the updated expense on success,
/// or a failure with validation/repository errors.
abstract class IUpdateExpenseUseCase {
  /// Update an existing expense.
  ///
  /// [expense] - The expense entity with updated values.
  /// Returns the updated expense or a failure.
  Future<Result<ExpenseEntity>> call(ExpenseEntity expense);
}

/// Interface for deleting an expense.
///
/// Validates the expense ID and soft-deletes the expense from the repository.
/// The operation is queued for Firestore sync.
///
/// Returns [Result<Unit>] on success, or a failure with validation/repository errors.
abstract class IDeleteExpenseUseCase {
  /// Delete an expense by ID.
  ///
  /// [expenseId] - The ID of the expense to delete.
  /// Returns Unit on success or a failure.
  Future<Result<Unit>> call(String expenseId);
}

/// Interface for getting a single expense by ID.
///
/// Retrieves an expense from the repository.
///
/// Returns [Result<ExpenseEntity>] with the expense on success,
/// or a failure if not found or repository error occurs.
abstract class IGetExpenseUseCase {
  /// Get an expense by ID.
  ///
  /// [expenseId] - The ID of the expense to retrieve.
  /// Returns the expense or a failure.
  Future<Result<ExpenseEntity>> call(String expenseId);
}

/// Interface for getting all expenses in a group.
///
/// Retrieves all non-deleted expenses for a specific group from the repository.
///
/// Returns [Result<List<ExpenseEntity>>] with the list of expenses on success,
/// or a failure if repository error occurs.
abstract class IGetExpensesByGroupUseCase {
  /// Get all expenses for a group.
  ///
  /// [groupId] - The ID of the group.
  /// Returns list of expenses or a failure.
  Future<Result<List<ExpenseEntity>>> call(String groupId);
}
