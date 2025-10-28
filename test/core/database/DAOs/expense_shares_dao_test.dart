import 'package:drift/native.dart';
import 'package:fairshare_app/core/database/app_database.dart';
import 'package:fairshare_app/features/expenses/domain/entities/expense_share_entity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  group('ExpenseSharesDao', () {
    test('insertExpenseShare should add share to database', () async {
      // Arrange
      final share = ExpenseShareEntity(
        expenseId: 'exp1',
        userId: 'user1',
        shareAmount: 50.0,
      );

      // Act
      await database.expenseSharesDao.insertExpenseShare(share);

      // Assert
      final shares = await database.expenseSharesDao.getExpenseShares('exp1');
      expect(shares.length, 1);
      expect(shares[0].userId, 'user1');
      expect(shares[0].shareAmount, 50.0);
    });

    test('getExpenseShares should return all shares for expense', () async {
      // Arrange
      await database.expenseSharesDao.insertExpenseShare(
        ExpenseShareEntity(expenseId: 'exp1', userId: 'user1', shareAmount: 50.0),
      );
      await database.expenseSharesDao.insertExpenseShare(
        ExpenseShareEntity(expenseId: 'exp1', userId: 'user2', shareAmount: 50.0),
      );
      await database.expenseSharesDao.insertExpenseShare(
        ExpenseShareEntity(expenseId: 'exp2', userId: 'user1', shareAmount: 30.0),
      );

      // Act
      final shares = await database.expenseSharesDao.getExpenseShares('exp1');

      // Assert
      expect(shares.length, 2);
      expect(shares.map((s) => s.userId).toSet(), {'user1', 'user2'});
    });

    test('getExpenseShares should return empty list for non-existent expense',
        () async {
      // Act
      final shares =
          await database.expenseSharesDao.getExpenseShares('nonexistent');

      // Assert
      expect(shares.length, 0);
    });

    test('deleteExpenseShares should remove all shares for expense', () async {
      // Arrange
      await database.expenseSharesDao.insertExpenseShare(
        ExpenseShareEntity(expenseId: 'exp1', userId: 'user1', shareAmount: 50.0),
      );
      await database.expenseSharesDao.insertExpenseShare(
        ExpenseShareEntity(expenseId: 'exp1', userId: 'user2', shareAmount: 50.0),
      );

      // Act
      await database.expenseSharesDao.deleteExpenseShares('exp1');

      // Assert
      final shares = await database.expenseSharesDao.getExpenseShares('exp1');
      expect(shares.length, 0);
    });

    test('deleteExpenseShares should only delete shares for specific expense',
        () async {
      // Arrange
      await database.expenseSharesDao.insertExpenseShare(
        ExpenseShareEntity(expenseId: 'exp1', userId: 'user1', shareAmount: 50.0),
      );
      await database.expenseSharesDao.insertExpenseShare(
        ExpenseShareEntity(expenseId: 'exp2', userId: 'user1', shareAmount: 30.0),
      );

      // Act
      await database.expenseSharesDao.deleteExpenseShares('exp1');

      // Assert
      final exp1Shares = await database.expenseSharesDao.getExpenseShares('exp1');
      final exp2Shares = await database.expenseSharesDao.getExpenseShares('exp2');
      expect(exp1Shares.length, 0);
      expect(exp2Shares.length, 1);
    });
  });
}
