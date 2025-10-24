import 'package:fairshare_app/features/expenses/domain/entities/expense_entity.dart';
import 'package:result_dart/result_dart.dart';

/// Interface for creating a new expense.
abstract class ICreateExpenseUseCase {
  Future<Result<ExpenseEntity>> call(ExpenseEntity expense);
}

/// Interface for updating an existing expense.
abstract class IUpdateExpenseUseCase {
  Future<Result<ExpenseEntity>> call(ExpenseEntity expense);
}

/// Interface for deleting an expense.
abstract class IDeleteExpenseUseCase {
  Future<Result<Unit>> call(String expenseId);
}

/// Interface for getting a single expense by ID.
abstract class IGetExpenseUseCase {
  Future<Result<ExpenseEntity>> call(String expenseId);
}

/// Interface for getting all expenses in a group.
abstract class IGetExpensesByGroupUseCase {
  Future<Result<List<ExpenseEntity>>> call(String groupId);
}
