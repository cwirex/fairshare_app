import 'dart:async';

import 'package:drift/native.dart';
import 'package:fairshare_app/core/database/app_database.dart';
import 'package:fairshare_app/core/events/event_broker.dart';
import 'package:fairshare_app/core/events/group_events.dart';
import 'package:fairshare_app/features/groups/data/repositories/synced_group_repository.dart';
import 'package:fairshare_app/features/groups/domain/entities/group_entity.dart';
import 'package:fairshare_app/features/groups/domain/entities/group_member_entity.dart';
import 'package:fairshare_app/features/groups/domain/use_cases/add_member_use_case.dart';
import 'package:fairshare_app/features/groups/domain/use_cases/create_group_use_case.dart';
import 'package:fairshare_app/features/groups/domain/use_cases/delete_group_use_case.dart';
import 'package:fairshare_app/features/groups/domain/use_cases/remove_member_use_case.dart';
import 'package:fairshare_app/features/groups/domain/use_cases/update_group_use_case.dart';
import 'package:flutter_test/flutter_test.dart';

/// Integration test for complete group flow:
/// Use Case → Repository → Database → Events
void main() {
  late AppDatabase database;
  late EventBroker eventBroker;
  late SyncedGroupRepository repository;
  late CreateGroupUseCase createUseCase;
  late UpdateGroupUseCase updateUseCase;
  late DeleteGroupUseCase deleteUseCase;
  late AddMemberUseCase addMemberUseCase;
  late RemoveMemberUseCase removeMemberUseCase;
  StreamSubscription<GroupCreated>? groupCreatedSub;
  StreamSubscription<GroupUpdated>? groupUpdatedSub;
  StreamSubscription<GroupDeleted>? groupDeletedSub;
  StreamSubscription<MemberAdded>? memberAddedSub;
  StreamSubscription<MemberRemoved>? memberRemovedSub;

  const testUserId = 'test-user-123';

  setUp(() async {
    // Create EventBroker first
    eventBroker = EventBroker();

    // Create in-memory database for testing
    database = AppDatabase.forTesting(NativeDatabase.memory());

    // Create repository
    repository = SyncedGroupRepository(
      database: database,
      groupsDao: database.groupsDao,
      syncDao: database.syncDao,
      eventBroker: eventBroker,
      ownerId: testUserId,
    );

    // Create use cases
    createUseCase = CreateGroupUseCase(repository);
    updateUseCase = UpdateGroupUseCase(repository);
    deleteUseCase = DeleteGroupUseCase(repository);
    addMemberUseCase = AddMemberUseCase(repository);
    removeMemberUseCase = RemoveMemberUseCase(repository);
  });

  tearDown(() async {
    await groupCreatedSub?.cancel();
    await groupUpdatedSub?.cancel();
    await groupDeletedSub?.cancel();
    await memberAddedSub?.cancel();
    await memberRemovedSub?.cancel();
    await database.close();
    // Don't dispose EventBroker - it's a singleton shared across tests
  });

  group('Group Flow Integration', () {
    test(
      'should create group, store in DB, enqueue sync, and fire event',
      () async {
        // Arrange
        final group = GroupEntity(
          id: 'test-group-1',
          displayName: 'Test Group',
          avatarUrl: '',
          isPersonal: false,
          defaultCurrency: 'USD',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          lastActivityAt: DateTime.now(),
          deletedAt: null,
        );

        final eventFired = Completer<GroupCreated>();
        groupCreatedSub = eventBroker.on<GroupCreated>().listen((event) {
          if (!eventFired.isCompleted) {
            eventFired.complete(event);
          }
        });
        groupUpdatedSub = eventBroker.on<GroupUpdated>().listen((_) {});
        groupDeletedSub = eventBroker.on<GroupDeleted>().listen((_) {});
        memberAddedSub = eventBroker.on<MemberAdded>().listen((_) {});
        memberRemovedSub = eventBroker.on<MemberRemoved>().listen((_) {});

        // Act
        final result = await createUseCase(group);

        // Assert
        expect(result.isSuccess(), true);
        expect(result.getOrNull()!.id, group.id);

        // Verify stored in database
        final storedGroup = await database.groupsDao.getGroupById(group.id);
        expect(storedGroup, isNotNull);
        expect(storedGroup!.displayName, group.displayName);

        // Verify sync operation was enqueued
        final syncOps = await database.syncDao.getPendingOperations(ownerId: testUserId);
        expect(syncOps.length, greaterThan(0));
        expect(
          syncOps.any((op) =>
            op.entityId == group.id && op.operationType == 'create'),
          true,
        );

        // Verify event was fired
        final event = await eventFired.future
            .timeout(const Duration(seconds: 1));
        expect(event.group.id, group.id);
        expect(event.group.displayName, group.displayName);
      },
    );

    test(
      'should update group, persist to DB, enqueue sync, and fire event',
      () async {
        // Arrange - Create group first
        final group = GroupEntity(
          id: 'test-group-2',
          displayName: 'Original Name',
          avatarUrl: '',
          isPersonal: false,
          defaultCurrency: 'USD',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          lastActivityAt: DateTime.now(),
          deletedAt: null,
        );

        groupCreatedSub = eventBroker.on<GroupCreated>().listen((_) {});
        groupDeletedSub = eventBroker.on<GroupDeleted>().listen((_) {});
        memberAddedSub = eventBroker.on<MemberAdded>().listen((_) {});
        memberRemovedSub = eventBroker.on<MemberRemoved>().listen((_) {});

        final eventFired = Completer<GroupUpdated>();
        groupUpdatedSub = eventBroker.on<GroupUpdated>().listen((event) {
          if (!eventFired.isCompleted) {
            eventFired.complete(event);
          }
        });

        await createUseCase(group);

        // Act - Update the group
        final updatedGroup = group.copyWith(displayName: 'Updated Name');
        final result = await updateUseCase(updatedGroup);

        // Assert
        expect(result.isSuccess(), true);

        // Verify updated in database
        final storedGroup = await database.groupsDao.getGroupById(group.id);
        expect(storedGroup!.displayName, 'Updated Name');

        // Verify sync operation was enqueued
        final syncOps = await database.syncDao.getPendingOperations(ownerId: testUserId);
        expect(
          syncOps.any((op) =>
            op.entityId == group.id && op.operationType == 'update'),
          true,
        );

        // Verify event was fired
        final event = await eventFired.future
            .timeout(const Duration(seconds: 1));
        expect(event.group.id, group.id);
        expect(event.group.displayName, 'Updated Name');
      },
    );

    test(
      'should delete group (soft delete), enqueue sync, and fire event',
      () async {
        // Arrange - Create group first
        final group = GroupEntity(
          id: 'test-group-3',
          displayName: 'To Be Deleted',
          avatarUrl: '',
          isPersonal: false,
          defaultCurrency: 'USD',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          lastActivityAt: DateTime.now(),
          deletedAt: null,
        );

        groupCreatedSub = eventBroker.on<GroupCreated>().listen((_) {});
        groupUpdatedSub = eventBroker.on<GroupUpdated>().listen((_) {});
        memberAddedSub = eventBroker.on<MemberAdded>().listen((_) {});
        memberRemovedSub = eventBroker.on<MemberRemoved>().listen((_) {});

        final eventFired = Completer<GroupDeleted>();
        groupDeletedSub = eventBroker.on<GroupDeleted>().listen((event) {
          if (!eventFired.isCompleted) {
            eventFired.complete(event);
          }
        });

        await createUseCase(group);

        // Act
        final result = await deleteUseCase(group.id);

        // Assert
        expect(result.isSuccess(), true);

        // Verify soft deleted in database (deletedAt is set)
        final storedGroup = await database.groupsDao.getGroupById(
          group.id,
          includeDeleted: true,
        );
        expect(storedGroup, isNotNull);
        expect(storedGroup!.deletedAt, isNotNull);

        // Verify not returned in normal queries
        final normalQuery = await database.groupsDao.getGroupById(group.id);
        expect(normalQuery, isNull);

        // Verify sync operation was enqueued
        final syncOps = await database.syncDao.getPendingOperations(ownerId: testUserId);
        expect(
          syncOps.any((op) =>
            op.entityId == group.id && op.operationType == 'delete'),
          true,
        );

        // Verify event was fired
        final event = await eventFired.future
            .timeout(const Duration(seconds: 1));
        expect(event.groupId, group.id);
      },
    );

    test(
      'should add member to group, store in DB, enqueue sync, and fire event',
      () async {
        // Arrange - Create group first
        final group = GroupEntity(
          id: 'test-group-4',
          displayName: 'Member Test Group',
          avatarUrl: '',
          isPersonal: false,
          defaultCurrency: 'USD',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          lastActivityAt: DateTime.now(),
          deletedAt: null,
        );

        groupCreatedSub = eventBroker.on<GroupCreated>().listen((_) {});
        groupUpdatedSub = eventBroker.on<GroupUpdated>().listen((_) {});
        groupDeletedSub = eventBroker.on<GroupDeleted>().listen((_) {});
        memberRemovedSub = eventBroker.on<MemberRemoved>().listen((_) {});

        final eventFired = Completer<MemberAdded>();
        memberAddedSub = eventBroker.on<MemberAdded>().listen((event) {
          if (!eventFired.isCompleted) {
            eventFired.complete(event);
          }
        });

        await createUseCase(group);

        final member = GroupMemberEntity(
          groupId: group.id,
          userId: 'user123',
          joinedAt: DateTime.now(),
        );

        // Act
        final result = await addMemberUseCase(member);

        // Assert
        expect(result.isSuccess(), true);

        // Verify stored in database
        final members = await database.groupsDao.getGroupMembers(group.id);
        expect(members, contains('user123'));

        // Verify sync operation was enqueued
        final syncOps = await database.syncDao.getPendingOperations(ownerId: testUserId);
        expect(
          syncOps.any((op) =>
            op.entityId == '${group.id}_user123' &&
            op.operationType == 'create'),
          true,
        );

        // Verify event was fired
        final event = await eventFired.future
            .timeout(const Duration(seconds: 1));
        expect(event.member.groupId, group.id);
        expect(event.member.userId, 'user123');
      },
    );

    test(
      'should remove member from group, update DB, enqueue sync, and fire event',
      () async {
        // Arrange - Create group and add member first
        final group = GroupEntity(
          id: 'test-group-5',
          displayName: 'Remove Member Group',
          avatarUrl: '',
          isPersonal: false,
          defaultCurrency: 'USD',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          lastActivityAt: DateTime.now(),
          deletedAt: null,
        );

        groupCreatedSub = eventBroker.on<GroupCreated>().listen((_) {});
        groupUpdatedSub = eventBroker.on<GroupUpdated>().listen((_) {});
        groupDeletedSub = eventBroker.on<GroupDeleted>().listen((_) {});
        memberAddedSub = eventBroker.on<MemberAdded>().listen((_) {});

        final eventFired = Completer<MemberRemoved>();
        memberRemovedSub = eventBroker.on<MemberRemoved>().listen((event) {
          if (!eventFired.isCompleted) {
            eventFired.complete(event);
          }
        });

        await createUseCase(group);

        final member = GroupMemberEntity(
          groupId: group.id,
          userId: 'user456',
          joinedAt: DateTime.now(),
        );
        await addMemberUseCase(member);

        // Act
        final params = RemoveMemberParams(
          groupId: group.id,
          userId: 'user456',
        );
        final result = await removeMemberUseCase(params);

        // Assert
        expect(result.isSuccess(), true);

        // Verify removed from database
        final members = await database.groupsDao.getGroupMembers(group.id);
        expect(members, isNot(contains('user456')));

        // Verify sync operation was enqueued
        final syncOps = await database.syncDao.getPendingOperations(ownerId: testUserId);
        expect(
          syncOps.any((op) =>
            op.entityId == '${group.id}_user456' &&
            op.operationType == 'delete'),
          true,
        );

        // Verify event was fired
        final event = await eventFired.future
            .timeout(const Duration(seconds: 1));
        expect(event.groupId, group.id);
        expect(event.userId, 'user456');
      },
    );

    test('should handle validation errors in use case', () async {
      // Arrange
      final invalidGroup = GroupEntity(
        id: 'test-group-6',
        displayName: 'A', // Invalid: too short
        avatarUrl: '',
        isPersonal: false,
        defaultCurrency: 'USD',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        lastActivityAt: DateTime.now(),
        deletedAt: null,
      );

      groupCreatedSub = eventBroker.on<GroupCreated>().listen((_) {});
      groupUpdatedSub = eventBroker.on<GroupUpdated>().listen((_) {});
      groupDeletedSub = eventBroker.on<GroupDeleted>().listen((_) {});
      memberAddedSub = eventBroker.on<MemberAdded>().listen((_) {});
      memberRemovedSub = eventBroker.on<MemberRemoved>().listen((_) {});

      // Act
      final result = await createUseCase(invalidGroup);

      // Assert
      expect(result.isError(), true);
      expect(
        result.exceptionOrNull()!.toString(),
        contains('at least 2 characters'),
      );

      // Verify NOT stored in database
      final storedGroup = await database.groupsDao.getGroupById(
        invalidGroup.id,
      );
      expect(storedGroup, isNull);

      // Verify NO sync operation was enqueued
      final syncOps = await database.syncDao.getPendingOperations(ownerId: testUserId);
      expect(
        syncOps.any((op) => op.entityId == invalidGroup.id),
        false,
      );
    });

    test(
      'should handle complete group lifecycle with members',
      () async {
        // Arrange
        final group = GroupEntity(
          id: 'test-group-lifecycle',
          displayName: 'Lifecycle Group',
          avatarUrl: '',
          isPersonal: false,
          defaultCurrency: 'USD',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          lastActivityAt: DateTime.now(),
          deletedAt: null,
        );

        groupCreatedSub = eventBroker.on<GroupCreated>().listen((_) {});
        groupUpdatedSub = eventBroker.on<GroupUpdated>().listen((_) {});
        groupDeletedSub = eventBroker.on<GroupDeleted>().listen((_) {});
        memberAddedSub = eventBroker.on<MemberAdded>().listen((_) {});
        memberRemovedSub = eventBroker.on<MemberRemoved>().listen((_) {});

        // Act - Create group
        final createResult = await createUseCase(group);
        expect(createResult.isSuccess(), true);

        // Add multiple members
        final members = ['user1', 'user2', 'user3'];
        for (final userId in members) {
          final member = GroupMemberEntity(
            groupId: group.id,
            userId: userId,
            joinedAt: DateTime.now(),
          );
          final result = await addMemberUseCase(member);
          expect(result.isSuccess(), true);
        }

        // Update group
        final updatedGroup = group.copyWith(displayName: 'Updated Lifecycle');
        final updateResult = await updateUseCase(updatedGroup);
        expect(updateResult.isSuccess(), true);

        // Remove one member
        final removeParams = RemoveMemberParams(
          groupId: group.id,
          userId: 'user2',
        );
        final removeResult = await removeMemberUseCase(removeParams);
        expect(removeResult.isSuccess(), true);

        // Assert final state
        final storedGroup = await database.groupsDao.getGroupById(group.id);
        expect(storedGroup!.displayName, 'Updated Lifecycle');

        final remainingMembers = await database.groupsDao.getGroupMembers(
          group.id,
        );
        expect(remainingMembers, ['user1', 'user3']);
        expect(remainingMembers, isNot(contains('user2')));
      },
    );
  });
}
