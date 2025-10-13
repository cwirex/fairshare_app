import 'package:fairshare_app/features/expenses/domain/entities/expense_entity.dart';
import 'package:fairshare_app/features/expenses/domain/repositories/expense_repository.dart';
import 'package:fairshare_app/features/expenses/domain/use_cases/get_expenses_by_group_use_case.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'get_expenses_by_group_use_case_test.mocks.dart';

@GenerateMocks([ExpenseRepository])
void main() {
  late MockExpenseRepository mockRepository;
  late GetExpensesByGroupUseCase useCase;

  setUp(() {
    mockRepository = MockExpenseRepository();
    useCase = GetExpensesByGroupUseCase(mockRepository);
  });

  group('GetExpensesByGroupUseCase', () {
    const groupId = 'group123';
    final testExpenses = [
      ExpenseEntity(
        id: 'expense1',
        groupId: groupId,
        title: 'Expense 1',
        amount: 100.0,
        currency: 'USD',
        paidBy: 'user1',
        shareWithEveryone: true,
        expenseDate: DateTime(2025, 1, 1),
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 1),
        deletedAt: null,
      ),
      ExpenseEntity(
        id: 'expense2',
        groupId: groupId,
        title: 'Expense 2',
        amount: 200.0,
        currency: 'USD',
        paidBy: 'user2',
        shareWithEveryone: true,
        expenseDate: DateTime(2025, 1, 2),
        createdAt: DateTime(2025, 1, 2),
        updatedAt: DateTime(2025, 1, 2),
        deletedAt: null,
      ),
    ];

    group('validate', () {
      test('should throw exception when group ID is empty', () {
        // Act & Assert
        expect(
          () => useCase.validate(''),
          throwsA(isA<Exception>()),
        );
      });

      test('should throw exception when group ID is only whitespace', () {
        // Act & Assert
        expect(
          () => useCase.validate('   '),
          throwsA(isA<Exception>()),
        );
      });

      test('should not throw exception when group ID is valid', () {
        // Act & Assert
        expect(() => useCase.validate(groupId), returnsNormally);
      });
    });

    group('execute', () {
      test('should return list of expenses for group', () async {
        // Arrange
        when(mockRepository.getExpensesByGroup(any))
            .thenAnswer((_) async => testExpenses);

        // Act
        final result = await useCase(groupId);

        // Assert
        expect(result.isSuccess(), true);
        expect(result.getOrNull(), testExpenses);
        expect(result.getOrNull()!.length, 2);
        verify(mockRepository.getExpensesByGroup(groupId)).called(1);
      });

      test('should return empty list when no expenses found', () async {
        // Arrange
        when(mockRepository.getExpensesByGroup(any))
            .thenAnswer((_) async => []);

        // Act
        final result = await useCase(groupId);

        // Assert
        expect(result.isSuccess(), true);
        expect(result.getOrNull(), []);
        expect(result.getOrNull()!.length, 0);
      });

      test('should return failure when repository throws exception', () async {
        // Arrange
        when(mockRepository.getExpensesByGroup(any))
            .thenThrow(Exception('Database error'));

        // Act
        final result = await useCase(groupId);

        // Assert
        expect(result.isError(), true);
        expect(result.exceptionOrNull()!.toString(), contains('Database error'));
      });

      test('should return failure when validation fails', () async {
        // Act
        final result = await useCase('');

        // Assert
        expect(result.isError(), true);
        expect(
          result.exceptionOrNull()!.toString(),
          contains('Group ID is required'),
        );
        verifyNever(mockRepository.getExpensesByGroup(any));
      });
    });
  });
}
