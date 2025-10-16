import 'package:fairshare_app/core/constants/entity_type.dart';
import 'package:fairshare_app/core/database/app_database.dart';
import 'package:fairshare_app/core/events/event_broker.dart';
import 'package:fairshare_app/core/events/group_events.dart';
import 'package:fairshare_app/core/logging/app_logger.dart';
import 'package:fairshare_app/features/groups/domain/entities/group_entity.dart';
import 'package:fairshare_app/features/groups/domain/entities/group_member_entity.dart';
import 'package:fairshare_app/features/groups/domain/repositories/group_repository.dart';

/// Group repository that coordinates local database and upload queue.
///
/// **Clean Architecture Compliance:**
/// - ONLY interacts with local database and queue
/// - NO Firestore calls (handled by sync services)
/// - NO connectivity checks (handled by SyncService)
/// - Uses atomic transactions for data integrity
/// - Fires events after successful operations
/// - User-scoped: ownerId is injected at construction time
class SyncedGroupRepository with LoggerMixin implements GroupRepository {
  final AppDatabase _database;
  final EventBroker _eventBroker;
  final String ownerId; // ID of the user who owns this repository instance

  SyncedGroupRepository(this._database, this._eventBroker, this.ownerId);

  @override
  Future<GroupEntity> createGroup(GroupEntity group) async {
    try {
      // Atomic transaction: DB write + Queue entry (all or nothing)
      await _database.transaction<void>(() async {
        await _database.groupsDao.insertGroup(group);
        await _database.syncDao.enqueueOperation(
          ownerId: ownerId,
          entityType: EntityType.group,
          entityId: group.id,
          operationType: 'create',
        );
      });

      // Fire event after successful operation
      _eventBroker.fire(GroupCreated(group));
      log.d('Created group: ${group.displayName} by owner: $ownerId');
      return group;
    } catch (e) {
      log.e('Failed to create group: $e');
      throw Exception('Failed to create group: $e');
    }
  }

  @override
  Future<GroupEntity> getGroupById(String id) async {
    try {
      final group = await _database.groupsDao.getGroupById(id);
      if (group != null) {
        return group;
      }
      throw Exception('Group not found: $id');
    } catch (e) {
      log.e('Failed to get group $id: $e');
      throw Exception('Failed to get group: $e');
    }
  }

  @override
  Future<List<GroupEntity>> getAllGroups() async {
    try {
      final groups = await _database.groupsDao.getAllGroups();
      return groups;
    } catch (e) {
      log.e('Failed to get all groups: $e');
      throw Exception('Failed to get all groups: $e');
    }
  }

  @override
  Future<GroupEntity> updateGroup(GroupEntity group) async {
    try {
      // Atomic transaction: DB update + Queue entry
      await _database.transaction<void>(() async {
        await _database.groupsDao.updateGroup(group);
        await _database.syncDao.enqueueOperation(
          ownerId: ownerId,
          entityType: EntityType.group,
          entityId: group.id,
          operationType: 'update',
        );
      });

      // Fire event after successful operation
      _eventBroker.fire(GroupUpdated(group));
      log.d('Updated group: ${group.displayName} by owner: $ownerId');
      return group;
    } catch (e) {
      log.e('Failed to update group ${group.id}: $e');
      throw Exception('Failed to update group: $e');
    }
  }

  @override
  Future<void> deleteGroup(String id) async {
    try {
      // Atomic transaction: Soft delete + Queue entry
      await _database.transaction<void>(() async {
        await _database.groupsDao.softDeleteGroup(id);
        await _database.syncDao.enqueueOperation(
          ownerId: ownerId,
          entityType: EntityType.group,
          entityId: id,
          operationType: 'delete',
        );
      });

      // Fire event after successful operation
      _eventBroker.fire(GroupDeleted(id));
      log.d('Deleted group: $id by owner: $ownerId');
    } catch (e) {
      log.e('Failed to delete group $id: $e');
      throw Exception('Failed to delete group: $e');
    }
  }

  @override
  Future<void> addMember(GroupMemberEntity member) async {
    try {
      // Atomic transaction: Add member + Queue entry
      await _database.transaction<void>(() async {
        await _database.groupsDao.addGroupMember(member);
        await _database.syncDao.enqueueOperation(
          ownerId: ownerId,
          entityType: EntityType.groupMember,
          entityId: '${member.groupId}_${member.userId}',
          operationType: 'create',
          metadata: member.groupId,
        );
      });

      // Fire event after successful operation
      _eventBroker.fire(MemberAdded(member));
      log.d('Added member ${member.userId} to group ${member.groupId} by owner: $ownerId');
    } catch (e) {
      log.e('Failed to add member: $e');
      throw Exception('Failed to add member: $e');
    }
  }

  @override
  Future<void> removeMember(String groupId, String userId) async {
    try {
      // Atomic transaction: Remove member + Queue entry
      await _database.transaction<void>(() async {
        await _database.groupsDao.removeGroupMember(groupId, userId);
        await _database.syncDao.enqueueOperation(
          ownerId: ownerId,
          entityType: EntityType.groupMember,
          entityId: '${groupId}_$userId',
          operationType: 'delete',
          metadata: groupId,
        );
      });

      // Fire event after successful operation
      _eventBroker.fire(MemberRemoved(groupId, userId));
      log.d('Removed member $userId from group $groupId by owner: $ownerId');
    } catch (e) {
      log.e('Failed to remove member: $e');
      throw Exception('Failed to remove member: $e');
    }
  }

  @override
  Future<List<GroupEntity>> getUserGroups(String userId) async {
    try {
      final groups = await _database.groupsDao.getUserGroups(userId);
      return groups;
    } catch (e) {
      log.e('Failed to get user groups: $e');
      throw Exception('Failed to get user groups: $e');
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
  Future<List<String>> getGroupMembers(String groupId) async {
    try {
      final members = await _database.groupsDao.getGroupMembers(groupId);
      return members;
    } catch (e) {
      log.e('Failed to get group members: $e');
      throw Exception('Failed to get group members: $e');
    }
  }

  @override
  Future<GroupEntity> joinGroupByCode(String code, String userId) async {
    try {
      // This is a special case - we need to fetch from Firestore first
      // This will be handled by a separate service, not the repository
      // For now, throw an exception
      throw Exception('Join group by code not implemented yet');
    } catch (e) {
      log.e('Failed to join group: $e');
      throw Exception('Failed to join group: $e');
    }
  }
}
