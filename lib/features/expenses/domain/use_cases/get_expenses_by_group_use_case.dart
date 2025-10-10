import 'package:fairshare_app/core/domain/use_case.dart';
import 'package:fairshare_app/features/expenses/domain/entities/expense_entity.dart';
import 'package:fairshare_app/features/expenses/domain/repositories/expense_repository.dart';
import 'package:result_dart/result_dart.dart';

/// Use case for getting all expenses in a group.
class GetExpensesByGroupUseCase extends UseCase<String, List<ExpenseEntity>> {
  final ExpenseRepository _repository;

  GetExpensesByGroupUseCase(this._repository);

  @override
  Future<Result<List<ExpenseEntity>>> call(String groupId) async {
    // Validate group ID
    if (groupId.trim().isEmpty) {
      return Failure(Exception('Group ID is required'));
    }

    // Delegate to repository
    try {
      final result = await _repository.getExpensesByGroup(groupId);
      return Success(result);
    } catch (e) {
      return Failure(Exception('Failed to get expenses by group: $e'));
    }
  }
}
