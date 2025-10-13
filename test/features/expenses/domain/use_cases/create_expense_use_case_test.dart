import 'package:fairshare_app/features/expenses/domain/entities/expense_entity.dart';
import 'package:fairshare_app/features/expenses/domain/repositories/expense_repository.dart';
import 'package:fairshare_app/features/expenses/domain/use_cases/create_expense_use_case.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'create_expense_use_case_test.mocks.dart';

@GenerateMocks([ExpenseRepository])
void main() {
  late MockExpenseRepository mockRepository;
  late CreateExpenseUseCase useCase;

  setUp(() {
    mockRepository = MockExpenseRepository();
    useCase = CreateExpenseUseCase(mockRepository);
  });

  group('CreateExpenseUseCase', () {
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

    group('validate', () {
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

      test('should throw exception when title is only whitespace', () {
        // Arrange
        final invalidExpense = testExpense.copyWith(title: '   ');

        // Act & Assert
        expect(
          () => useCase.validate(invalidExpense),
          throwsA(isA<Exception>()),
        );
      });

      test('should throw exception when groupId is empty', () {
        // Arrange
        final invalidExpense = testExpense.copyWith(groupId: '');

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
      test('should call repository createExpense with valid expense', () async {
        // Arrange
        when(mockRepository.createExpense(any))
            .thenAnswer((_) async => testExpense);

        // Act
        final result = await useCase(testExpense);

        // Assert
        expect(result.isSuccess(), true);
        expect(result.getOrNull(), testExpense);
        verify(mockRepository.createExpense(testExpense)).called(1);
      });

      test('should return failure when repository throws exception', () async {
        // Arrange
        when(mockRepository.createExpense(any))
            .thenThrow(Exception('Database error'));

        // Act
        final result = await useCase(testExpense);

        // Assert
        expect(result.isError(), true);
        expect(result.exceptionOrNull()!.toString(), contains('Database error'));
      });

      test('should return failure when validation fails', () async {
        // Arrange
        final invalidExpense = testExpense.copyWith(amount: 0);

        // Act
        final result = await useCase(invalidExpense);

        // Assert
        expect(result.isError(), true);
        expect(
          result.exceptionOrNull()!.toString(),
          contains('Amount must be greater than zero'),
        );
        verifyNever(mockRepository.createExpense(any));
      });
    });
  });
}
