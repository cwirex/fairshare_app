import 'package:fairshare_app/features/expenses/domain/entities/expense_entity.dart';
import 'package:fairshare_app/features/expenses/domain/repositories/expense_repository.dart';
import 'package:fairshare_app/features/expenses/domain/use_cases/get_expense_use_case.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'get_expense_use_case_test.mocks.dart';

@GenerateMocks([ExpenseRepository])
void main() {
  late MockExpenseRepository mockRepository;
  late GetExpenseUseCase useCase;

  setUp(() {
    mockRepository = MockExpenseRepository();
    useCase = GetExpenseUseCase(mockRepository);
  });

  group('GetExpenseUseCase', () {
    const expenseId = 'expense123';
    final testExpense = ExpenseEntity(
      id: expenseId,
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

    group('validate', () {
      test('should throw exception when expense ID is empty', () {
        // Act & Assert
        expect(
          () => useCase.validate(''),
          throwsA(isA<Exception>()),
        );
      });

      test('should throw exception when expense ID is only whitespace', () {
        // Act & Assert
        expect(
          () => useCase.validate('   '),
          throwsA(isA<Exception>()),
        );
      });

      test('should not throw exception when expense ID is valid', () {
        // Act & Assert
        expect(() => useCase.validate(expenseId), returnsNormally);
      });
    });

    group('execute', () {
      test('should return expense when found', () async {
        // Arrange
        when(mockRepository.getExpenseById(any))
            .thenAnswer((_) async => testExpense);

        // Act
        final result = await useCase(expenseId);

        // Assert
        expect(result.isSuccess(), true);
        expect(result.getOrNull(), testExpense);
        verify(mockRepository.getExpenseById(expenseId)).called(1);
      });

      test('should return failure when repository throws exception', () async {
        // Arrange
        when(mockRepository.getExpenseById(any))
            .thenThrow(Exception('Expense not found'));

        // Act
        final result = await useCase(expenseId);

        // Assert
        expect(result.isError(), true);
        expect(
          result.exceptionOrNull()!.toString(),
          contains('Expense not found'),
        );
      });

      test('should return failure when validation fails', () async {
        // Act
        final result = await useCase('');

        // Assert
        expect(result.isError(), true);
        expect(
          result.exceptionOrNull()!.toString(),
          contains('Expense ID is required'),
        );
        verifyNever(mockRepository.getExpenseById(any));
      });
    });
  });
}
