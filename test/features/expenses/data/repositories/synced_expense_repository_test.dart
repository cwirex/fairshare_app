import 'package:fairshare_app/core/database/app_database.dart';
import 'package:fairshare_app/features/expenses/data/repositories/synced_expense_repository.dart';
import 'package:fairshare_app/features/expenses/domain/entities/expense_entity.dart';
import 'package:fairshare_app/features/expenses/domain/entities/expense_share_entity.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'synced_expense_repository_test.mocks.dart';

@GenerateMocks([AppDatabase])
void main() {
  late MockAppDatabase mockDatabase;
  late SyncedExpenseRepository repository;

  setUp(() {
    mockDatabase = MockAppDatabase();
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
          return await callback();
        });
        when(mockDatabase.insertExpense(any)).thenAnswer((_) async {});
        when(mockDatabase.enqueueOperation(
          entityType: anyNamed('entityType'),
          entityId: anyNamed('entityId'),
          operationType: anyNamed('operationType'),
          metadata: anyNamed('metadata'),
        )).thenAnswer((_) async {});

        // Act
        final result = await repository.createExpense(testExpense);

        // Assert
        expect(result.isSuccess(), true);
        verify(mockDatabase.transaction(any)).called(1);
        verify(mockDatabase.insertExpense(testExpense)).called(1);
        verify(mockDatabase.enqueueOperation(
          entityType: 'expense',
          entityId: 'expense123',
          operationType: 'create',
          metadata: 'group123',
        )).called(1);
      });

      test('should return failure if database operation fails', () async {
        // Arrange
        when(mockDatabase.transaction(any)).thenThrow(Exception('DB Error'));

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
        when(mockDatabase.getExpenseById('expense123'))
            .thenAnswer((_) async => testExpense);

        // Act
        final result = await repository.getExpenseById('expense123');

        // Assert
        expect(result.isSuccess(), true);
        expect(result.getOrNull(), testExpense);
      });

      test('should return failure if expense not found', () async {
        // Arrange
        when(mockDatabase.getExpenseById('nonexistent'))
            .thenAnswer((_) async => null);

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
          return await callback();
        });
        when(mockDatabase.updateExpense(any)).thenAnswer((_) async {});
        when(mockDatabase.enqueueOperation(
          entityType: anyNamed('entityType'),
          entityId: anyNamed('entityId'),
          operationType: anyNamed('operationType'),
          metadata: anyNamed('metadata'),
        )).thenAnswer((_) async {});

        // Act
        final result = await repository.updateExpense(testExpense);

        // Assert
        expect(result.isSuccess(), true);
        verify(mockDatabase.transaction(any)).called(1);
        verify(mockDatabase.updateExpense(testExpense)).called(1);
        verify(mockDatabase.enqueueOperation(
          entityType: 'expense',
          entityId: 'expense123',
          operationType: 'update',
          metadata: 'group123',
        )).called(1);
      });
    });

    group('deleteExpense', () {
      test('should soft delete expense and enqueue operation atomically',
          () async {
        // Arrange
        when(mockDatabase.getExpenseById('expense123'))
            .thenAnswer((_) async => testExpense);
        when(mockDatabase.transaction(any)).thenAnswer((invocation) async {
          final callback = invocation.positionalArguments[0] as Function();
          return await callback();
        });
        when(mockDatabase.softDeleteExpense(any)).thenAnswer((_) async {});
        when(mockDatabase.enqueueOperation(
          entityType: anyNamed('entityType'),
          entityId: anyNamed('entityId'),
          operationType: anyNamed('operationType'),
          metadata: anyNamed('metadata'),
        )).thenAnswer((_) async {});

        // Act
        final result = await repository.deleteExpense('expense123');

        // Assert
        expect(result.isSuccess(), true);
        verify(mockDatabase.transaction(any)).called(1);
        verify(mockDatabase.softDeleteExpense('expense123')).called(1);
        verify(mockDatabase.enqueueOperation(
          entityType: 'expense',
          entityId: 'expense123',
          operationType: 'delete',
          metadata: 'group123',
        )).called(1);
      });

      test('should return failure if expense not found for deletion',
          () async {
        // Arrange
        when(mockDatabase.getExpenseById('nonexistent'))
            .thenAnswer((_) async => null);

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
          return await callback();
        });
        when(mockDatabase.insertExpenseShare(any)).thenAnswer((_) async {});
        when(mockDatabase.enqueueOperation(
          entityType: anyNamed('entityType'),
          entityId: anyNamed('entityId'),
          operationType: anyNamed('operationType'),
          metadata: anyNamed('metadata'),
        )).thenAnswer((_) async {});

        // Act
        final result = await repository.addExpenseShare(testShare);

        // Assert
        expect(result.isSuccess(), true);
        verify(mockDatabase.transaction(any)).called(1);
        verify(mockDatabase.insertExpenseShare(testShare)).called(1);
        verify(mockDatabase.enqueueOperation(
          entityType: 'expense_share',
          entityId: 'expense123_user456',
          operationType: 'create',
          metadata: 'expense123',
        )).called(1);
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
        when(mockDatabase.getExpenseShares('expense123'))
            .thenAnswer((_) async => testShares);

        // Act
        final result = await repository.getExpenseShares('expense123');

        // Assert
        expect(result.isSuccess(), true);
        expect(result.getOrNull()!.length, 2);
        verify(mockDatabase.getExpenseShares('expense123')).called(1);
      });
    });
  });
}
