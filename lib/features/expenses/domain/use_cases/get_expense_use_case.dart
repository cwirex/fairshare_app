import 'package:fairshare_app/core/domain/use_case.dart';
import 'package:fairshare_app/features/expenses/domain/entities/expense_entity.dart';
import 'package:fairshare_app/features/expenses/domain/repositories/expense_repository.dart';

/// Use case for getting a single expense by ID.
class GetExpenseUseCase extends UseCase<String, ExpenseEntity> {
  final ExpenseRepository _repository;

  GetExpenseUseCase(this._repository);

  @override
  void validate(String input) {
    if (input.trim().isEmpty) {
      throw Exception('Expense ID is required');
    }
  }

  @override
  Future<ExpenseEntity> execute(String input) async {
    return await _repository.getExpenseById(input);
  }
}
