import 'package:fairshare_app/core/database/database_provider.dart';
import 'package:fairshare_app/core/events/app_event.dart';
import 'package:fairshare_app/core/events/event_providers.dart';
import 'package:fairshare_app/core/events/expense_events.dart';
import 'package:fairshare_app/core/events/group_events.dart';
import 'package:fairshare_app/core/logging/app_logger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'group_stats_providers.g.dart';

/// Event-driven provider for total spending in a group.
///
/// Returns the sum of all expense amounts for the group.
/// Automatically recalculates when expenses are created, updated, or deleted.
@riverpod
class GroupTotalSpending extends _$GroupTotalSpending with LoggerMixin {
  @override
  Stream<double> build(String groupId) async* {
    log.d('Initializing GroupTotalSpending for group: $groupId');

    // Calculate initial total
    final total = await _calculateTotal(groupId);
    yield total;

    // Listen to events and recalculate when expenses change
    final eventBroker = ref.watch(eventBrokerProvider);

    await for (final event in eventBroker.stream) {
      if (_shouldRecalculate(event, groupId)) {
        log.d(
          'Recalculating total spending for group $groupId due to event: ${event.runtimeType}',
        );
        final updatedTotal = await _calculateTotal(groupId);
        log.i('Total spending for group $groupId: \$${updatedTotal.toStringAsFixed(2)}');
        yield updatedTotal;
      }
    }
  }

  /// Calculate total spending for a group
  Future<double> _calculateTotal(String groupId) async {
    final database = ref.read(appDatabaseProvider);
    final expenses = await database.expensesDao.getExpensesByGroup(groupId);
    return expenses.fold<double>(0.0, (sum, expense) => sum + expense.amount);
  }

  /// Determine if we should recalculate based on the event
  bool _shouldRecalculate(AppEvent event, String groupId) {
    if (event is ExpenseCreated) {
      return event.expense.groupId == groupId;
    }
    if (event is ExpenseUpdated) {
      return event.expense.groupId == groupId;
    }
    if (event is ExpenseDeleted) {
      return event.groupId == groupId;
    }
    return false;
  }
}

/// Event-driven provider for expense count in a group.
///
/// Returns the number of expenses in the group.
/// Automatically recalculates when expenses are created or deleted.
@riverpod
class GroupExpenseCount extends _$GroupExpenseCount with LoggerMixin {
  @override
  Stream<int> build(String groupId) async* {
    log.d('Initializing GroupExpenseCount for group: $groupId');

    // Calculate initial count
    final count = await _calculateCount(groupId);
    yield count;

    // Listen to events and recalculate when expenses change
    final eventBroker = ref.watch(eventBrokerProvider);

    await for (final event in eventBroker.stream) {
      if (_shouldRecalculate(event, groupId)) {
        log.d(
          'Recalculating expense count for group $groupId due to event: ${event.runtimeType}',
        );
        final updatedCount = await _calculateCount(groupId);
        log.i('Expense count for group $groupId: $updatedCount');
        yield updatedCount;
      }
    }
  }

  /// Calculate expense count for a group
  Future<int> _calculateCount(String groupId) async {
    final database = ref.read(appDatabaseProvider);
    final expenses = await database.expensesDao.getExpensesByGroup(groupId);
    return expenses.length;
  }

  /// Determine if we should recalculate based on the event
  bool _shouldRecalculate(AppEvent event, String groupId) {
    if (event is ExpenseCreated) {
      return event.expense.groupId == groupId;
    }
    if (event is ExpenseDeleted) {
      return event.groupId == groupId;
    }
    return false;
  }
}

/// Event-driven provider for member count in a group.
///
/// Returns the number of members in the group.
/// Automatically recalculates when members are added or removed.
@riverpod
class GroupMemberCount extends _$GroupMemberCount with LoggerMixin {
  @override
  Stream<int> build(String groupId) async* {
    log.d('Initializing GroupMemberCount for group: $groupId');

    // Calculate initial count
    final count = await _calculateCount(groupId);
    yield count;

    // Listen to events and recalculate when members change
    final eventBroker = ref.watch(eventBrokerProvider);

    await for (final event in eventBroker.stream) {
      if (_shouldRecalculate(event, groupId)) {
        log.d(
          'Recalculating member count for group $groupId due to event: ${event.runtimeType}',
        );
        final updatedCount = await _calculateCount(groupId);
        log.i('Member count for group $groupId: $updatedCount');
        yield updatedCount;
      }
    }
  }

  /// Calculate member count for a group
  Future<int> _calculateCount(String groupId) async {
    final database = ref.read(appDatabaseProvider);
    final members = await database.groupsDao.getAllGroupMembers(groupId);
    return members.length;
  }

  /// Determine if we should recalculate based on the event
  bool _shouldRecalculate(AppEvent event, String groupId) {
    // TODO: Update when MemberEvent types are implemented
    // For now, recalculate on group updates as a conservative approach
    if (event is GroupUpdated) {
      return event.group.id == groupId;
    }
    return false;
  }
}

/// Statistics summary for a group.
class GroupStatistics {
  final String groupId;
  final double totalSpending;
  final int expenseCount;
  final int memberCount;
  final DateTime lastUpdated;

  GroupStatistics({
    required this.groupId,
    required this.totalSpending,
    required this.expenseCount,
    required this.memberCount,
    required this.lastUpdated,
  });

  @override
  String toString() =>
      'GroupStatistics(group: $groupId, spending: \$$totalSpending, expenses: $expenseCount, members: $memberCount)';
}

/// Event-driven provider for aggregate group statistics.
///
/// Combines total spending, expense count, and member count into one object.
/// Automatically updates when any of the underlying values change.
@riverpod
class GroupStats extends _$GroupStats with LoggerMixin {
  @override
  Stream<GroupStatistics> build(String groupId) async* {
    log.d('Initializing GroupStats for group: $groupId');

    // Get initial statistics
    final stats = await _calculateStats(groupId);
    yield stats;

    // Listen to events and recalculate when relevant changes occur
    final eventBroker = ref.watch(eventBrokerProvider);

    await for (final event in eventBroker.stream) {
      if (_shouldRecalculate(event, groupId)) {
        log.d(
          'Recalculating stats for group $groupId due to event: ${event.runtimeType}',
        );
        final updatedStats = await _calculateStats(groupId);
        log.i('Updated stats for group $groupId: $updatedStats');
        yield updatedStats;
      }
    }
  }

  /// Calculate all statistics for a group
  Future<GroupStatistics> _calculateStats(String groupId) async {
    final database = ref.read(appDatabaseProvider);

    // Fetch all data in parallel
    final results = await Future.wait([
      database.expensesDao.getExpensesByGroup(groupId),
      database.groupsDao.getAllGroupMembers(groupId),
    ]);

    final expenses = results[0] as List;
    final members = results[1] as List;

    final totalSpending = expenses.fold<double>(
      0.0,
      (sum, expense) => sum + (expense as dynamic).amount,
    );

    return GroupStatistics(
      groupId: groupId,
      totalSpending: totalSpending,
      expenseCount: expenses.length,
      memberCount: members.length,
      lastUpdated: DateTime.now(),
    );
  }

  /// Determine if we should recalculate based on the event
  bool _shouldRecalculate(AppEvent event, String groupId) {
    // Recalculate on expense events
    if (event is ExpenseCreated) {
      return event.expense.groupId == groupId;
    }
    if (event is ExpenseUpdated) {
      return event.expense.groupId == groupId;
    }
    if (event is ExpenseDeleted) {
      return event.groupId == groupId;
    }

    // Recalculate on group updates (may affect member count)
    if (event is GroupUpdated) {
      return event.group.id == groupId;
    }

    // TODO: Add member-specific events when implemented
    return false;
  }
}

/// Event-driven provider for average expense amount in a group.
///
/// Returns the average amount per expense (total / count).
/// Returns 0.0 if there are no expenses.
@riverpod
class GroupAverageExpense extends _$GroupAverageExpense with LoggerMixin {
  @override
  Stream<double> build(String groupId) async* {
    log.d('Initializing GroupAverageExpense for group: $groupId');

    // Calculate initial average
    final average = await _calculateAverage(groupId);
    yield average;

    // Listen to events and recalculate when expenses change
    final eventBroker = ref.watch(eventBrokerProvider);

    await for (final event in eventBroker.stream) {
      if (_shouldRecalculate(event, groupId)) {
        log.d(
          'Recalculating average expense for group $groupId due to event: ${event.runtimeType}',
        );
        final updatedAverage = await _calculateAverage(groupId);
        log.i(
          'Average expense for group $groupId: \$${updatedAverage.toStringAsFixed(2)}',
        );
        yield updatedAverage;
      }
    }
  }

  /// Calculate average expense amount for a group
  Future<double> _calculateAverage(String groupId) async {
    final database = ref.read(appDatabaseProvider);
    final expenses = await database.expensesDao.getExpensesByGroup(groupId);

    if (expenses.isEmpty) {
      return 0.0;
    }

    final total = expenses.fold<double>(
      0.0,
      (sum, expense) => sum + expense.amount,
    );
    return total / expenses.length;
  }

  /// Determine if we should recalculate based on the event
  bool _shouldRecalculate(AppEvent event, String groupId) {
    if (event is ExpenseCreated) {
      return event.expense.groupId == groupId;
    }
    if (event is ExpenseUpdated) {
      return event.expense.groupId == groupId;
    }
    if (event is ExpenseDeleted) {
      return event.groupId == groupId;
    }
    return false;
  }
}
