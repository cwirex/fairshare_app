import 'package:fairshare_app/features/groups/domain/entities/group_entity.dart';
import 'package:fairshare_app/features/groups/domain/repositories/group_repository.dart';
import 'package:fairshare_app/features/groups/domain/use_cases/create_group_use_case.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'create_group_use_case_test.mocks.dart';

@GenerateMocks([GroupRepository])
void main() {
  late MockGroupRepository mockRepository;
  late CreateGroupUseCase useCase;

  setUp(() {
    mockRepository = MockGroupRepository();
    useCase = CreateGroupUseCase(mockRepository);
  });

  group('CreateGroupUseCase', () {
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
      test('should throw exception when display name is empty', () {
        // Arrange
        final invalidGroup = testGroup.copyWith(displayName: '');

        // Act & Assert
        expect(
          () => useCase.validate(invalidGroup),
          throwsA(isA<Exception>()),
        );
      });

      test('should throw exception when display name is only whitespace', () {
        // Arrange
        final invalidGroup = testGroup.copyWith(displayName: '   ');

        // Act & Assert
        expect(
          () => useCase.validate(invalidGroup),
          throwsA(isA<Exception>()),
        );
      });

      test('should throw exception when display name is too short', () {
        // Arrange
        final invalidGroup = testGroup.copyWith(displayName: 'A');

        // Act & Assert
        expect(
          () => useCase.validate(invalidGroup),
          throwsA(isA<Exception>()),
        );
      });

      test('should throw exception when display name is too long', () {
        // Arrange
        final longName = 'A' * 101;
        final invalidGroup = testGroup.copyWith(displayName: longName);

        // Act & Assert
        expect(
          () => useCase.validate(invalidGroup),
          throwsA(isA<Exception>()),
        );
      });

      test('should throw exception when default currency is empty', () {
        // Arrange
        final invalidGroup = testGroup.copyWith(defaultCurrency: '');

        // Act & Assert
        expect(
          () => useCase.validate(invalidGroup),
          throwsA(isA<Exception>()),
        );
      });

      test('should not throw exception when group is valid', () {
        // Act & Assert
        expect(() => useCase.validate(testGroup), returnsNormally);
      });

      test('should accept group name with exactly 2 characters', () {
        // Arrange
        final validGroup = testGroup.copyWith(displayName: 'AB');

        // Act & Assert
        expect(() => useCase.validate(validGroup), returnsNormally);
      });

      test('should accept group name with exactly 100 characters', () {
        // Arrange
        final validName = 'A' * 100;
        final validGroup = testGroup.copyWith(displayName: validName);

        // Act & Assert
        expect(() => useCase.validate(validGroup), returnsNormally);
      });
    });

    group('execute', () {
      test('should call repository createGroup with valid group', () async {
        // Arrange
        when(mockRepository.createGroup(any))
            .thenAnswer((_) async => testGroup);

        // Act
        final result = await useCase(testGroup);

        // Assert
        expect(result.isSuccess(), true);
        expect(result.getOrNull(), testGroup);
        verify(mockRepository.createGroup(testGroup)).called(1);
      });

      test('should return failure when repository throws exception', () async {
        // Arrange
        when(mockRepository.createGroup(any))
            .thenThrow(Exception('Database error'));

        // Act
        final result = await useCase(testGroup);

        // Assert
        expect(result.isError(), true);
        expect(result.exceptionOrNull()!.toString(), contains('Database error'));
      });

      test('should return failure when validation fails', () async {
        // Arrange
        final invalidGroup = testGroup.copyWith(displayName: '');

        // Act
        final result = await useCase(invalidGroup);

        // Assert
        expect(result.isError(), true);
        expect(
          result.exceptionOrNull()!.toString(),
          contains('Group name is required'),
        );
        verifyNever(mockRepository.createGroup(any));
      });
    });
  });
}
