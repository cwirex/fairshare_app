import 'package:fairshare_app/core/sync/sync_providers.dart';
import 'package:fairshare_app/features/expenses/domain/use_cases/create_expense_use_case.dart';
import 'package:fairshare_app/features/expenses/domain/use_cases/delete_expense_use_case.dart';
import 'package:fairshare_app/features/expenses/domain/use_cases/expense_use_case_interfaces.dart';
import 'package:fairshare_app/features/expenses/domain/use_cases/get_expense_use_case.dart';
import 'package:fairshare_app/features/expenses/domain/use_cases/get_expenses_by_group_use_case.dart';
import 'package:fairshare_app/features/expenses/domain/use_cases/update_expense_use_case.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'expense_use_case_providers.g.dart';

/// Provider for CreateExpenseUseCase
@riverpod
ICreateExpenseUseCase createExpenseUseCase(CreateExpenseUseCaseRef ref) {
  final repository = ref.watch(expenseRepositoryProvider);
  return CreateExpenseUseCase(repository);
}

/// Provider for UpdateExpenseUseCase
@riverpod
IUpdateExpenseUseCase updateExpenseUseCase(UpdateExpenseUseCaseRef ref) {
  final repository = ref.watch(expenseRepositoryProvider);
  return UpdateExpenseUseCase(repository);
}

/// Provider for DeleteExpenseUseCase
@riverpod
IDeleteExpenseUseCase deleteExpenseUseCase(DeleteExpenseUseCaseRef ref) {
  final repository = ref.watch(expenseRepositoryProvider);
  return DeleteExpenseUseCase(repository);
}

/// Provider for GetExpenseUseCase
@riverpod
IGetExpenseUseCase getExpenseUseCase(GetExpenseUseCaseRef ref) {
  final repository = ref.watch(expenseRepositoryProvider);
  return GetExpenseUseCase(repository);
}

/// Provider for GetExpensesByGroupUseCase
@riverpod
IGetExpensesByGroupUseCase getExpensesByGroupUseCase(
  GetExpensesByGroupUseCaseRef ref,
) {
  final repository = ref.watch(expenseRepositoryProvider);
  return GetExpensesByGroupUseCase(repository);
}
