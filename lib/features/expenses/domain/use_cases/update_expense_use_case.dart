import 'package:fairshare_app/core/domain/use_case.dart';
import 'package:fairshare_app/features/expenses/domain/entities/expense_entity.dart';
import 'package:fairshare_app/features/expenses/domain/repositories/expense_repository.dart';
import 'package:result_dart/result_dart.dart';

/// Use case for updating an existing expense.
class UpdateExpenseUseCase extends UseCase<ExpenseEntity, ExpenseEntity> {
  final ExpenseRepository _repository;

  UpdateExpenseUseCase(this._repository);

  @override
  Future<Result<ExpenseEntity>> call(ExpenseEntity expense) async {
    // Validate ID
    if (expense.id.trim().isEmpty) {
      return Failure(Exception('Expense ID is required'));
    }

    // Validate amount
    if (expense.amount <= 0) {
      return Failure(Exception('Amount must be greater than zero'));
    }

    // Validate title
    if (expense.title.trim().isEmpty) {
      return Failure(Exception('Title is required'));
    }

    // Delegate to repository
    try {
      final result = await _repository.updateExpense(expense);
      return Success(result);
    } catch (e) {
      return Failure(Exception('Failed to update expense: $e'));
    }
  }
}
