import 'package:fairshare_app/core/sync/sync_providers.dart';
import 'package:fairshare_app/features/expenses/domain/entities/expense_entity.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'expense_providers.g.dart';

/// Provider to watch all expenses across all groups.
///
/// This stream updates automatically when expenses are created, updated, or deleted.
@riverpod
Stream<List<ExpenseEntity>> allExpenses(Ref ref) {
  final repository = ref.watch(expenseRepositoryProvider);
  return repository.watchAllExpenses();
}

/// Provider to watch expenses for a specific group.
///
/// This stream updates automatically when expenses in the group are created, updated, or deleted.
@riverpod
Stream<List<ExpenseEntity>> expensesByGroup(Ref ref, String groupId) {
  final repository = ref.watch(expenseRepositoryProvider);
  return repository.watchExpensesByGroup(groupId);
}
