import 'package:fairshare_app/features/expenses/domain/repositories/expense_repository.dart';
import 'package:fairshare_app/features/expenses/domain/use_cases/delete_expense_use_case.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'delete_expense_use_case_test.mocks.dart';

@GenerateMocks([ExpenseRepository])
void main() {
  late MockExpenseRepository mockRepository;
  late DeleteExpenseUseCase useCase;

  setUp(() {
    mockRepository = MockExpenseRepository();
    useCase = DeleteExpenseUseCase(mockRepository);
  });

  group('DeleteExpenseUseCase', () {
    const expenseId = 'expense123';

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
      test('should call repository deleteExpense with valid ID', () async {
        // Arrange
        when(mockRepository.deleteExpense(any)).thenAnswer((_) async {});

        // Act
        final result = await useCase(expenseId);

        // Assert
        expect(result.isSuccess(), true);
        verify(mockRepository.deleteExpense(expenseId)).called(1);
      });

      test('should return failure when repository throws exception', () async {
        // Arrange
        when(mockRepository.deleteExpense(any))
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
        verifyNever(mockRepository.deleteExpense(any));
      });
    });
  });
}
