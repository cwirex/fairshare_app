import 'package:fairshare_app/core/events/app_event.dart';
import 'package:fairshare_app/features/expenses/domain/entities/expense_entity.dart';
import 'package:fairshare_app/features/expenses/domain/entities/expense_share_entity.dart';

/// Event fired when an expense is created.
class ExpenseCreated extends AppEvent {
  final ExpenseEntity expense;

  ExpenseCreated(this.expense);

  @override
  String toString() => 'ExpenseCreated(${expense.id}, ${expense.title})';
}

/// Event fired when an expense is updated.
class ExpenseUpdated extends AppEvent {
  final ExpenseEntity expense;
  final ExpenseEntity? previousVersion;

  ExpenseUpdated(this.expense, [this.previousVersion]);

  @override
  String toString() => 'ExpenseUpdated(${expense.id}, ${expense.title})';
}

/// Event fired when an expense is deleted.
class ExpenseDeleted extends AppEvent {
  final String expenseId;
  final String groupId;

  ExpenseDeleted(this.expenseId, this.groupId);

  @override
  String toString() => 'ExpenseDeleted($expenseId in group $groupId)';
}

/// Event fired when an expense share is added.
class ExpenseShareAdded extends AppEvent {
  final ExpenseShareEntity share;

  ExpenseShareAdded(this.share);

  @override
  String toString() =>
      'ExpenseShareAdded(expense: ${share.expenseId}, user: ${share.userId})';
}

/// Event fired when an expense share is updated.
class ExpenseShareUpdated extends AppEvent {
  final ExpenseShareEntity share;
  final ExpenseShareEntity? previousVersion;

  ExpenseShareUpdated(this.share, [this.previousVersion]);

  @override
  String toString() =>
      'ExpenseShareUpdated(expense: ${share.expenseId}, user: ${share.userId})';
}
