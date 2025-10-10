import 'package:fairshare_app/core/events/expense_events.dart';
import 'package:fairshare_app/core/events/group_events.dart';

/// Base class for all domain events.
abstract class AppEvent {
  final DateTime timestamp;

  AppEvent() : timestamp = DateTime.now();
}

/// Helper extensions for filtering events.
extension EventFilters on AppEvent {
  /// Returns true if this event affects the specified group.
  bool affectsGroup(String groupId) {
    if (this is ExpenseCreated) {
      return (this as ExpenseCreated).expense.groupId == groupId;
    } else if (this is ExpenseUpdated) {
      return (this as ExpenseUpdated).expense.groupId == groupId;
    } else if (this is ExpenseDeleted) {
      return (this as ExpenseDeleted).groupId == groupId;
    } else if (this is GroupCreated) {
      return (this as GroupCreated).group.id == groupId;
    } else if (this is GroupUpdated) {
      return (this as GroupUpdated).group.id == groupId;
    } else if (this is GroupDeleted) {
      return (this as GroupDeleted).groupId == groupId;
    } else if (this is MemberAdded) {
      return (this as MemberAdded).member.groupId == groupId;
    } else if (this is MemberRemoved) {
      return (this as MemberRemoved).groupId == groupId;
    }
    return false;
  }

  /// Returns true if this event is related to expenses.
  bool isExpenseEvent() {
    return this is ExpenseCreated ||
        this is ExpenseUpdated ||
        this is ExpenseDeleted ||
        this is ExpenseShareAdded ||
        this is ExpenseShareUpdated;
  }

  /// Returns true if this event is related to groups.
  bool isGroupEvent() {
    return this is GroupCreated ||
        this is GroupUpdated ||
        this is GroupDeleted ||
        this is MemberAdded ||
        this is MemberRemoved;
  }
}
