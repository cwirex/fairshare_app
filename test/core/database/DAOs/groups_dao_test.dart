import 'package:drift/native.dart';
import 'package:fairshare_app/core/database/app_database.dart';
import 'package:fairshare_app/core/events/event_broker.dart';
import 'package:fairshare_app/features/groups/domain/entities/group_entity.dart';
import 'package:fairshare_app/features/groups/domain/entities/group_member_entity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late EventBroker eventBroker;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    eventBroker = EventBroker();
  });

  tearDown(() async {
    await database.close();
    eventBroker.dispose();
  });

  group('GroupsDao', () {
    test('insertGroup should add group to database', () async {
      // Arrange
      final group = GroupEntity(
        id: 'group1',
        displayName: 'Test Group',
        isPersonal: false,
        defaultCurrency: 'USD',
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 1),
        lastActivityAt: DateTime(2025, 1, 1),
      );

      // Act
      await database.groupsDao.insertGroup(group);

      // Assert
      final retrieved = await database.groupsDao.getGroupById('group1');
      expect(retrieved, isNotNull);
      expect(retrieved!.displayName, 'Test Group');
    });

    test('getGroupById should return null for non-existent group', () async {
      // Act
      final result = await database.groupsDao.getGroupById('nonexistent');

      // Assert
      expect(result, isNull);
    });

    test('getGroupById should exclude soft-deleted groups by default', () async {
      // Arrange
      final group = GroupEntity(
        id: 'group1',
        displayName: 'Deleted Group',
        isPersonal: false,
        defaultCurrency: 'USD',
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 1),
        lastActivityAt: DateTime(2025, 1, 1),
      );
      await database.groupsDao.insertGroup(group);
      await database.groupsDao.softDeleteGroup('group1');

      // Act
      final result = await database.groupsDao.getGroupById('group1');

      // Assert
      expect(result, isNull);
    });

    test('getAllGroups should return all non-deleted groups', () async {
      // Arrange
      final group1 = GroupEntity(
        id: 'group1',
        displayName: 'Group 1',
        isPersonal: false,
        defaultCurrency: 'USD',
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 1),
        lastActivityAt: DateTime(2025, 1, 1),
      );
      final group2 = GroupEntity(
        id: 'group2',
        displayName: 'Group 2',
        isPersonal: false,
        defaultCurrency: 'USD',
        createdAt: DateTime(2025, 1, 2),
        updatedAt: DateTime(2025, 1, 2),
        lastActivityAt: DateTime(2025, 1, 2),
      );
      await database.groupsDao.insertGroup(group1);
      await database.groupsDao.insertGroup(group2);

      // Act
      final groups = await database.groupsDao.getAllGroups();

      // Assert
      expect(groups.length, 2);
    });

    test('updateGroup should update existing group', () async {
      // Arrange
      final group = GroupEntity(
        id: 'group1',
        displayName: 'Original Name',
        isPersonal: false,
        defaultCurrency: 'USD',
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 1),
        lastActivityAt: DateTime(2025, 1, 1),
      );
      await database.groupsDao.insertGroup(group);

      final updated = group.copyWith(displayName: 'Updated Name');

      // Act
      await database.groupsDao.updateGroup(updated);

      // Assert
      final retrieved = await database.groupsDao.getGroupById('group1');
      expect(retrieved!.displayName, 'Updated Name');
    });

    test('deleteGroup should remove group from database', () async {
      // Arrange
      final group = GroupEntity(
        id: 'group1',
        displayName: 'To Delete',
        isPersonal: false,
        defaultCurrency: 'USD',
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 1),
        lastActivityAt: DateTime(2025, 1, 1),
      );
      await database.groupsDao.insertGroup(group);

      // Act
      await database.groupsDao.deleteGroup('group1');

      // Assert
      final retrieved =
          await database.groupsDao.getGroupById('group1', includeDeleted: true);
      expect(retrieved, isNull);
    });

    test('softDeleteGroup should mark group as deleted', () async {
      // Arrange
      final group = GroupEntity(
        id: 'group1',
        displayName: 'To Soft Delete',
        isPersonal: false,
        defaultCurrency: 'USD',
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 1),
        lastActivityAt: DateTime(2025, 1, 1),
      );
      await database.groupsDao.insertGroup(group);

      // Act
      await database.groupsDao.softDeleteGroup('group1');

      // Assert
      final retrieved =
          await database.groupsDao.getGroupById('group1', includeDeleted: true);
      expect(retrieved, isNotNull);
      expect(retrieved!.deletedAt, isNotNull);
    });

    test('addGroupMember should add member to group', () async {
      // Arrange
      final member = GroupMemberEntity(
        groupId: 'group1',
        userId: 'user1',
        joinedAt: DateTime(2025, 1, 1),
      );

      // Act
      await database.groupsDao.addGroupMember(member);

      // Assert
      final members = await database.groupsDao.getAllGroupMembers('group1');
      expect(members.length, 1);
      expect(members[0].userId, 'user1');
    });

    test('removeGroupMember should remove member from group', () async {
      // Arrange
      final member = GroupMemberEntity(
        groupId: 'group1',
        userId: 'user1',
        joinedAt: DateTime(2025, 1, 1),
      );
      await database.groupsDao.addGroupMember(member);

      // Act
      await database.groupsDao.removeGroupMember('group1', 'user1');

      // Assert
      final members = await database.groupsDao.getAllGroupMembers('group1');
      expect(members.length, 0);
    });

    test('getGroupMembers should return member IDs for group', () async {
      // Arrange
      await database.groupsDao.addGroupMember(
        GroupMemberEntity(
          groupId: 'group1',
          userId: 'user1',
          joinedAt: DateTime(2025, 1, 1),
        ),
      );
      await database.groupsDao.addGroupMember(
        GroupMemberEntity(
          groupId: 'group1',
          userId: 'user2',
          joinedAt: DateTime(2025, 1, 1),
        ),
      );

      // Act
      final memberIds = await database.groupsDao.getGroupMembers('group1');

      // Assert
      expect(memberIds.length, 2);
      expect(memberIds.toSet(), {'user1', 'user2'});
    });

    test('upsertGroupFromSync should insert new group', () async {
      // Arrange
      final group = GroupEntity(
        id: 'group1',
        displayName: 'From Sync',
        isPersonal: false,
        defaultCurrency: 'USD',
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 1),
        lastActivityAt: DateTime(2025, 1, 1),
      );

      // Act
      await database.groupsDao.upsertGroupFromSync(group, eventBroker);

      // Assert
      final retrieved = await database.groupsDao.getGroupById('group1');
      expect(retrieved, isNotNull);
      expect(retrieved!.displayName, 'From Sync');
    });
  });
}
