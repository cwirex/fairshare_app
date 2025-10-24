import 'package:drift/drift.dart';
import 'package:fairshare_app/core/database/app_database.dart';
import 'package:fairshare_app/core/database/interfaces/dao_interfaces.dart';
import 'package:fairshare_app/core/database/tables/expenses_table.dart';
import 'package:fairshare_app/core/events/event_broker.dart';
import 'package:fairshare_app/core/events/expense_events.dart';
import 'package:fairshare_app/core/logging/app_logger.dart';
import 'package:fairshare_app/features/expenses/domain/entities/expense_entity.dart';

part 'expenses_dao.g.dart';

@DriftAccessor(tables: [Expenses])
class ExpensesDao extends DatabaseAccessor<AppDatabase>
    with _$ExpensesDaoMixin, LoggerMixin
    implements IExpensesDao {
  final AppDatabase db;

  ExpensesDao(this.db) : super(db);

  /// Insert a new expense into the database
  @override
  Future<void> insertExpense(ExpenseEntity expense) async {
    await into(expenses).insert(
      ExpensesCompanion(
        id: Value(expense.id),
        groupId: Value(expense.groupId),
        title: Value(expense.title),
        amount: Value(expense.amount),
        currency: Value(expense.currency),
        paidBy: Value(expense.paidBy),
        shareWithEveryone: Value(expense.shareWithEveryone),
        expenseDate: Value(expense.expenseDate),
        createdAt: Value(expense.createdAt),
        updatedAt: Value(expense.updatedAt),
        deletedAt: Value(expense.deletedAt),
      ),
    );
    // Update group activity timestamp
    await db.groupsDao.updateGroupActivity(expense.groupId);
  }

  /// Get expense by ID
  /// Set [includeDeleted] to true to also query soft-deleted expenses
  @override
  Future<ExpenseEntity?> getExpenseById(
    String id, {
    bool includeDeleted = false,
  }) async {
    final query = select(expenses)..where((e) => e.id.equals(id));
    if (!includeDeleted) {
      query.where((e) => e.deletedAt.isNull());
    }
    final result = await query.getSingleOrNull();
    return result != null ? _expenseFromDb(result) : null;
  }

  /// Get all expenses for a specific group
  @override
  Future<List<ExpenseEntity>> getExpensesByGroup(String groupId) async {
    final query =
        select(expenses)
          ..where((e) => e.groupId.equals(groupId) & e.deletedAt.isNull())
          ..orderBy([(e) => OrderingTerm.desc(e.expenseDate)]);
    final results = await query.get();
    return results.map(_expenseFromDb).toList();
  }

  /// Get all expenses across all groups
  @override
  Future<List<ExpenseEntity>> getAllExpenses() async {
    final query =
        select(expenses)
          ..where((e) => e.deletedAt.isNull())
          ..orderBy([(e) => OrderingTerm.desc(e.expenseDate)]);
    final results = await query.get();
    return results.map(_expenseFromDb).toList();
  }

  /// Update expense timestamp after server upload
  @override
  Future<void> updateExpenseTimestamp(
    String id,
    DateTime serverTimestamp,
  ) async {
    await (update(expenses)..where(
      (e) => e.id.equals(id),
    )).write(ExpensesCompanion(updatedAt: Value(serverTimestamp)));
  }

  /// Update existing expense
  @override
  Future<void> updateExpense(ExpenseEntity expense) async {
    await update(expenses).replace(
      ExpensesCompanion(
        id: Value(expense.id),
        groupId: Value(expense.groupId),
        title: Value(expense.title),
        amount: Value(expense.amount),
        currency: Value(expense.currency),
        paidBy: Value(expense.paidBy),
        shareWithEveryone: Value(expense.shareWithEveryone),
        expenseDate: Value(expense.expenseDate),
        createdAt: Value(expense.createdAt),
        updatedAt: Value(DateTime.now()),
        deletedAt: Value(expense.deletedAt),
      ),
    );
    // Update group activity timestamp
    await db.groupsDao.updateGroupActivity(expense.groupId);
  }

  /// Delete expense by ID
  @override
  Future<void> deleteExpense(String id) async {
    await (delete(expenses)..where((e) => e.id.equals(id))).go();
  }

  /// Watch expenses for a specific group (stream)
  @override
  Stream<List<ExpenseEntity>> watchExpensesByGroup(String groupId) {
    final query =
        select(expenses)
          ..where((e) => e.groupId.equals(groupId) & e.deletedAt.isNull())
          ..orderBy([(e) => OrderingTerm.desc(e.expenseDate)]);
    return query.watch().map((rows) => rows.map(_expenseFromDb).toList());
  }

  /// Watch all expenses (stream)
  @override
  Stream<List<ExpenseEntity>> watchAllExpenses() {
    final query =
        select(expenses)
          ..where((e) => e.deletedAt.isNull())
          ..orderBy([(e) => OrderingTerm.desc(e.expenseDate)]);
    return query.watch().map((rows) => rows.map(_expenseFromDb).toList());
  }

  /// Insert or update an expense from remote sync (bypasses queue)
  /// Fires events to update UI when remote changes arrive
  ///
  /// [eventBroker] is passed in to maintain clean DAO architecture
  @override
  Future<void> upsertExpenseFromSync(
    ExpenseEntity expense,
    EventBroker eventBroker,
  ) async {
    final existing = await getExpenseById(expense.id, includeDeleted: true);

    if (existing == null) {
      // New expense from server - insert directly
      // Use insertOrReplace to handle race conditions and duplicate inserts
      await into(expenses).insert(
        ExpensesCompanion(
          id: Value(expense.id),
          groupId: Value(expense.groupId),
          title: Value(expense.title),
          amount: Value(expense.amount),
          currency: Value(expense.currency),
          paidBy: Value(expense.paidBy),
          shareWithEveryone: Value(expense.shareWithEveryone),
          expenseDate: Value(expense.expenseDate),
          createdAt: Value(expense.createdAt),
          updatedAt: Value(expense.updatedAt),
          deletedAt: Value(expense.deletedAt),
        ),
        mode: InsertMode.insertOrReplace,
      );

      // Fire event for remote creation
      eventBroker.fire(ExpenseCreated(expense));
      log.d('Remote expense created: ${expense.title}');
    } else {
      // Only update if remote version is newer (Last Write Wins)
      if (expense.updatedAt.isAfter(existing.updatedAt)) {
        await (update(expenses)..where((e) => e.id.equals(expense.id))).write(
          ExpensesCompanion(
            title: Value(expense.title),
            amount: Value(expense.amount),
            currency: Value(expense.currency),
            paidBy: Value(expense.paidBy),
            shareWithEveryone: Value(expense.shareWithEveryone),
            expenseDate: Value(expense.expenseDate),
            updatedAt: Value(expense.updatedAt),
            deletedAt: Value(expense.deletedAt),
          ),
        );

        // Fire event for remote update
        eventBroker.fire(ExpenseUpdated(expense));
        log.d('Remote expense updated: ${expense.title}');
      }
    }
  }

  /// Soft delete an expense (sets deletedAt timestamp)
  @override
  Future<void> softDeleteExpense(String id) async {
    await (update(expenses)..where((e) => e.id.equals(id))).write(
      ExpensesCompanion(
        deletedAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Restore a soft-deleted expense (clears deletedAt)
  @override
  Future<void> restoreExpense(String id) async {
    await (update(expenses)..where((e) => e.id.equals(id))).write(
      ExpensesCompanion(
        deletedAt: const Value(null),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Hard delete an expense (permanent deletion).
  /// Call after successful server deletion.
  @override
  Future<void> hardDeleteExpense(String id) async {
    // Delete shares first
    await (delete(db.expenseShares)..where((s) => s.expenseId.equals(id))).go();
    // Delete expense
    await (delete(expenses)..where((e) => e.id.equals(id))).go();
  }

  /// Convert database expense row to domain expense entity
  ExpenseEntity _expenseFromDb(Expense dbExpense) {
    return ExpenseEntity(
      id: dbExpense.id,
      groupId: dbExpense.groupId,
      title: dbExpense.title,
      amount: dbExpense.amount,
      currency: dbExpense.currency,
      paidBy: dbExpense.paidBy,
      shareWithEveryone: dbExpense.shareWithEveryone,
      expenseDate: dbExpense.expenseDate,
      createdAt: dbExpense.createdAt,
      updatedAt: dbExpense.updatedAt,
      deletedAt: dbExpense.deletedAt,
    );
  }
}
