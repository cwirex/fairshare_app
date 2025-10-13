import 'package:fairshare_app/features/groups/domain/entities/group_entity.dart';
import 'package:fairshare_app/features/groups/domain/repositories/group_repository.dart';
import 'package:fairshare_app/features/groups/domain/use_cases/join_group_by_code_use_case.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'join_group_by_code_use_case_test.mocks.dart';

@GenerateMocks([GroupRepository])
void main() {
  late MockGroupRepository mockRepository;
  late JoinGroupByCodeUseCase useCase;

  setUp(() {
    mockRepository = MockGroupRepository();
    useCase = JoinGroupByCodeUseCase(mockRepository);
  });

  group('JoinGroupByCodeUseCase', () {
    const testParams = JoinGroupByCodeParams(
      groupCode: 'ABC123',
      userId: 'user456',
    );

    final testGroup = GroupEntity(
      id: 'group123',
      displayName: 'Test Group',
      avatarUrl: '',
      isPersonal: false,
      defaultCurrency: 'USD',
      createdAt: DateTime(2025, 1, 1),
      updatedAt: DateTime(2025, 1, 1),
      lastActivityAt: DateTime(2025, 1, 1),
      deletedAt: null,
    );

    group('validate', () {
      test('should throw exception when group code is empty', () {
        // Arrange
        const invalidParams = JoinGroupByCodeParams(
          groupCode: '',
          userId: 'user456',
        );

        // Act & Assert
        expect(
          () => useCase.validate(invalidParams),
          throwsA(isA<Exception>()),
        );
      });

      test('should throw exception when group code is only whitespace', () {
        // Arrange
        const invalidParams = JoinGroupByCodeParams(
          groupCode: '   ',
          userId: 'user456',
        );

        // Act & Assert
        expect(
          () => useCase.validate(invalidParams),
          throwsA(isA<Exception>()),
        );
      });

      test('should throw exception when user ID is empty', () {
        // Arrange
        const invalidParams = JoinGroupByCodeParams(
          groupCode: 'ABC123',
          userId: '',
        );

        // Act & Assert
        expect(
          () => useCase.validate(invalidParams),
          throwsA(isA<Exception>()),
        );
      });

      test('should throw exception when user ID is only whitespace', () {
        // Arrange
        const invalidParams = JoinGroupByCodeParams(
          groupCode: 'ABC123',
          userId: '   ',
        );

        // Act & Assert
        expect(
          () => useCase.validate(invalidParams),
          throwsA(isA<Exception>()),
        );
      });

      test('should not throw exception when params are valid', () {
        // Act & Assert
        expect(() => useCase.validate(testParams), returnsNormally);
      });
    });

    group('execute', () {
      test('should call repository joinGroupByCode with valid params', () async {
        // Arrange
        when(mockRepository.joinGroupByCode(any, any))
            .thenAnswer((_) async => testGroup);

        // Act
        final result = await useCase(testParams);

        // Assert
        expect(result.isSuccess(), true);
        expect(result.getOrNull(), testGroup);
        verify(mockRepository.joinGroupByCode('ABC123', 'user456')).called(1);
      });

      test('should return failure when repository throws exception', () async {
        // Arrange
        when(mockRepository.joinGroupByCode(any, any))
            .thenThrow(Exception('Group not found'));

        // Act
        final result = await useCase(testParams);

        // Assert
        expect(result.isError(), true);
        expect(
          result.exceptionOrNull()!.toString(),
          contains('Group not found'),
        );
      });

      test('should return failure when validation fails', () async {
        // Arrange
        const invalidParams = JoinGroupByCodeParams(
          groupCode: '',
          userId: 'user456',
        );

        // Act
        final result = await useCase(invalidParams);

        // Assert
        expect(result.isError(), true);
        expect(
          result.exceptionOrNull()!.toString(),
          contains('Group code is required'),
        );
        verifyNever(mockRepository.joinGroupByCode(any, any));
      });
    });
  });
}
