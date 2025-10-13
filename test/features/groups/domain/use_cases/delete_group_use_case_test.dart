import 'package:fairshare_app/features/groups/domain/repositories/group_repository.dart';
import 'package:fairshare_app/features/groups/domain/use_cases/delete_group_use_case.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'delete_group_use_case_test.mocks.dart';

@GenerateMocks([GroupRepository])
void main() {
  late MockGroupRepository mockRepository;
  late DeleteGroupUseCase useCase;

  setUp(() {
    mockRepository = MockGroupRepository();
    useCase = DeleteGroupUseCase(mockRepository);
  });

  group('DeleteGroupUseCase', () {
    const groupId = 'group123';

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
      test('should call repository deleteGroup with valid ID', () async {
        // Arrange
        when(mockRepository.deleteGroup(any)).thenAnswer((_) async {});

        // Act
        final result = await useCase(groupId);

        // Assert
        expect(result.isSuccess(), true);
        verify(mockRepository.deleteGroup(groupId)).called(1);
      });

      test('should return failure when repository throws exception', () async {
        // Arrange
        when(mockRepository.deleteGroup(any))
            .thenThrow(Exception('Group not found'));

        // Act
        final result = await useCase(groupId);

        // Assert
        expect(result.isError(), true);
        expect(
          result.exceptionOrNull()!.toString(),
          contains('Group not found'),
        );
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
        verifyNever(mockRepository.deleteGroup(any));
      });
    });
  });
}
