import 'package:fairshare_app/core/database/DAOs/groups_dao.dart';
import 'package:fairshare_app/core/database/DAOs/sync_dao.dart';
import 'package:fairshare_app/core/database/app_database.dart';
import 'package:fairshare_app/core/events/event_broker.dart';
import 'package:fairshare_app/features/groups/data/repositories/synced_group_repository.dart';
import 'package:fairshare_app/features/groups/domain/entities/group_entity.dart';
import 'package:fairshare_app/features/groups/domain/entities/group_member_entity.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'synced_group_repository_test.mocks.dart';

@GenerateMocks([AppDatabase, GroupsDao, SyncDao, EventBroker])
void main() {
  late MockAppDatabase mockDatabase;
  late MockGroupsDao mockGroupsDao;
  late MockSyncDao mockSyncDao;
  late MockEventBroker mockEventBroker;
  late SyncedGroupRepository repository;

  setUp(() {
    mockDatabase = MockAppDatabase();
    mockGroupsDao = MockGroupsDao();
    mockSyncDao = MockSyncDao();
    mockEventBroker = MockEventBroker();
    const testUserId = 'testUserId';

    // Wire up the DAOs to the mock database
    when(mockDatabase.groupsDao).thenReturn(mockGroupsDao);
    when(mockDatabase.syncDao).thenReturn(mockSyncDao);

    repository = SyncedGroupRepository(
      mockDatabase,
      mockEventBroker,
      testUserId,
    );
  });

  group('SyncedGroupRepository', () {
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

    group('createGroup', () {
      test('should insert group and enqueue operation atomically', () async {
        // Arrange
        when(mockDatabase.transaction(any)).thenAnswer((invocation) async {
          final callback = invocation.positionalArguments[0] as Function();
          await callback();
          return null;
        });
        when(mockGroupsDao.insertGroup(any)).thenAnswer((_) async {});
        when(
          mockSyncDao.enqueueOperation(
            ownerId: anyNamed('ownerId'),
            entityType: anyNamed('entityType'),
            entityId: anyNamed('entityId'),
            operationType: anyNamed('operationType'),
            metadata: anyNamed('metadata'),
          ),
        ).thenAnswer((_) async {});

        // Act
        final result = await repository.createGroup(testGroup);

        // Assert
        expect(result, testGroup);
        verify(mockDatabase.transaction<void>(any)).called(1);
        verify(mockGroupsDao.insertGroup(testGroup)).called(1);
        verify(
          mockSyncDao.enqueueOperation(
            ownerId: 'testUserId',
            entityType: 'group',
            entityId: 'group123',
            operationType: 'create',
          ),
        ).called(1);
      });

      test('should throw exception if database operation fails', () async {
        // Arrange
        when(
          mockDatabase.transaction<void>(any),
        ).thenThrow(Exception('DB Error'));

        // Act & Assert
        expect(
          () => repository.createGroup(testGroup),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('getGroupById', () {
      test('should return group if found', () async {
        // Arrange
        when(
          mockGroupsDao.getGroupById('group123'),
        ).thenAnswer((_) async => testGroup);

        // Act
        final result = await repository.getGroupById('group123');

        // Assert
        expect(result, testGroup);
        verify(mockGroupsDao.getGroupById('group123')).called(1);
      });

      test('should throw exception if group not found', () async {
        // Arrange
        when(
          mockGroupsDao.getGroupById('nonexistent'),
        ).thenAnswer((_) async => null);

        // Act & Assert
        expect(
          () => repository.getGroupById('nonexistent'),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('updateGroup', () {
      test('should update group and enqueue operation atomically', () async {
        // Arrange
        when(mockDatabase.transaction(any)).thenAnswer((invocation) async {
          final callback = invocation.positionalArguments[0] as Function();
          await callback();
          return null;
        });
        when(mockGroupsDao.updateGroup(any)).thenAnswer((_) async {});
        when(
          mockSyncDao.enqueueOperation(
            ownerId: anyNamed('ownerId'),
            entityType: anyNamed('entityType'),
            entityId: anyNamed('entityId'),
            operationType: anyNamed('operationType'),
            metadata: anyNamed('metadata'),
          ),
        ).thenAnswer((_) async {});

        // Act
        final result = await repository.updateGroup(testGroup);

        // Assert
        expect(result, testGroup);
        verify(mockDatabase.transaction<void>(any)).called(1);
        verify(mockGroupsDao.updateGroup(testGroup)).called(1);
        verify(
          mockSyncDao.enqueueOperation(
            ownerId: 'testUserId',
            entityType: 'group',
            entityId: 'group123',
            operationType: 'update',
          ),
        ).called(1);
      });
    });

    group('deleteGroup', () {
      test(
        'should soft delete group and enqueue operation atomically',
        () async {
          // Arrange
          when(mockDatabase.transaction(any)).thenAnswer((invocation) async {
            final callback = invocation.positionalArguments[0] as Function();
            await callback();
            return null;
          });
          when(mockGroupsDao.softDeleteGroup(any)).thenAnswer((_) async {});
          when(
            mockSyncDao.enqueueOperation(
              ownerId: anyNamed('ownerId'),
              entityType: anyNamed('entityType'),
              entityId: anyNamed('entityId'),
              operationType: anyNamed('operationType'),
              metadata: anyNamed('metadata'),
            ),
          ).thenAnswer((_) async {});

          // Act
          await repository.deleteGroup('group123');

          // Assert
          verify(mockDatabase.transaction<void>(any)).called(1);
          verify(mockGroupsDao.softDeleteGroup('group123')).called(1);
          verify(
            mockSyncDao.enqueueOperation(
              ownerId: 'testUserId',
              entityType: 'group',
              entityId: 'group123',
              operationType: 'delete',
            ),
          ).called(1);
        },
      );
    });

    group('addMember', () {
      final testMember = GroupMemberEntity(
        groupId: 'group123',
        userId: 'user456',
        joinedAt: DateTime(2025, 1, 1),
      );

      test('should add member and enqueue operation atomically', () async {
        // Arrange
        when(mockDatabase.transaction(any)).thenAnswer((invocation) async {
          final callback = invocation.positionalArguments[0] as Function();
          await callback();
          return null;
        });
        when(mockGroupsDao.addGroupMember(any)).thenAnswer((_) async {});
        when(
          mockSyncDao.enqueueOperation(
            ownerId: anyNamed('ownerId'),
            entityType: anyNamed('entityType'),
            entityId: anyNamed('entityId'),
            operationType: anyNamed('operationType'),
            metadata: anyNamed('metadata'),
          ),
        ).thenAnswer((_) async {});

        // Act
        await repository.addMember(testMember);

        // Assert
        verify(mockDatabase.transaction<void>(any)).called(1);
        verify(mockGroupsDao.addGroupMember(testMember)).called(1);
        verify(
          mockSyncDao.enqueueOperation(
            ownerId: 'testUserId',
            entityType: 'group_member',
            entityId: 'group123_user456',
            operationType: 'create',
            metadata: 'group123',
          ),
        ).called(1);
      });
    });

    group('removeMember', () {
      test('should remove member and enqueue operation atomically', () async {
        // Arrange
        when(mockDatabase.transaction(any)).thenAnswer((invocation) async {
          final callback = invocation.positionalArguments[0] as Function();
          await callback();
          return null;
        });
        when(
          mockGroupsDao.removeGroupMember(any, any),
        ).thenAnswer((_) async {});
        when(
          mockSyncDao.enqueueOperation(
            ownerId: anyNamed('ownerId'),
            entityType: anyNamed('entityType'),
            entityId: anyNamed('entityId'),
            operationType: anyNamed('operationType'),
            metadata: anyNamed('metadata'),
          ),
        ).thenAnswer((_) async {});

        // Act
        await repository.removeMember('group123', 'user456');

        // Assert
        verify(mockDatabase.transaction<void>(any)).called(1);
        verify(
          mockGroupsDao.removeGroupMember('group123', 'user456'),
        ).called(1);
        verify(
          mockSyncDao.enqueueOperation(
            ownerId: 'testUserId',
            entityType: 'group_member',
            entityId: 'group123_user456',
            operationType: 'delete',
            metadata: 'group123',
          ),
        ).called(1);
      });
    });

    group('atomic transaction guarantee', () {
      test('should rollback if queue enqueue fails', () async {
        // Arrange
        when(mockDatabase.transaction(any)).thenAnswer((invocation) async {
          final callback = invocation.positionalArguments[0] as Function();
          await callback();
          return null;
        });
        when(mockGroupsDao.insertGroup(any)).thenAnswer((_) async {});
        when(
          mockSyncDao.enqueueOperation(
            ownerId: anyNamed('ownerId'),
            entityType: anyNamed('entityType'),
            entityId: anyNamed('entityId'),
            operationType: anyNamed('operationType'),
            metadata: anyNamed('metadata'),
          ),
        ).thenThrow(Exception('Queue error'));

        // Act & Assert
        expect(
          () => repository.createGroup(testGroup),
          throwsA(predicate((e) => e.toString().contains('Queue error'))),
        );
      });
    });
  });
}
