import 'package:fairshare_app/features/groups/domain/entities/group_member_entity.dart';
import 'package:fairshare_app/features/groups/domain/repositories/group_repository.dart';
import 'package:fairshare_app/features/groups/domain/use_cases/add_member_use_case.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'add_member_use_case_test.mocks.dart';

@GenerateMocks([GroupRepository])
void main() {
  late MockGroupRepository mockRepository;
  late AddMemberUseCase useCase;

  setUp(() {
    mockRepository = MockGroupRepository();
    useCase = AddMemberUseCase(mockRepository);
  });

  group('AddMemberUseCase', () {
    final testMember = GroupMemberEntity(
      groupId: 'group123',
      userId: 'user456',
      joinedAt: DateTime(2025, 1, 1),
    );

    group('validate', () {
      test('should throw exception when group ID is empty', () {
        // Arrange
        final invalidMember = GroupMemberEntity(
          groupId: '',
          userId: 'user456',
          joinedAt: DateTime.now(),
        );

        // Act & Assert
        expect(
          () => useCase.validate(invalidMember),
          throwsA(isA<Exception>()),
        );
      });

      test('should throw exception when group ID is only whitespace', () {
        // Arrange
        final invalidMember = GroupMemberEntity(
          groupId: '   ',
          userId: 'user456',
          joinedAt: DateTime.now(),
        );

        // Act & Assert
        expect(
          () => useCase.validate(invalidMember),
          throwsA(isA<Exception>()),
        );
      });

      test('should throw exception when user ID is empty', () {
        // Arrange
        final invalidMember = GroupMemberEntity(
          groupId: 'group123',
          userId: '',
          joinedAt: DateTime.now(),
        );

        // Act & Assert
        expect(
          () => useCase.validate(invalidMember),
          throwsA(isA<Exception>()),
        );
      });

      test('should throw exception when user ID is only whitespace', () {
        // Arrange
        final invalidMember = GroupMemberEntity(
          groupId: 'group123',
          userId: '   ',
          joinedAt: DateTime.now(),
        );

        // Act & Assert
        expect(
          () => useCase.validate(invalidMember),
          throwsA(isA<Exception>()),
        );
      });

      test('should not throw exception when member is valid', () {
        // Act & Assert
        expect(() => useCase.validate(testMember), returnsNormally);
      });
    });

    group('execute', () {
      test('should call repository addMember with valid member', () async {
        // Arrange
        when(mockRepository.addMember(any)).thenAnswer((_) async {});

        // Act
        final result = await useCase(testMember);

        // Assert
        expect(result.isSuccess(), true);
        verify(mockRepository.addMember(testMember)).called(1);
      });

      test('should return failure when repository throws exception', () async {
        // Arrange
        when(mockRepository.addMember(any))
            .thenThrow(Exception('Failed to add member'));

        // Act
        final result = await useCase(testMember);

        // Assert
        expect(result.isError(), true);
        expect(
          result.exceptionOrNull()!.toString(),
          contains('Failed to add member'),
        );
      });

      test('should return failure when validation fails', () async {
        // Arrange
        final invalidMember = GroupMemberEntity(
          groupId: '',
          userId: 'user456',
          joinedAt: DateTime.now(),
        );

        // Act
        final result = await useCase(invalidMember);

        // Assert
        expect(result.isError(), true);
        expect(
          result.exceptionOrNull()!.toString(),
          contains('Group ID is required'),
        );
        verifyNever(mockRepository.addMember(any));
      });
    });
  });
}
