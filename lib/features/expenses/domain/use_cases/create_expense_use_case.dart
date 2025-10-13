import 'package:fairshare_app/core/domain/use_case.dart';
import 'package:fairshare_app/features/expenses/domain/entities/expense_entity.dart';
import 'package:fairshare_app/features/expenses/domain/repositories/expense_repository.dart';

/// Use case for creating a new expense.
class CreateExpenseUseCase extends UseCase<ExpenseEntity, ExpenseEntity> {
  final ExpenseRepository _repository;

  CreateExpenseUseCase(this._repository);

  @override
  void validate(ExpenseEntity input) {
    if (input.amount <= 0) {
      throw Exception('Amount must be greater than zero');
    }

    if (input.title.trim().isEmpty) {
      throw Exception('Title is required');
    }

    if (input.groupId.trim().isEmpty) {
      throw Exception('Group is required');
    }
  }

  @override
  Future<ExpenseEntity> execute(ExpenseEntity input) async {
    log.d('Creating expense: ${input.title}');
    return await _repository.createExpense(input);
  }
}
