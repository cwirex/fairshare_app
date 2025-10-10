import 'package:fairshare_app/core/domain/use_case.dart';
import 'package:fairshare_app/features/expenses/domain/entities/expense_entity.dart';
import 'package:fairshare_app/features/expenses/domain/repositories/expense_repository.dart';
import 'package:result_dart/result_dart.dart';

/// Use case for creating a new expense.
class CreateExpenseUseCase extends UseCase<ExpenseEntity, ExpenseEntity> {
  final ExpenseRepository _repository;

  CreateExpenseUseCase(this._repository);

  @override
  Future<Result<ExpenseEntity>> call(ExpenseEntity expense) async {
    log.d('Creating expense: $expense');
    // Validate amount
    if (expense.amount <= 0) {
      return Failure(Exception('Amount must be greater than zero'));
    }

    // Validate title
    if (expense.title.trim().isEmpty) {
      return Failure(Exception('Title is required'));
    }

    // Validate group ID
    if (expense.groupId.trim().isEmpty) {
      return Failure(Exception('Group is required'));
    }

    try {
      final result = await _repository.createExpense(expense);
      return Success(result);
    } catch (e) {
      log.e('Error creating expense: $e');
      return Failure(Exception('Failed to create expense'));
    }
  }
}
