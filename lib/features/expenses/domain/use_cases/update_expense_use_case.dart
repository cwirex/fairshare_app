import 'package:fairshare_app/core/domain/use_case.dart';
import 'package:fairshare_app/features/expenses/domain/entities/expense_entity.dart';
import 'package:fairshare_app/features/expenses/domain/repositories/expense_repository.dart';

/// Use case for updating an existing expense.
class UpdateExpenseUseCase extends UseCase<ExpenseEntity, ExpenseEntity> {
  final ExpenseRepository _repository;

  UpdateExpenseUseCase(this._repository);

  @override
  void validate(ExpenseEntity input) {
    if (input.id.trim().isEmpty) {
      throw Exception('Expense ID is required');
    }

    if (input.amount <= 0) {
      throw Exception('Amount must be greater than zero');
    }

    if (input.title.trim().isEmpty) {
      throw Exception('Title is required');
    }
  }

  @override
  Future<ExpenseEntity> execute(ExpenseEntity input) async {
    log.d('Updating expense: ${input.title}');
    return await _repository.updateExpense(input);
  }
}
