import 'package:drift/drift.dart';
import 'package:fairshare_app/core/database/tables/expenses_table.dart';
import 'package:fairshare_app/core/database/tables/users_table.dart';

/// Table definition for expense shares.
///
/// Stores individual user shares for each expense.
class ExpenseShares extends Table {
  /// Expense ID reference
  TextColumn get expenseId =>
      text().references(Expenses, #id, onDelete: KeyAction.cascade)();

  /// User ID who shares this expense
  TextColumn get userId =>
      text().references(AppUsers, #id, onDelete: KeyAction.cascade)();

  /// Amount this user owes for the expense
  RealColumn get shareAmount => real()();

  @override
  Set<Column> get primaryKey => {expenseId, userId};
}
