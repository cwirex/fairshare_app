import 'package:fairshare_app/core/database/app_database.dart';
import 'package:fairshare_app/core/database/DAOs/expenses_dao.dart';
import 'package:fairshare_app/core/database/DAOs/expense_shares_dao.dart';
import 'package:fairshare_app/core/database/DAOs/sync_dao.dart';
import 'package:fairshare_app/features/expenses/data/repositories/synced_expense_repository.dart';
import 'package:fairshare_app/features/expenses/domain/entities/expense_entity.dart';
import 'package:fairshare_app/features/expenses/domain/entities/expense_share_entity.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'synced_expense_repository_test.mocks.dart';

@GenerateMocks([AppDatabase, ExpensesDao, ExpenseSharesDao, SyncDao])
void main() {
  late MockAppDatabase mockDatabase;
  late MockExpensesDao mockExpensesDao;
  late MockExpenseSharesDao mockExpenseSharesDao;
  late MockSyncDao mockSyncDao;
  late SyncedExpenseRepository repository;

  setUp(() {
    mockDatabase = MockAppDatabase();
    mockExpensesDao = MockExpensesDao();
    mockExpenseSharesDao = MockExpenseSharesDao();
    mockSyncDao = MockSyncDao();

    // Wire up the DAOs to the mock database
    when(mockDatabase.expensesDao).thenReturn(mockExpensesDao);
    when(mockDatabase.expenseSharesDao).thenReturn(mockExpenseSharesDao);
    when(mockDatabase.syncDao).thenReturn(mockSyncDao);

    repository = SyncedExpenseRepository(mockDatabase);
  });

  group('SyncedExpenseRepository', () {
    final testExpense = ExpenseEntity(
      id: 'expense123',
      groupId: 'group123',
      title: 'Test Expense',
      amount: 100.0,
      currency: 'USD',
      paidBy: 'user1',
      shareWithEveryone: true,
      expenseDate: DateTime(2025, 1, 1),
      createdAt: DateTime(2025, 1, 1),
      updatedAt: DateTime(2025, 1, 1),
      deletedAt: null,
    );

    group('createExpense', () {
      test('should insert expense and enqueue operation atomically', () async {
        // Arrange
        when(mockDatabase.transaction(any)).thenAnswer((invocation) async {
          final callback = invocation.positionalArguments[0] as Function();
          await callback();
          return null;
        });
        when(mockExpensesDao.insertExpense(any)).thenAnswer((_) async {});
        when(
          mockSyncDao.enqueueOperation(
            entityType: anyNamed('entityType'),
            entityId: anyNamed('entityId'),
            operationType: anyNamed('operationType'),
            metadata: anyNamed('metadata'),
          ),
        ).thenAnswer((_) async {});

        // Act
        final result = await repository.createExpense(testExpense);

        // Assert
        expect(result.isSuccess(), true);
        verify(mockDatabase.transaction<void>(any)).called(1);
        verify(mockExpensesDao.insertExpense(testExpense)).called(1);
        verify(
          mockSyncDao.enqueueOperation(
            entityType: 'expense',
            entityId: 'expense123',
            operationType: 'create',
            metadata: 'group123',
          ),
        ).called(1);
      });

      test('should return failure if database operation fails', () async {
        // Arrange
        when(mockDatabase.transaction<void>(any)).thenThrow(Exception('DB Error'));

        // Act
        final result = await repository.createExpense(testExpense);

        // Assert
        expect(result.isError(), true);
        expect(result.exceptionOrNull()!.toString(), contains('DB Error'));
      });
    });

    group('getExpenseById', () {
      test('should return expense if found', () async {
        // Arrange
        when(
          mockExpensesDao.getExpenseById('expense123'),
        ).thenAnswer((_) async => testExpense);

        // Act
        final result = await repository.getExpenseById('expense123');

        // Assert
        expect(result.isSuccess(), true);
        expect(result.getOrNull(), testExpense);
      });

      test('should return failure if expense not found', () async {
        // Arrange
        when(
          mockExpensesDao.getExpenseById('nonexistent'),
        ).thenAnswer((_) async => null);

        // Act
        final result = await repository.getExpenseById('nonexistent');

        // Assert
        expect(result.isError(), true);
        expect(result.exceptionOrNull()!.toString(), contains('not found'));
      });
    });

    group('updateExpense', () {
      test('should update expense and enqueue operation atomically', () async {
        // Arrange
        when(mockDatabase.transaction(any)).thenAnswer((invocation) async {
          final callback = invocation.positionalArguments[0] as Function();
          await callback();
          return null;
        });
        when(mockExpensesDao.updateExpense(any)).thenAnswer((_) async {});
        when(
          mockSyncDao.enqueueOperation(
            entityType: anyNamed('entityType'),
            entityId: anyNamed('entityId'),
            operationType: anyNamed('operationType'),
            metadata: anyNamed('metadata'),
          ),
        ).thenAnswer((_) async {});

        // Act
        final result = await repository.updateExpense(testExpense);

        // Assert
        expect(result.isSuccess(), true);
        verify(mockDatabase.transaction<void>(any)).called(1);
        verify(mockExpensesDao.updateExpense(testExpense)).called(1);
        verify(
          mockSyncDao.enqueueOperation(
            entityType: 'expense',
            entityId: 'expense123',
            operationType: 'update',
            metadata: 'group123',
          ),
        ).called(1);
      });
    });

    group('deleteExpense', () {
      test(
        'should soft delete expense and enqueue operation atomically',
        () async {
          // Arrange
          when(
            mockExpensesDao.getExpenseById('expense123'),
          ).thenAnswer((_) async => testExpense);
          when(mockDatabase.transaction(any)).thenAnswer((invocation) async {
            final callback = invocation.positionalArguments[0] as Function();
            await callback();
            return null;
          });
          when(mockExpensesDao.softDeleteExpense(any)).thenAnswer((_) async {});
          when(
            mockSyncDao.enqueueOperation(
              entityType: anyNamed('entityType'),
              entityId: anyNamed('entityId'),
              operationType: anyNamed('operationType'),
              metadata: anyNamed('metadata'),
            ),
          ).thenAnswer((_) async {});

          // Act
          final result = await repository.deleteExpense('expense123');

          // Assert
          expect(result.isSuccess(), true);
          verify(mockDatabase.transaction<void>(any)).called(1);
          verify(
            mockExpensesDao.softDeleteExpense('expense123'),
          ).called(1);
          verify(
            mockSyncDao.enqueueOperation(
              entityType: 'expense',
              entityId: 'expense123',
              operationType: 'delete',
              metadata: 'group123',
            ),
          ).called(1);
        },
      );

      test('should return failure if expense not found for deletion', () async {
        // Arrange
        when(
          mockExpensesDao.getExpenseById('nonexistent'),
        ).thenAnswer((_) async => null);

        // Act
        final result = await repository.deleteExpense('nonexistent');

        // Assert
        expect(result.isError(), true);
        expect(result.exceptionOrNull()!.toString(), contains('not found'));
      });
    });

    group('addExpenseShare', () {
      final testShare = ExpenseShareEntity(
        expenseId: 'expense123',
        userId: 'user456',
        shareAmount: 50.0,
      );

      test('should add share and enqueue operation atomically', () async {
        // Arrange
        when(mockDatabase.transaction(any)).thenAnswer((invocation) async {
          final callback = invocation.positionalArguments[0] as Function();
          await callback();
          return null;
        });
        when(mockExpenseSharesDao.insertExpenseShare(any)).thenAnswer((_) async {});
        when(
          mockSyncDao.enqueueOperation(
            entityType: anyNamed('entityType'),
            entityId: anyNamed('entityId'),
            operationType: anyNamed('operationType'),
            metadata: anyNamed('metadata'),
          ),
        ).thenAnswer((_) async {});

        // Act
        final result = await repository.addExpenseShare(testShare);

        // Assert
        expect(result.isSuccess(), true);
        verify(mockDatabase.transaction<void>(any)).called(1);
        verify(
          mockExpenseSharesDao.insertExpenseShare(testShare),
        ).called(1);
        verify(
          mockSyncDao.enqueueOperation(
            entityType: 'expense_share',
            entityId: 'expense123_user456',
            operationType: 'create',
            metadata: 'expense123',
          ),
        ).called(1);
      });
    });

    group('getExpenseShares', () {
      test('should return list of shares for expense', () async {
        // Arrange
        final testShares = [
          ExpenseShareEntity(
            expenseId: 'expense123',
            userId: 'user1',
            shareAmount: 50.0,
          ),
          ExpenseShareEntity(
            expenseId: 'expense123',
            userId: 'user2',
            shareAmount: 50.0,
          ),
        ];
        when(
          mockExpenseSharesDao.getExpenseShares('expense123'),
        ).thenAnswer((_) async => testShares);

        // Act
        final result = await repository.getExpenseShares('expense123');

        // Assert
        expect(result.isSuccess(), true);
        expect(result.getOrNull()!.length, 2);
        verify(
          mockExpenseSharesDao.getExpenseShares('expense123'),
        ).called(1);
      });
    });
  });
}
