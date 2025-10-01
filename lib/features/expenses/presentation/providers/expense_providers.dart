import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

import 'package:fairshare_app/core/database/database_provider.dart';
import 'package:fairshare_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:fairshare_app/features/expenses/data/repositories/local_expense_repository.dart';
import 'package:fairshare_app/features/expenses/domain/entities/expense_entity.dart';
import 'package:fairshare_app/features/expenses/domain/repositories/expense_repository.dart';

part 'expense_providers.g.dart';

/// Provider for expense repository
@Riverpod(keepAlive: true)
ExpenseRepository expenseRepository(ExpenseRepositoryRef ref) {
  final database = ref.watch(appDatabaseProvider);
  return LocalExpenseRepository(database);
}

/// Provider to watch all expenses
@riverpod
Stream<List<ExpenseEntity>> allExpenses(AllExpensesRef ref) {
  final repository = ref.watch(expenseRepositoryProvider);
  return repository.watchAllExpenses();
}

/// Provider to watch expenses for a specific group
@riverpod
Stream<List<ExpenseEntity>> expensesByGroup(
  ExpensesByGroupRef ref,
  String groupId,
) {
  final repository = ref.watch(expenseRepositoryProvider);
  return repository.watchExpensesByGroup(groupId);
}

/// Notifier for managing expense operations
@riverpod
class ExpenseNotifier extends _$ExpenseNotifier {
  @override
  FutureOr<void> build() {
    // No initial state needed
  }

  /// Create a new expense
  Future<void> createExpense({
    required String title,
    required double amount,
    required String currency,
    String? groupId,
    DateTime? expenseDate,
  }) async {
    state = const AsyncLoading();

    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) {
      state = AsyncError(
        Exception('User must be logged in to create expenses'),
        StackTrace.current,
      );
      return;
    }

    // Use "personal" as default group if not specified
    final effectiveGroupId = groupId ?? 'personal';

    final now = DateTime.now();
    final expense = ExpenseEntity(
      id: const Uuid().v4(),
      groupId: effectiveGroupId,
      title: title,
      amount: amount,
      currency: currency,
      paidBy: currentUser.id,
      shareWithEveryone: true,
      expenseDate: expenseDate ?? now,
      createdAt: now,
      updatedAt: now,
      isSynced: false,
    );

    final repository = ref.read(expenseRepositoryProvider);
    final result = await repository.createExpense(expense);

    result.fold(
      (success) {
        state = const AsyncData(null);
      },
      (error) {
        state = AsyncError(error, StackTrace.current);
      },
    );
  }

  /// Update an existing expense
  Future<void> updateExpense(ExpenseEntity expense) async {
    state = const AsyncLoading();

    final repository = ref.read(expenseRepositoryProvider);
    final result = await repository.updateExpense(
      expense.copyWith(
        updatedAt: DateTime.now(),
        isSynced: false,
      ),
    );

    result.fold(
      (success) {
        state = const AsyncData(null);
      },
      (error) {
        state = AsyncError(error, StackTrace.current);
      },
    );
  }

  /// Delete an expense
  Future<void> deleteExpense(String id) async {
    state = const AsyncLoading();

    final repository = ref.read(expenseRepositoryProvider);
    final result = await repository.deleteExpense(id);

    result.fold(
      (success) {
        state = const AsyncData(null);
      },
      (error) {
        state = AsyncError(error, StackTrace.current);
      },
    );
  }
}