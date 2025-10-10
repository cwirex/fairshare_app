import 'package:fairshare_app/core/domain/use_case.dart';
import 'package:fairshare_app/features/expenses/domain/repositories/expense_repository.dart';
import 'package:result_dart/result_dart.dart';

/// Use case for deleting an expense.
class DeleteExpenseUseCase extends UseCase<String, Unit> {
  final ExpenseRepository _repository;

  DeleteExpenseUseCase(this._repository);

  @override
  Future<Result<Unit>> call(String expenseId) async {
    // Validate ID
    if (expenseId.trim().isEmpty) {
      return Failure(Exception('Expense ID is required'));
    }

    // Delegate to repository
    try {
      await _repository.deleteExpense(expenseId);
      return Success.unit();
    } catch (e) {
      return Failure(Exception('Failed to delete expense: $e'));
    }
  }
}
