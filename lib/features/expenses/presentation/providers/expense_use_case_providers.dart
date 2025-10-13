import 'package:fairshare_app/core/sync/sync_providers.dart';
import 'package:fairshare_app/features/expenses/domain/use_cases/create_expense_use_case.dart';
import 'package:fairshare_app/features/expenses/domain/use_cases/delete_expense_use_case.dart';
import 'package:fairshare_app/features/expenses/domain/use_cases/get_expense_use_case.dart';
import 'package:fairshare_app/features/expenses/domain/use_cases/get_expenses_by_group_use_case.dart';
import 'package:fairshare_app/features/expenses/domain/use_cases/update_expense_use_case.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'expense_use_case_providers.g.dart';

/// Provider for CreateExpenseUseCase
@riverpod
CreateExpenseUseCase createExpenseUseCase(CreateExpenseUseCaseRef ref) {
  final repository = ref.watch(expenseRepositoryProvider);
  return CreateExpenseUseCase(repository);
}

/// Provider for UpdateExpenseUseCase
@riverpod
UpdateExpenseUseCase updateExpenseUseCase(UpdateExpenseUseCaseRef ref) {
  final repository = ref.watch(expenseRepositoryProvider);
  return UpdateExpenseUseCase(repository);
}

/// Provider for DeleteExpenseUseCase
@riverpod
DeleteExpenseUseCase deleteExpenseUseCase(DeleteExpenseUseCaseRef ref) {
  final repository = ref.watch(expenseRepositoryProvider);
  return DeleteExpenseUseCase(repository);
}

/// Provider for GetExpenseUseCase
@riverpod
GetExpenseUseCase getExpenseUseCase(GetExpenseUseCaseRef ref) {
  final repository = ref.watch(expenseRepositoryProvider);
  return GetExpenseUseCase(repository);
}

/// Provider for GetExpensesByGroupUseCase
@riverpod
GetExpensesByGroupUseCase getExpensesByGroupUseCase(
  GetExpensesByGroupUseCaseRef ref,
) {
  final repository = ref.watch(expenseRepositoryProvider);
  return GetExpensesByGroupUseCase(repository);
}
