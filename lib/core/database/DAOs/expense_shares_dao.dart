import 'package:drift/drift.dart';
import 'package:fairshare_app/core/database/app_database.dart';
import 'package:fairshare_app/core/database/interfaces/dao_interfaces.dart';
import 'package:fairshare_app/core/database/tables/shares_table.dart';
import 'package:fairshare_app/features/expenses/domain/entities/expense_share_entity.dart';

part 'expense_shares_dao.g.dart';

@DriftAccessor(tables: [ExpenseShares])
class ExpenseSharesDao extends DatabaseAccessor<AppDatabase>
    with _$ExpenseSharesDaoMixin
    implements IExpenseSharesDao {
  final AppDatabase db;

  ExpenseSharesDao(this.db) : super(db);

  /// Insert a new expense share
  @override
  Future<void> insertExpenseShare(ExpenseShareEntity share) async {
    await into(expenseShares).insert(
      ExpenseSharesCompanion(
        expenseId: Value(share.expenseId),
        userId: Value(share.userId),
        shareAmount: Value(share.shareAmount),
      ),
    );
  }

  /// Get all shares for an expense
  @override
  Future<List<ExpenseShareEntity>> getExpenseShares(String expenseId) async {
    final query = select(expenseShares)
      ..where((s) => s.expenseId.equals(expenseId));
    final results = await query.get();
    return results.map(_expenseShareFromDb).toList();
  }

  /// Delete all shares for an expense
  @override
  Future<void> deleteExpenseShares(String expenseId) async {
    await (delete(expenseShares)
      ..where((s) => s.expenseId.equals(expenseId))).go();
  }

  ExpenseShareEntity _expenseShareFromDb(ExpenseShare dbShare) {
    return ExpenseShareEntity(
      expenseId: dbShare.expenseId,
      userId: dbShare.userId,
      shareAmount: dbShare.shareAmount,
    );
  }
}
