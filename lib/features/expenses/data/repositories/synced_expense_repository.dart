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
  Future<ExpenseEntity> createExpense(ExpenseEntity expense) async {
    // Atomic transaction: DB insert + Queue entry
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
    return expense;
  }

  @override
  Future<ExpenseEntity> getExpenseById(String id) async {
    final expense = await _database.expensesDao.getExpenseById(id);
    if (expense == null) {
      throw Failure(Exception('Expense not found: $id'));
    }
    return expense;
  }

  @override
  Future<List<ExpenseEntity>> getExpensesByGroup(String groupId) async {
    final expenses = await _database.expensesDao.getExpensesByGroup(groupId);
    return expenses;
  }

  @override
  Future<List<ExpenseEntity>> getAllExpenses() async {
    final expenses = await _database.expensesDao.getAllExpenses();
    return expenses;
  }

  @override
  Future<ExpenseEntity> updateExpense(ExpenseEntity expense) async {
    await _database.transaction<void>(() async {
      await _database.expensesDao.updateExpense(expense);
      await _database.syncDao.enqueueOperation(
        entityType: 'expense',
        entityId: expense.id,
        operationType: 'update',
        metadata: expense.groupId,
      );
    });

    return expense;
  }

  @override
  Future<void> deleteExpense(String id) async {
    // Get expense first to retrieve groupId
    final expense = await _database.expensesDao.getExpenseById(id);
    if (expense == null) {
      log.e('Expense not found for deletion: $id');
      throw Failure(Exception('Expense not found: $id'));
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
    return Future.value();
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
