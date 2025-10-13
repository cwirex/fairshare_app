import 'package:fairshare_app/core/constants/entity_type.dart';
import 'package:fairshare_app/core/database/app_database.dart';
import 'package:fairshare_app/features/expenses/domain/entities/expense_entity.dart';
import 'package:fairshare_app/features/expenses/domain/repositories/expense_repository.dart';
import 'package:result_dart/result_dart.dart';

/// Local implementation of ExpenseRepository using Drift database.
class LocalExpenseRepository implements ExpenseRepository {
  final AppDatabase _database;

  LocalExpenseRepository(this._database);

  @override
  Future<ExpenseEntity> createExpense(ExpenseEntity expense) async {
    // Atomic transaction: DB insert + Queue entry
    await _database.transaction(() async {
      await _database.expensesDao.insertExpense(expense);
      // All expenses are synced (personal group expenses too - for backup)
      await _database.syncDao.enqueueOperation(
        entityType: 'expense',
        entityId: expense.id,
        operationType: 'create',
      );
    });
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
    await _database.transaction(() async {
      await _database.expensesDao.updateExpense(expense);

      // All expenses are synced (personal group expenses too - for backup)
      await _database.syncDao.enqueueOperation(
        entityType: 'expense',
        entityId: expense.id,
        operationType: 'update',
      );
    });
    return expense;
  }

  @override
  Future<void> deleteExpense(String id) async {
    await _database.transaction(() async {
      // Get expense to retrieve groupId before deleting
      final expense = await _database.expensesDao.getExpenseById(id);
      final metadata =
          expense != null ? '{"groupId":"${expense.groupId}"}' : null;

      // All expenses are synced (personal group expenses too - for backup)
      await _database.syncDao.enqueueOperation(
        entityType: EntityType.expense.name,
        entityId: id,
        operationType: 'delete',
        metadata: metadata,
      );

      await _database.expensesDao.deleteExpense(id);
    });
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
}
