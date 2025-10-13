import 'package:fairshare_app/features/expenses/domain/entities/expense_entity.dart';
import 'package:fairshare_app/features/expenses/domain/repositories/expense_repository.dart';
import 'package:fairshare_app/features/expenses/domain/use_cases/update_expense_use_case.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'update_expense_use_case_test.mocks.dart';

@GenerateMocks([ExpenseRepository])
void main() {
  late MockExpenseRepository mockRepository;
  late UpdateExpenseUseCase useCase;

  setUp(() {
    mockRepository = MockExpenseRepository();
    useCase = UpdateExpenseUseCase(mockRepository);
  });

  group('UpdateExpenseUseCase', () {
    final testExpense = ExpenseEntity(
      id: 'expense123',
      groupId: 'group123',
      title: 'Updated Expense',
      amount: 150.0,
      currency: 'USD',
      paidBy: 'user1',
      shareWithEveryone: true,
      expenseDate: DateTime(2025, 1, 1),
      createdAt: DateTime(2025, 1, 1),
      updatedAt: DateTime(2025, 1, 2),
      deletedAt: null,
    );

    group('validate', () {
      test('should throw exception when expense ID is empty', () {
        // Arrange
        final invalidExpense = testExpense.copyWith(id: '');

        // Act & Assert
        expect(
          () => useCase.validate(invalidExpense),
          throwsA(isA<Exception>()),
        );
      });

      test('should throw exception when amount is zero', () {
        // Arrange
        final invalidExpense = testExpense.copyWith(amount: 0);

        // Act & Assert
        expect(
          () => useCase.validate(invalidExpense),
          throwsA(isA<Exception>()),
        );
      });

      test('should throw exception when amount is negative', () {
        // Arrange
        final invalidExpense = testExpense.copyWith(amount: -10);

        // Act & Assert
        expect(
          () => useCase.validate(invalidExpense),
          throwsA(isA<Exception>()),
        );
      });

      test('should throw exception when title is empty', () {
        // Arrange
        final invalidExpense = testExpense.copyWith(title: '');

        // Act & Assert
        expect(
          () => useCase.validate(invalidExpense),
          throwsA(isA<Exception>()),
        );
      });

      test('should not throw exception when expense is valid', () {
        // Act & Assert
        expect(() => useCase.validate(testExpense), returnsNormally);
      });
    });

    group('execute', () {
      test('should call repository updateExpense with valid expense', () async {
        // Arrange
        when(mockRepository.updateExpense(any))
            .thenAnswer((_) async => testExpense);

        // Act
        final result = await useCase(testExpense);

        // Assert
        expect(result.isSuccess(), true);
        expect(result.getOrNull(), testExpense);
        verify(mockRepository.updateExpense(testExpense)).called(1);
      });

      test('should return failure when repository throws exception', () async {
        // Arrange
        when(mockRepository.updateExpense(any))
            .thenThrow(Exception('Database error'));

        // Act
        final result = await useCase(testExpense);

        // Assert
        expect(result.isError(), true);
        expect(result.exceptionOrNull()!.toString(), contains('Database error'));
      });

      test('should return failure when validation fails', () async {
        // Arrange
        final invalidExpense = testExpense.copyWith(id: '');

        // Act
        final result = await useCase(invalidExpense);

        // Assert
        expect(result.isError(), true);
        expect(
          result.exceptionOrNull()!.toString(),
          contains('Expense ID is required'),
        );
        verifyNever(mockRepository.updateExpense(any));
      });
    });
  });
}
