import 'package:fairshare_app/core/events/app_event.dart';
import 'package:fairshare_app/core/events/event_providers.dart';
import 'package:fairshare_app/core/events/expense_events.dart';
import 'package:fairshare_app/features/expenses/presentation/providers/expense_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'group_statistics_providers.g.dart';

/// Statistics data for a group.
class GroupStatistics {
  final double totalAmount;
  final int expenseCount;
  final String groupId;

  GroupStatistics({
    required this.totalAmount,
    required this.expenseCount,
    required this.groupId,
  });

  @override
  String toString() =>
      'GroupStatistics(groupId: $groupId, total: $totalAmount, count: $expenseCount)';
}

/// Event-driven provider that calculates the total amount of expenses for a group.
///
/// This provider automatically recalculates when expense events (created/updated/deleted)
/// affect the specified group.
@riverpod
class GroupTotal extends _$GroupTotal {
  @override
  Stream<double> build(String groupId) async* {
    // Get initial value
    final expenses = await ref.watch(expensesByGroupProvider(groupId).future);
    yield _calculateTotal(expenses);

    // Listen to expense events and recalculate when this group is affected
    final eventBroker = ref.watch(eventBrokerProvider);

    await for (final event in eventBroker.stream) {
      // Only recalculate if event affects this group
      if (_affectsThisGroup(event, groupId)) {
        final updatedExpenses =
            await ref.read(expensesByGroupProvider(groupId).future);
        yield _calculateTotal(updatedExpenses);
      }
    }
  }

  double _calculateTotal(List expenses) {
    return expenses.fold<double>(0.0, (sum, expense) => sum + expense.amount);
  }

  bool _affectsThisGroup(AppEvent event, String groupId) {
    return (event is ExpenseCreated && event.expense.groupId == groupId) ||
        (event is ExpenseUpdated && event.expense.groupId == groupId) ||
        (event is ExpenseDeleted && event.groupId == groupId);
  }
}

/// Event-driven provider that counts the number of expenses in a group.
///
/// This provider automatically recalculates when expense events (created/updated/deleted)
/// affect the specified group.
@riverpod
class GroupExpenseCount extends _$GroupExpenseCount {
  @override
  Stream<int> build(String groupId) async* {
    // Get initial value
    final expenses = await ref.watch(expensesByGroupProvider(groupId).future);
    yield expenses.length;

    // Listen to expense events and recalculate when this group is affected
    final eventBroker = ref.watch(eventBrokerProvider);

    await for (final event in eventBroker.stream) {
      // Only recalculate if event affects this group
      if (_affectsThisGroup(event, groupId)) {
        final updatedExpenses =
            await ref.read(expensesByGroupProvider(groupId).future);
        yield updatedExpenses.length;
      }
    }
  }

  bool _affectsThisGroup(AppEvent event, String groupId) {
    return (event is ExpenseCreated && event.expense.groupId == groupId) ||
        (event is ExpenseUpdated && event.expense.groupId == groupId) ||
        (event is ExpenseDeleted && event.groupId == groupId);
  }
}

/// Combined event-driven provider for group statistics.
///
/// Provides both total amount and expense count in a single object.
/// Automatically updates when expense events affect the specified group.
@riverpod
class GroupStatisticsStream extends _$GroupStatisticsStream {
  @override
  Stream<GroupStatistics> build(String groupId) async* {
    // Get initial value
    final expenses = await ref.watch(expensesByGroupProvider(groupId).future);
    yield GroupStatistics(
      groupId: groupId,
      totalAmount: _calculateTotal(expenses),
      expenseCount: expenses.length,
    );

    // Listen to expense events and recalculate when this group is affected
    final eventBroker = ref.watch(eventBrokerProvider);

    await for (final event in eventBroker.stream) {
      // Only recalculate if event affects this group
      if (_affectsThisGroup(event, groupId)) {
        final updatedExpenses =
            await ref.read(expensesByGroupProvider(groupId).future);
        yield GroupStatistics(
          groupId: groupId,
          totalAmount: _calculateTotal(updatedExpenses),
          expenseCount: updatedExpenses.length,
        );
      }
    }
  }

  double _calculateTotal(List expenses) {
    return expenses.fold<double>(0.0, (sum, expense) => sum + expense.amount);
  }

  bool _affectsThisGroup(AppEvent event, String groupId) {
    return (event is ExpenseCreated && event.expense.groupId == groupId) ||
        (event is ExpenseUpdated && event.expense.groupId == groupId) ||
        (event is ExpenseDeleted && event.groupId == groupId);
  }
}
