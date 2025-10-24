import 'package:fairshare_app/core/domain/use_case.dart';
import 'package:fairshare_app/features/expenses/domain/repositories/expense_repository.dart';
import 'package:fairshare_app/features/expenses/domain/use_cases/expense_use_case_interfaces.dart';
import 'package:result_dart/result_dart.dart';

/// Use case for deleting an expense.
class DeleteExpenseUseCase extends UseCase<String, Unit>
    implements IDeleteExpenseUseCase {
  final ExpenseRepository _repository;

  DeleteExpenseUseCase(this._repository);

  @override
  void validate(String input) {
    if (input.trim().isEmpty) {
      throw Exception('Expense ID is required');
    }
  }

  @override
  Future<Unit> execute(String input) async {
    log.d('Deleting expense: $input');
    await _repository.deleteExpense(input);
    return unit;
  }
}
