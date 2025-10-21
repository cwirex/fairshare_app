import 'package:fairshare_app/features/groups/domain/entities/group_entity.dart';
import 'package:fairshare_app/features/groups/domain/entities/group_member_entity.dart';
import 'package:fairshare_app/features/groups/domain/repositories/group_repository.dart';
import 'package:fairshare_app/features/groups/domain/services/remote_group_service.dart';
import 'package:fairshare_app/features/groups/domain/use_cases/join_group_by_code_use_case.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:result_dart/result_dart.dart';

import 'join_group_by_code_use_case_test.mocks.dart';

@GenerateMocks([GroupRepository, RemoteGroupService])
void main() {
  late MockGroupRepository mockRepository;
  late MockRemoteGroupService mockRemoteService;
  late JoinGroupByCodeUseCase useCase;

  final dummyGroup = GroupEntity(
    id: 'dummy',
    displayName: 'Dummy',
    createdAt: DateTime(2025),
    updatedAt: DateTime(2025),
    lastActivityAt: DateTime(2025),
  );

  setUp(() {
    mockRepository = MockGroupRepository();
    mockRemoteService = MockRemoteGroupService();

    // Provide dummy values for Result types
    provideDummy<Result<GroupEntity>>(Success(dummyGroup));
    provideDummy<Result<void>>(Success.unit());
    provideDummy<Result<List<GroupMemberEntity>>>(Success([]));

    useCase = JoinGroupByCodeUseCase(mockRepository, mockRemoteService);
  });

  group('JoinGroupByCodeUseCase', () {
    const testParams = JoinGroupByCodeParams(
      groupCode: '123456',
      userId: 'user456',
    );

    final testGroup = GroupEntity(
      id: '123456',
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

      test('should throw exception when group code is not 6 digits', () {
        // Arrange
        const invalidParams = JoinGroupByCodeParams(
          groupCode: '12345', // Only 5 digits
          userId: 'user456',
        );

        // Act & Assert
        expect(
          () => useCase.validate(invalidParams),
          throwsA(isA<Exception>()),
        );
      });

      test('should throw exception when group code contains non-digits', () {
        // Arrange
        const invalidParams = JoinGroupByCodeParams(
          groupCode: 'ABC123', // Contains letters
          userId: 'user456',
        );

        // Act & Assert
        expect(
          () => useCase.validate(invalidParams),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('execute', () {
      test('should successfully join group when all operations succeed', () async {
        // Arrange
        when(mockRepository.getUserGroups('user456'))
            .thenAnswer((_) async => []); // User has no groups
        when(mockRemoteService.downloadGroup('123456'))
            .thenAnswer((_) async => Success(testGroup));
        when(mockRemoteService.uploadGroupMember(any))
            .thenAnswer((_) async => Success.unit());
        when(mockRepository.createGroup(any))
            .thenAnswer((_) async => testGroup);
        when(mockRepository.addMember(any)).thenAnswer((_) async {});

        // Act
        final result = await useCase(testParams);

        // Assert
        expect(result.isSuccess(), true);
        expect(result.getOrNull(), testGroup);
        verify(mockRepository.getUserGroups('user456')).called(1);
        verify(mockRemoteService.downloadGroup('123456')).called(1);
        verify(mockRemoteService.uploadGroupMember(any)).called(1);
        verify(mockRepository.createGroup(testGroup)).called(1);
        verify(mockRepository.addMember(any)).called(1);
      });

      test('should return existing group if already joined locally', () async {
        // Arrange
        when(mockRepository.getUserGroups('user456'))
            .thenAnswer((_) async => [testGroup]); // User already has this group

        // Act
        final result = await useCase(testParams);

        // Assert
        expect(result.isSuccess(), true);
        expect(result.getOrNull(), testGroup);
        verify(mockRepository.getUserGroups('user456')).called(1);
        verifyNever(mockRemoteService.downloadGroup(any));
        verifyNever(mockRepository.createGroup(any));
      });

      test('should return failure when remote group not found', () async {
        // Arrange
        when(mockRepository.getUserGroups('user456'))
            .thenAnswer((_) async => []); // User has no groups
        when(mockRemoteService.downloadGroup('123456'))
            .thenAnswer((_) async => Failure(Exception('Group not found')));

        // Act
        final result = await useCase(testParams);

        // Assert
        expect(result.isError(), true);
        expect(
          result.exceptionOrNull()!.toString(),
          contains('Group not found'),
        );
        verifyNever(mockRepository.createGroup(any));
      });

      test('should return failure when upload member fails', () async {
        // Arrange
        when(mockRepository.getUserGroups('user456'))
            .thenAnswer((_) async => []); // User has no groups
        when(mockRemoteService.downloadGroup('123456'))
            .thenAnswer((_) async => Success(testGroup));
        when(mockRemoteService.uploadGroupMember(any))
            .thenAnswer((_) async => Failure(Exception('Upload failed')));

        // Act
        final result = await useCase(testParams);

        // Assert
        expect(result.isError(), true);
        expect(
          result.exceptionOrNull()!.toString(),
          contains('Upload failed'),
        );
        verifyNever(mockRepository.createGroup(any));
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
        // No need to verify - validation happens before any method calls
      });
    });
  });
}
