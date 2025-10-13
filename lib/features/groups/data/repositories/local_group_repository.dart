import 'package:fairshare_app/core/constants/entity_type.dart';
import 'package:fairshare_app/core/database/app_database.dart';
import 'package:fairshare_app/core/logging/app_logger.dart';
import 'package:fairshare_app/features/groups/domain/entities/group_entity.dart';
import 'package:fairshare_app/features/groups/domain/entities/group_member_entity.dart';
import 'package:fairshare_app/features/groups/domain/repositories/group_repository.dart';

class LocalGroupRepository with LoggerMixin implements GroupRepository {
  final AppDatabase _database;

  LocalGroupRepository(this._database);

  @override
  Future<GroupEntity> createGroup(GroupEntity group) async {
    // Atomic transaction: DB write + Queue entry (all or nothing)
    await _database.transaction(() async {
      await _database.groupsDao.insertGroup(group);

      // Only enqueue non-personal groups for sync
      if (!group.isPersonal) {
        await _database.syncDao.enqueueOperation(
          entityType: EntityType.group,
          entityId: group.id,
          operationType: 'create',
        );
      }
    });

    // Return the created group
    return group;
  }

  @override
  Future<GroupEntity> getGroupById(String id) async {
    final group = await _database.groupsDao.getGroupById(id);
    if (group == null) {
      throw Exception('Group not found LOCAL: $id');
    }
    return group;
  }

  @override
  Future<List<GroupEntity>> getAllGroups() async {
    return await _database.groupsDao.getAllGroups();
  }

  @override
  Future<GroupEntity> updateGroup(GroupEntity group) async {
    await _database.transaction(() async {
      await _database.groupsDao.updateGroup(group);

      // Only enqueue non-personal groups for sync
      if (!group.isPersonal) {
        await _database.syncDao.enqueueOperation(
          entityType: EntityType.group,
          entityId: group.id,
          operationType: 'update',
        );
      }
    });

    return group;
  }

  @override
  Future<void> deleteGroup(String id) async {
    // Get group first to check if personal
    final group = await _database.groupsDao.getGroupById(id);

    await _database.transaction(() async {
      // Only enqueue non-personal groups for sync
      if (group != null && !group.isPersonal) {
        await _database.syncDao.enqueueOperation(
          entityType: EntityType.group,
          entityId: id,
          operationType: 'delete',
        );
      }
      await _database.groupsDao.deleteGroup(id);
    });

    return Future.value();
  }

  @override
  Future<void> addMember(GroupMemberEntity member) async {
    await _database.groupsDao.addGroupMember(member);
    return Future.value();
  }

  @override
  Future<void> removeMember(String groupId, String userId) async {
    await _database.groupsDao.removeGroupMember(groupId, userId);
    return Future.value();
  }

  @override
  Future<List<String>> getGroupMembers(String groupId) async {
    return await _database.groupsDao.getGroupMembers(groupId);
  }

  @override
  Future<List<GroupEntity>> getUserGroups(String userId) async {
    return await _database.groupsDao.getUserGroups(userId);
  }

  @override
  Stream<List<GroupEntity>> watchAllGroups() {
    return _database.groupsDao.watchAllGroups();
  }

  @override
  Stream<List<GroupEntity>> watchUserGroups(String userId) {
    return _database.groupsDao.watchUserGroups(userId);
  }

  @override
  Future<GroupEntity> joinGroupByCode(String groupCode, String userId) {
    log.e('Attempted to join group by code in LocalGroupRepository');
    log.d('Group code: $groupCode, User ID: $userId');
    // Local repository doesn't support joining remote groups
    throw Exception(
      'Cannot join remote groups in offline mode. Please check your internet connection.',
    );
  }
}
