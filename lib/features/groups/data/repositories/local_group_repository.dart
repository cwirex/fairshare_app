import 'package:fairshare_app/core/database/app_database.dart';
import 'package:fairshare_app/features/groups/domain/entities/group_entity.dart';
import 'package:fairshare_app/features/groups/domain/entities/group_member_entity.dart';
import 'package:fairshare_app/features/groups/domain/repositories/group_repository.dart';
import 'package:result_dart/result_dart.dart';

class LocalGroupRepository implements GroupRepository {
  final AppDatabase _database;

  LocalGroupRepository(this._database);

  @override
  Future<Result<GroupEntity>> createGroup(GroupEntity group) async {
    try {
      await _database.transaction(() async {
        await _database.insertGroup(group);

        // Only enqueue non-personal groups for sync
        if (!group.isPersonal) {
          await _database.enqueueOperation(
            entityType: 'group',
            entityId: group.id,
            operationType: 'create',
          );
        }
      });
      return Success(group);
    } catch (e) {
      return Failure(Exception('Failed to create group: $e'));
    }
  }

  @override
  Future<Result<GroupEntity>> getGroupById(String id) async {
    try {
      final group = await _database.getGroupById(id);
      if (group == null) {
        return Failure(Exception('Group not found LOCAL: $id'));
      }
      return Success(group);
    } catch (e) {
      return Failure(Exception('Failed to get group: $e'));
    }
  }

  @override
  Future<Result<List<GroupEntity>>> getAllGroups() async {
    try {
      final groups = await _database.getAllGroups();
      return Success(groups);
    } catch (e) {
      return Failure(Exception('Failed to get all groups: $e'));
    }
  }

  @override
  Future<Result<GroupEntity>> updateGroup(GroupEntity group) async {
    try {
      await _database.transaction(() async {
        await _database.updateGroup(group);

        // Only enqueue non-personal groups for sync
        if (!group.isPersonal) {
          await _database.enqueueOperation(
            entityType: 'group',
            entityId: group.id,
            operationType: 'update',
          );
        }
      });
      return Success(group);
    } catch (e) {
      return Failure(Exception('Failed to update group: $e'));
    }
  }

  @override
  Future<Result<void>> deleteGroup(String id) async {
    try {
      // Get group first to check if personal
      final group = await _database.getGroupById(id);

      await _database.transaction(() async {
        // Only enqueue non-personal groups for sync
        if (group != null && !group.isPersonal) {
          await _database.enqueueOperation(
            entityType: 'group',
            entityId: id,
            operationType: 'delete',
          );
        }
        await _database.deleteGroup(id);
      });
      return Success.unit();
    } catch (e) {
      return Failure(Exception('Failed to delete group: $e'));
    }
  }

  @override
  Future<Result<void>> addMember(GroupMemberEntity member) async {
    try {
      await _database.addGroupMember(member);
      return Success.unit();
    } catch (e) {
      return Failure(Exception('Failed to add member: $e'));
    }
  }

  @override
  Future<Result<void>> removeMember(String groupId, String userId) async {
    try {
      await _database.removeGroupMember(groupId, userId);
      return Success.unit();
    } catch (e) {
      return Failure(Exception('Failed to remove member: $e'));
    }
  }

  @override
  Future<Result<List<String>>> getGroupMembers(String groupId) async {
    try {
      final members = await _database.getGroupMembers(groupId);
      return Success(members);
    } catch (e) {
      return Failure(Exception('Failed to get group members: $e'));
    }
  }

  @override
  Future<Result<List<GroupEntity>>> getUserGroups(String userId) async {
    try {
      final groups = await _database.getUserGroups(userId);
      return Success(groups);
    } catch (e) {
      return Failure(Exception('Failed to get user groups: $e'));
    }
  }

  @override
  Stream<List<GroupEntity>> watchAllGroups() {
    return _database.watchAllGroups();
  }

  @override
  Stream<List<GroupEntity>> watchUserGroups(String userId) {
    return _database.watchUserGroups(userId);
  }

  @override
  Future<Result<GroupEntity>> joinGroupByCode(
      String groupCode, String userId) async {
    // Local repository doesn't support joining remote groups
    return Failure(Exception(
        'Cannot join remote groups in offline mode. Please check your internet connection.'));
  }
}
