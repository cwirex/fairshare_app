import 'package:drift/drift.dart';
import 'package:fairshare_app/core/database/tables/groups_table.dart';
import 'package:fairshare_app/core/database/tables/users_table.dart';

/// Table definition for expenses in the FairShare app.
///
/// Stores expense information for group sharing.
/// Sync is managed by comparing with group.lastUpdateTimestamp.
class Expenses extends Table {
  /// Unique expense ID
  TextColumn get id => text()();

  /// Group this expense belongs to
  TextColumn get groupId => text().references(AppGroups, #id, onDelete: KeyAction.cascade)();

  /// Expense title/description
  TextColumn get title => text()();

  /// Expense amount (must be positive)
  RealColumn get amount => real()();

  /// Currency code (e.g., USD, EUR)
  TextColumn get currency => text()();

  /// User ID who paid for this expense
  TextColumn get paidBy => text()();

  /// Whether expense is shared with everyone in group
  BoolColumn get shareWithEveryone =>
      boolean().withDefault(const Constant(true))();

  /// Date when the expense occurred
  DateTimeColumn get expenseDate => dateTime()();

  /// When the expense was created
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  /// Last time expense data was updated
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  /// When the expense was soft-deleted (null if active)
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Table definition for expense shares.
///
/// Stores individual user shares for each expense.
class ExpenseShares extends Table {
  /// Expense ID reference
  TextColumn get expenseId => text().references(Expenses, #id, onDelete: KeyAction.cascade)();

  /// User ID who shares this expense
  TextColumn get userId => text().references(AppUsers, #id, onDelete: KeyAction.cascade)();

  /// Amount this user owes for the expense
  RealColumn get shareAmount => real()();

  @override
  Set<Column> get primaryKey => {expenseId, userId};
}
