import 'package:fairshare_app/core/events/app_event.dart';
import 'package:fairshare_app/core/events/event_providers.dart';
import 'package:fairshare_app/core/events/expense_events.dart';
import 'package:fairshare_app/core/events/group_events.dart';
import 'package:fairshare_app/features/expenses/domain/entities/expense_entity.dart';
import 'package:fairshare_app/features/expenses/presentation/providers/expense_providers.dart';
import 'package:fairshare_app/features/groups/presentation/providers/group_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'dashboard_providers.g.dart';

/// Dashboard statistics aggregated across all groups.
class DashboardStatistics {
  final double totalSpending;
  final int totalExpenses;
  final int totalGroups;
  final DateTime lastUpdated;

  DashboardStatistics({
    required this.totalSpending,
    required this.totalExpenses,
    required this.totalGroups,
    required this.lastUpdated,
  });

  @override
  String toString() =>
      'DashboardStatistics(total: $totalSpending, expenses: $totalExpenses, groups: $totalGroups)';
}

/// Event-driven provider for dashboard statistics.
///
/// Automatically recalculates when expenses or groups are created/updated/deleted.
@riverpod
class DashboardStats extends _$DashboardStats {
  @override
  Stream<DashboardStatistics> build() async* {
    // Get initial values
    final expenses = await ref.watch(allExpensesProvider.future);
    final groups = await ref.watch(userGroupsProvider.future);

    yield DashboardStatistics(
      totalSpending: _calculateTotalSpending(expenses),
      totalExpenses: expenses.length,
      totalGroups: groups.length,
      lastUpdated: DateTime.now(),
    );

    // Listen to events and recalculate when relevant changes occur
    final eventBroker = ref.watch(eventBrokerProvider);

    await for (final event in eventBroker.stream) {
      // Recalculate on any expense or group event
      if (_shouldRecalculate(event)) {
        final updatedExpenses = await ref.read(allExpensesProvider.future);
        final updatedGroups = await ref.read(userGroupsProvider.future);

        yield DashboardStatistics(
          totalSpending: _calculateTotalSpending(updatedExpenses),
          totalExpenses: updatedExpenses.length,
          totalGroups: updatedGroups.length,
          lastUpdated: DateTime.now(),
        );
      }
    }
  }

  double _calculateTotalSpending(List<ExpenseEntity> expenses) {
    return expenses.fold<double>(0.0, (sum, expense) => sum + expense.amount);
  }

  bool _shouldRecalculate(AppEvent event) {
    return event is ExpenseCreated ||
        event is ExpenseUpdated ||
        event is ExpenseDeleted ||
        event is GroupCreated ||
        event is GroupDeleted;
  }
}

/// Event-driven provider for total spending across all groups.
@riverpod
class TotalSpending extends _$TotalSpending {
  @override
  Stream<double> build() async* {
    // Get initial value
    final expenses = await ref.watch(allExpensesProvider.future);
    yield _calculateTotal(expenses);

    // Listen to expense events and recalculate
    final eventBroker = ref.watch(eventBrokerProvider);

    await for (final event in eventBroker.stream) {
      if (event is ExpenseCreated ||
          event is ExpenseUpdated ||
          event is ExpenseDeleted) {
        final updatedExpenses = await ref.read(allExpensesProvider.future);
        yield _calculateTotal(updatedExpenses);
      }
    }
  }

  double _calculateTotal(List<ExpenseEntity> expenses) {
    return expenses.fold<double>(0.0, (sum, expense) => sum + expense.amount);
  }
}

/// Recent activity item for the activity feed.
class ActivityItem {
  final String id;
  final String type; // 'expense_created', 'expense_updated', 'group_created', etc.
  final String description;
  final DateTime timestamp;
  final String? groupId;

  ActivityItem({
    required this.id,
    required this.type,
    required this.description,
    required this.timestamp,
    this.groupId,
  });

  @override
  String toString() => 'ActivityItem($type: $description at $timestamp)';
}

/// Event-driven provider for recent activity feed.
///
/// Maintains a list of the most recent 10 activities (expenses/groups).
/// Automatically updates when events are fired.
@riverpod
class RecentActivity extends _$RecentActivity {
  static const int _maxItems = 10;
  final List<ActivityItem> _activities = [];

  @override
  Stream<List<ActivityItem>> build() async* {
    // Initialize with existing expenses and groups
    await _initializeActivities();
    yield List.unmodifiable(_activities);

    // Listen to events and add to activity feed
    final eventBroker = ref.watch(eventBrokerProvider);

    await for (final event in eventBroker.stream) {
      final activityItem = _eventToActivity(event);
      if (activityItem != null) {
        _activities.insert(0, activityItem); // Add to front
        if (_activities.length > _maxItems) {
          _activities.removeLast(); // Keep only recent items
        }
        yield List.unmodifiable(_activities);
      }
    }
  }

  Future<void> _initializeActivities() async {
    final expenses = await ref.read(allExpensesProvider.future);

    // Convert most recent expenses to activity items
    final sortedExpenses = expenses.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    for (final expense in sortedExpenses.take(_maxItems)) {
      _activities.add(
        ActivityItem(
          id: expense.id,
          type: 'expense_created',
          description: '${expense.title} - ${expense.currency} ${expense.amount.toStringAsFixed(2)}',
          timestamp: expense.createdAt,
          groupId: expense.groupId,
        ),
      );
    }
  }

  ActivityItem? _eventToActivity(AppEvent event) {
    if (event is ExpenseCreated) {
      return ActivityItem(
        id: event.expense.id,
        type: 'expense_created',
        description:
            'Created: ${event.expense.title} - ${event.expense.currency} ${event.expense.amount.toStringAsFixed(2)}',
        timestamp: event.timestamp,
        groupId: event.expense.groupId,
      );
    } else if (event is ExpenseUpdated) {
      return ActivityItem(
        id: event.expense.id,
        type: 'expense_updated',
        description:
            'Updated: ${event.expense.title} - ${event.expense.currency} ${event.expense.amount.toStringAsFixed(2)}',
        timestamp: event.timestamp,
        groupId: event.expense.groupId,
      );
    } else if (event is ExpenseDeleted) {
      return ActivityItem(
        id: event.expenseId,
        type: 'expense_deleted',
        description: 'Deleted expense',
        timestamp: event.timestamp,
        groupId: event.groupId,
      );
    } else if (event is GroupCreated) {
      return ActivityItem(
        id: event.group.id,
        type: 'group_created',
        description: 'Created group: ${event.group.displayName}',
        timestamp: event.timestamp,
        groupId: event.group.id,
      );
    } else if (event is GroupUpdated) {
      return ActivityItem(
        id: event.group.id,
        type: 'group_updated',
        description: 'Updated group: ${event.group.displayName}',
        timestamp: event.timestamp,
        groupId: event.group.id,
      );
    } else if (event is GroupDeleted) {
      return ActivityItem(
        id: event.groupId,
        type: 'group_deleted',
        description: 'Deleted group',
        timestamp: event.timestamp,
        groupId: event.groupId,
      );
    }
    return null;
  }
}
