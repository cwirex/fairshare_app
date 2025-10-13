import 'package:fairshare_app/features/groups/domain/repositories/group_repository.dart';
import 'package:fairshare_app/features/groups/domain/use_cases/remove_member_use_case.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'remove_member_use_case_test.mocks.dart';

@GenerateMocks([GroupRepository])
void main() {
  late MockGroupRepository mockRepository;
  late RemoveMemberUseCase useCase;

  setUp(() {
    mockRepository = MockGroupRepository();
    useCase = RemoveMemberUseCase(mockRepository);
  });

  group('RemoveMemberUseCase', () {
    const testParams = RemoveMemberParams(
      groupId: 'group123',
      userId: 'user456',
    );

    group('validate', () {
      test('should throw exception when group ID is empty', () {
        // Arrange
        const invalidParams = RemoveMemberParams(
          groupId: '',
          userId: 'user456',
        );

        // Act & Assert
        expect(
          () => useCase.validate(invalidParams),
          throwsA(isA<Exception>()),
        );
      });

      test('should throw exception when group ID is only whitespace', () {
        // Arrange
        const invalidParams = RemoveMemberParams(
          groupId: '   ',
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
        const invalidParams = RemoveMemberParams(
          groupId: 'group123',
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
        const invalidParams = RemoveMemberParams(
          groupId: 'group123',
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
      test('should call repository removeMember with valid params', () async {
        // Arrange
        when(mockRepository.removeMember(any, any)).thenAnswer((_) async {});

        // Act
        final result = await useCase(testParams);

        // Assert
        expect(result.isSuccess(), true);
        verify(mockRepository.removeMember('group123', 'user456')).called(1);
      });

      test('should return failure when repository throws exception', () async {
        // Arrange
        when(mockRepository.removeMember(any, any))
            .thenThrow(Exception('Failed to remove member'));

        // Act
        final result = await useCase(testParams);

        // Assert
        expect(result.isError(), true);
        expect(
          result.exceptionOrNull()!.toString(),
          contains('Failed to remove member'),
        );
      });

      test('should return failure when validation fails', () async {
        // Arrange
        const invalidParams = RemoveMemberParams(
          groupId: '',
          userId: 'user456',
        );

        // Act
        final result = await useCase(invalidParams);

        // Assert
        expect(result.isError(), true);
        expect(
          result.exceptionOrNull()!.toString(),
          contains('Group ID is required'),
        );
        verifyNever(mockRepository.removeMember(any, any));
      });
    });
  });
}
