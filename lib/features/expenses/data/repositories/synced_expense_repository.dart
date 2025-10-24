import 'package:fairshare_app/core/constants/entity_type.dart';
import 'package:fairshare_app/core/database/app_database.dart';
import 'package:fairshare_app/core/database/interfaces/dao_interfaces.dart';
import 'package:fairshare_app/core/events/event_broker_interface.dart';
import 'package:fairshare_app/core/events/expense_events.dart';
import 'package:fairshare_app/core/events/sync_events.dart';
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
/// - Fires events after successful operations
/// - User-scoped: ownerId is injected at construction time
class SyncedExpenseRepository with LoggerMixin implements ExpenseRepository {
  final AppDatabase _database;
  final IExpensesDao _expensesDao;
  final IExpenseSharesDao _expenseSharesDao;
  final ISyncDao _syncDao;
  final IEventBroker _eventBroker;
  final String ownerId; // ID of the user who owns this repository instance

  SyncedExpenseRepository({
    required AppDatabase database,
    required IExpensesDao expensesDao,
    required IExpenseSharesDao expenseSharesDao,
    required ISyncDao syncDao,
    required IEventBroker eventBroker,
    required this.ownerId,
  }) : _database = database,
       _expensesDao = expensesDao,
       _expenseSharesDao = expenseSharesDao,
       _syncDao = syncDao,
       _eventBroker = eventBroker;

  @override
  Future<ExpenseEntity> createExpense(ExpenseEntity expense) async {
    // Atomic transaction: DB insert + Queue entry
    await _database.transaction<void>(() async {
      await _expensesDao.insertExpense(expense);
      await _syncDao.enqueueOperation(
        ownerId: ownerId,
        entityType: EntityType.expense,
        entityId: expense.id,
        operationType: 'create',
        metadata: expense.groupId,
      );
    });

    // Fire events after successful operation
    _eventBroker.fire(ExpenseCreated(expense));
    _eventBroker.fire(UploadQueueItemAdded('createExpense'));
    log.d('Created expense: ${expense.title} by owner: $ownerId');
    return expense;
  }

  @override
  Future<ExpenseEntity> getExpenseById(String id) async {
    final expense = await _expensesDao.getExpenseById(id);
    if (expense == null) {
      throw Exception('Expense not found: $id');
    }
    return expense;
  }

  @override
  Future<List<ExpenseEntity>> getExpensesByGroup(String groupId) async {
    final expenses = await _expensesDao.getExpensesByGroup(groupId);
    return expenses;
  }

  @override
  Future<List<ExpenseEntity>> getAllExpenses() async {
    final expenses = await _expensesDao.getAllExpenses();
    return expenses;
  }

  @override
  Future<ExpenseEntity> updateExpense(ExpenseEntity expense) async {
    await _database.transaction<void>(() async {
      await _expensesDao.updateExpense(expense);
      await _syncDao.enqueueOperation(
        ownerId: ownerId,
        entityType: EntityType.expense,
        entityId: expense.id,
        operationType: 'update',
        metadata: expense.groupId,
      );
    });

    // Fire events after successful operation
    _eventBroker.fire(ExpenseUpdated(expense));
    _eventBroker.fire(UploadQueueItemAdded('updateExpense'));
    log.d('Updated expense: ${expense.title} by owner: $ownerId');
    return expense;
  }

  @override
  Future<void> deleteExpense(String id) async {
    // Get expense first to retrieve groupId
    final expense = await _expensesDao.getExpenseById(id);
    if (expense == null) {
      log.e('Expense not found for deletion: $id');
      throw Exception('Expense not found: $id');
    }

    // Atomic transaction: Soft delete + Queue entry
    await _database.transaction<void>(() async {
      await _expensesDao.softDeleteExpense(id);
      await _syncDao.enqueueOperation(
        ownerId: ownerId,
        entityType: EntityType.expense,
        entityId: id,
        operationType: 'delete',
        metadata: expense.groupId,
      );
    });

    // Fire events after successful operation
    _eventBroker.fire(ExpenseDeleted(id, expense.groupId));
    _eventBroker.fire(UploadQueueItemAdded('deleteExpense'));
    log.d('Deleted expense: ${expense.title} by owner: $ownerId');
    return Future.value();
  }

  @override
  Stream<List<ExpenseEntity>> watchExpensesByGroup(String groupId) {
    return _expensesDao.watchExpensesByGroup(groupId);
  }

  @override
  Stream<List<ExpenseEntity>> watchAllExpenses() {
    return _expensesDao.watchAllExpenses();
  }

  Future<Result<void>> addExpenseShare(ExpenseShareEntity share) async {
    try {
      // Atomic transaction: Add share + Queue entry
      await _database.transaction<void>(() async {
        await _expenseSharesDao.insertExpenseShare(share);
        await _syncDao.enqueueOperation(
          ownerId: ownerId,
          entityType: EntityType.expenseShare,
          entityId: '${share.expenseId}_${share.userId}',
          operationType: 'create',
          metadata: share.expenseId,
        );
      });

      // Fire events after successful operation
      _eventBroker.fire(ExpenseShareAdded(share));
      _eventBroker.fire(UploadQueueItemAdded('addExpenseShare'));
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
      final shares = await _expenseSharesDao.getExpenseShares(expenseId);
      return Success(shares);
    } catch (e) {
      log.e('Failed to get shares for expense $expenseId: $e');
      return Failure(Exception('Failed to get expense shares: $e'));
    }
  }
}
