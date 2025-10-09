import 'package:fairshare_app/core/database/app_database.dart';
import 'package:fairshare_app/core/logging/app_logger.dart';
import 'package:fairshare_app/features/groups/domain/entities/group_entity.dart';
import 'package:fairshare_app/features/groups/domain/entities/group_member_entity.dart';
import 'package:fairshare_app/features/groups/domain/repositories/group_repository.dart';
import 'package:result_dart/result_dart.dart';

/// Group repository that coordinates local database and upload queue.
///
/// **Clean Architecture Compliance:**
/// - ONLY interacts with local database and queue
/// - NO Firestore calls (handled by sync services)
/// - NO connectivity checks (handled by SyncService)
/// - Uses atomic transactions for data integrity
class SyncedGroupRepository with LoggerMixin implements GroupRepository {
  final AppDatabase _database;

  SyncedGroupRepository(this._database);

  @override
  Future<Result<GroupEntity>> createGroup(GroupEntity group) async {
    try {
      // Atomic transaction: DB write + Queue entry (all or nothing)
      await _database.transaction<void>(() async {
        await _database.groupsDao.insertGroup(group);
        await _database.syncDao.enqueueOperation(
          entityType: 'group',
          entityId: group.id,
          operationType: 'create',
        );
      });

      log.d('Created group: ${group.displayName}');
      return Success(group);
    } catch (e) {
      log.e('Failed to create group: $e');
      return Failure(Exception('Failed to create group: $e'));
    }
  }

  @override
  Future<Result<GroupEntity>> getGroupById(String id) async {
    try {
      final group = await _database.groupsDao.getGroupById(id);
      if (group != null) {
        return Success(group);
      }
      return Failure(Exception('Group not found: $id'));
    } catch (e) {
      log.e('Failed to get group $id: $e');
      return Failure(Exception('Failed to get group: $e'));
    }
  }

  @override
  Future<Result<List<GroupEntity>>> getAllGroups() async {
    try {
      final groups = await _database.groupsDao.getAllGroups();
      return Success(groups);
    } catch (e) {
      log.e('Failed to get all groups: $e');
      return Failure(Exception('Failed to get all groups: $e'));
    }
  }

  @override
  Future<Result<GroupEntity>> updateGroup(GroupEntity group) async {
    try {
      // Atomic transaction: DB update + Queue entry
      await _database.transaction<void>(() async {
        await _database.groupsDao.updateGroup(group);
        await _database.syncDao.enqueueOperation(
          entityType: 'group',
          entityId: group.id,
          operationType: 'update',
        );
      });

      log.d('Updated group: ${group.displayName}');
      return Success(group);
    } catch (e) {
      log.e('Failed to update group ${group.id}: $e');
      return Failure(Exception('Failed to update group: $e'));
    }
  }

  @override
  Future<Result<void>> deleteGroup(String id) async {
    try {
      // Atomic transaction: Soft delete + Queue entry
      await _database.transaction<void>(() async {
        await _database.groupsDao.softDeleteGroup(id);
        await _database.syncDao.enqueueOperation(
          entityType: 'group',
          entityId: id,
          operationType: 'delete',
        );
      });

      log.d('Deleted group: $id');
      return Success.unit();
    } catch (e) {
      log.e('Failed to delete group $id: $e');
      return Failure(Exception('Failed to delete group: $e'));
    }
  }

  @override
  Future<Result<void>> addMember(GroupMemberEntity member) async {
    try {
      // Atomic transaction: Add member + Queue entry
      await _database.transaction<void>(() async {
        await _database.groupsDao.addGroupMember(member);
        await _database.syncDao.enqueueOperation(
          entityType: 'group_member',
          entityId: '${member.groupId}_${member.userId}',
          operationType: 'create',
          metadata: member.groupId,
        );
      });

      log.d('Added member ${member.userId} to group ${member.groupId}');
      return Success.unit();
    } catch (e) {
      log.e('Failed to add member: $e');
      return Failure(Exception('Failed to add member: $e'));
    }
  }

  @override
  Future<Result<void>> removeMember(String groupId, String userId) async {
    try {
      // Atomic transaction: Remove member + Queue entry
      await _database.transaction<void>(() async {
        await _database.groupsDao.removeGroupMember(groupId, userId);
        await _database.syncDao.enqueueOperation(
          entityType: 'group_member',
          entityId: '${groupId}_$userId',
          operationType: 'delete',
          metadata: groupId,
        );
      });

      log.d('Removed member $userId from group $groupId');
      return Success.unit();
    } catch (e) {
      log.e('Failed to remove member: $e');
      return Failure(Exception('Failed to remove member: $e'));
    }
  }

  @override
  Future<Result<List<GroupEntity>>> getUserGroups(String userId) async {
    try {
      final groups = await _database.groupsDao.getUserGroups(userId);
      return Success(groups);
    } catch (e) {
      log.e('Failed to get user groups: $e');
      return Failure(Exception('Failed to get user groups: $e'));
    }
  }

  @override
  Stream<List<GroupEntity>> watchUserGroups(String userId) {
    return _database.groupsDao.watchUserGroups(userId);
  }

  @override
  Stream<List<GroupEntity>> watchAllGroups() {
    return _database.groupsDao.watchAllGroups();
  }

  @override
  Future<Result<List<String>>> getGroupMembers(String groupId) async {
    try {
      final members = await _database.groupsDao.getGroupMembers(groupId);
      return Success(members);
    } catch (e) {
      log.e('Failed to get group members: $e');
      return Failure(Exception('Failed to get group members: $e'));
    }
  }

  @override
  Future<Result<GroupEntity>> joinGroupByCode(
    String code,
    String userId,
  ) async {
    try {
      // This is a special case - we need to fetch from Firestore first
      // This will be handled by a separate service, not the repository
      // For now, return a failure
      return Failure(Exception('Join group by code not implemented yet'));
    } catch (e) {
      log.e('Failed to join group: $e');
      return Failure(Exception('Failed to join group: $e'));
    }
  }
}
