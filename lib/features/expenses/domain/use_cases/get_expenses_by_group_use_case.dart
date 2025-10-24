import 'package:fairshare_app/core/domain/use_case.dart';
import 'package:fairshare_app/features/expenses/domain/entities/expense_entity.dart';
import 'package:fairshare_app/features/expenses/domain/repositories/expense_repository.dart';
import 'package:fairshare_app/features/expenses/domain/use_cases/expense_use_case_interfaces.dart';

/// Use case for getting all expenses in a group.
class GetExpensesByGroupUseCase extends UseCase<String, List<ExpenseEntity>>
    implements IGetExpensesByGroupUseCase {
  final ExpenseRepository _repository;

  GetExpensesByGroupUseCase(this._repository);

  @override
  void validate(String input) {
    if (input.trim().isEmpty) {
      throw Exception('Group ID is required');
    }
  }

  @override
  Future<List<ExpenseEntity>> execute(String input) async {
    return await _repository.getExpensesByGroup(input);
  }
}
