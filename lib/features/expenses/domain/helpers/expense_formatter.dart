import 'package:fairshare_app/features/expenses/domain/entities/expense_entity.dart';

/// Formats expense data for display.
class ExpenseFormatter {
  const ExpenseFormatter._();

  static String formatAmount(ExpenseEntity expense) {
    return '${expense.currency} ${expense.amount.toStringAsFixed(2)}';
  }

  static String formatDate(ExpenseEntity expense) {
    return expense.expenseDate.toString().split(' ')[0];
  }

  static bool needsSync(ExpenseEntity expense) {
    return !expense.isSynced;
  }

  static bool isRecent(ExpenseEntity expense) {
    return DateTime.now().difference(expense.expenseDate).inDays < 7;
  }
}