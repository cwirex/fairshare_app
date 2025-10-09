import 'package:fairshare_app/core/database/app_database.dart';
import 'package:fairshare_app/core/logging/app_logger.dart';
import 'package:fairshare_app/features/expenses/domain/entities/expense_entity.dart';
import 'package:fairshare_app/features/expenses/domain/entities/expense_share_entity.dart';
import 'package:fairshare_app/features/expenses/domain/repositories/expense_repository.dart';
import 'package:result_dart/result_dart.dart';

/// Expense repository that coordinates local database and upload queue.
///
/// **Clean Architecture Compliance:**
/// - ONLY interacts with local database and queue
/// - NO Firestore calls (handled by sync services)
/// - Uses atomic transactions for data integrity
class SyncedExpenseRepository with LoggerMixin implements ExpenseRepository {
  final AppDatabase _database;

  SyncedExpenseRepository(this._database);

  @override
  Future<Result<ExpenseEntity>> createExpense(ExpenseEntity expense) async {
    try {
      // Atomic transaction: DB write + Queue entry (all or nothing)
      await _database.transaction<void>(() async {
        await _database.expensesDao.insertExpense(expense);
        await _database.syncDao.enqueueOperation(
          entityType: 'expense',
          entityId: expense.id,
          operationType: 'create',
          metadata: expense.groupId,
        );
      });

      log.d('Created expense: ${expense.title}');
      return Success(expense);
    } catch (e) {
      log.e('Failed to create expense: $e');
      return Failure(Exception('Failed to create expense: $e'));
    }
  }

  @override
  Future<Result<ExpenseEntity>> getExpenseById(String id) async {
    try {
      final expense = await _database.expensesDao.getExpenseById(id);
      if (expense == null) {
        return Failure(Exception('Expense not found: $id'));
      }
      return Success(expense);
    } catch (e) {
      log.e('Failed to get expense $id: $e');
      return Failure(Exception('Failed to get expense: $e'));
    }
  }

  @override
  Future<Result<List<ExpenseEntity>>> getExpensesByGroup(String groupId) async {
    try {
      final expenses = await _database.expensesDao.getExpensesByGroup(groupId);
      return Success(expenses);
    } catch (e) {
      log.e('Failed to get expenses for group $groupId: $e');
      return Failure(Exception('Failed to get expenses by group: $e'));
    }
  }

  @override
  Future<Result<List<ExpenseEntity>>> getAllExpenses() async {
    try {
      final expenses = await _database.expensesDao.getAllExpenses();
      return Success(expenses);
    } catch (e) {
      log.e('Failed to get all expenses: $e');
      return Failure(Exception('Failed to get all expenses: $e'));
    }
  }

  @override
  Future<Result<ExpenseEntity>> updateExpense(ExpenseEntity expense) async {
    try {
      // Atomic transaction: DB update + Queue entry
      await _database.transaction<void>(() async {
        await _database.expensesDao.updateExpense(expense);
        await _database.syncDao.enqueueOperation(
          entityType: 'expense',
          entityId: expense.id,
          operationType: 'update',
          metadata: expense.groupId,
        );
      });

      log.d('Updated expense: ${expense.title}');
      return Success(expense);
    } catch (e) {
      log.e('Failed to update expense ${expense.id}: $e');
      return Failure(Exception('Failed to update expense: $e'));
    }
  }

  @override
  Future<Result<void>> deleteExpense(String id) async {
    try {
      // Get expense first to retrieve groupId
      final expense = await _database.expensesDao.getExpenseById(id);
      if (expense == null) {
        return Failure(Exception('Expense not found: $id'));
      }

      // Atomic transaction: Soft delete + Queue entry
      await _database.transaction<void>(() async {
        await _database.expensesDao.softDeleteExpense(id);
        await _database.syncDao.enqueueOperation(
          entityType: 'expense',
          entityId: id,
          operationType: 'delete',
          metadata: expense.groupId,
        );
      });

      log.d('Deleted expense: ${expense.title}');
      return Success.unit();
    } catch (e) {
      log.e('Failed to delete expense $id: $e');
      return Failure(Exception('Failed to delete expense: $e'));
    }
  }

  @override
  Stream<List<ExpenseEntity>> watchExpensesByGroup(String groupId) {
    return _database.expensesDao.watchExpensesByGroup(groupId);
  }

  @override
  Stream<List<ExpenseEntity>> watchAllExpenses() {
    return _database.expensesDao.watchAllExpenses();
  }

  @override
  Future<Result<void>> addExpenseShare(ExpenseShareEntity share) async {
    try {
      // Atomic transaction: Add share + Queue entry
      await _database.transaction<void>(() async {
        await _database.expenseSharesDao.insertExpenseShare(share);
        await _database.syncDao.enqueueOperation(
          entityType: 'expense_share',
          entityId: '${share.expenseId}_${share.userId}',
          operationType: 'create',
          metadata: share.expenseId,
        );
      });

      log.d('Added share for expense ${share.expenseId}');
      return Success.unit();
    } catch (e) {
      log.e('Failed to add expense share: $e');
      return Failure(Exception('Failed to add expense share: $e'));
    }
  }

  @override
  Future<Result<List<ExpenseShareEntity>>> getExpenseShares(
    String expenseId,
  ) async {
    try {
      final shares = await _database.expenseSharesDao.getExpenseShares(
        expenseId,
      );
      return Success(shares);
    } catch (e) {
      log.e('Failed to get shares for expense $expenseId: $e');
      return Failure(Exception('Failed to get expense shares: $e'));
    }
  }
}
