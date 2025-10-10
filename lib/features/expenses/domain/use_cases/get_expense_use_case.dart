import 'package:fairshare_app/core/domain/use_case.dart';
import 'package:fairshare_app/features/expenses/domain/entities/expense_entity.dart';
import 'package:fairshare_app/features/expenses/domain/repositories/expense_repository.dart';
import 'package:result_dart/result_dart.dart';

/// Use case for getting a single expense by ID.
class GetExpenseUseCase extends UseCase<String, ExpenseEntity> {
  final ExpenseRepository _repository;

  GetExpenseUseCase(this._repository);

  @override
  Future<Result<ExpenseEntity>> call(String expenseId) async {
    // Validate ID
    if (expenseId.trim().isEmpty) {
      return Failure(Exception('Expense ID is required'));
    }

    // Delegate to repository
    try {
      final result = await _repository.getExpenseById(expenseId);
      return Success(result);
    } catch (e) {
      return Failure(Exception('Failed to get expense: $e'));
    }
  }
}
