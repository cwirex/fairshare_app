import 'package:fairshare_app/core/constants/entity_type.dart';
import 'package:fairshare_app/core/database/app_database.dart';
import 'package:fairshare_app/core/database/interfaces/dao_interfaces.dart';
import 'package:fairshare_app/core/events/event_broker_interface.dart';
import 'package:fairshare_app/core/events/group_events.dart';
import 'package:fairshare_app/core/events/sync_events.dart';
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
  final IGroupsDao _groupsDao;
  final ISyncDao _syncDao;
  final IEventBroker _eventBroker;
  final String ownerId; // ID of the user who owns this repository instance

  SyncedGroupRepository({
    required AppDatabase database,
    required IGroupsDao groupsDao,
    required ISyncDao syncDao,
    required IEventBroker eventBroker,
    required this.ownerId,
  }) : _database = database,
       _groupsDao = groupsDao,
       _syncDao = syncDao,
       _eventBroker = eventBroker;

  @override
  Future<GroupEntity> createGroup(GroupEntity group) async {
    try {
      // Atomic transaction: DB write + Queue entry (all or nothing)
      await _database.transaction<void>(() async {
        await _groupsDao.insertGroup(group);

        // Only enqueue non-personal groups for sync
        // Personal groups are local-only and don't need Firestore sync
        if (!group.isPersonal) {
          await _syncDao.enqueueOperation(
            ownerId: ownerId,
            entityType: EntityType.group,
            entityId: group.id,
            operationType: 'create',
          );
        }
      });

      // Fire events after successful operation
      _eventBroker.fire(GroupCreated(group));
      if (!group.isPersonal) {
        _eventBroker.fire(UploadQueueItemAdded('createGroup'));
      }
      log.d(
        'Created group: ${group.displayName} (personal: ${group.isPersonal}) by owner: $ownerId',
      );
      return group;
    } catch (e) {
      log.e('Failed to create group: $e');
      throw Exception('Failed to create group: $e');
    }
  }

  @override
  Future<GroupEntity> getGroupById(String id) async {
    try {
      final group = await _groupsDao.getGroupById(id);
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
      final groups = await _groupsDao.getAllGroups();
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
        await _groupsDao.updateGroup(group);

        // Only enqueue non-personal groups for sync
        if (!group.isPersonal) {
          await _syncDao.enqueueOperation(
            ownerId: ownerId,
            entityType: EntityType.group,
            entityId: group.id,
            operationType: 'update',
          );
        }
      });

      // Fire events after successful operation
      _eventBroker.fire(GroupUpdated(group));
      if (!group.isPersonal) {
        _eventBroker.fire(UploadQueueItemAdded('updateGroup'));
      }
      log.d(
        'Updated group: ${group.displayName} (personal: ${group.isPersonal}) by owner: $ownerId',
      );
      return group;
    } catch (e) {
      log.e('Failed to update group ${group.id}: $e');
      throw Exception('Failed to update group: $e');
    }
  }

  @override
  Future<void> deleteGroup(String id) async {
    try {
      // Check if group is personal before enqueueing
      final group = await _groupsDao.getGroupById(id);
      final isPersonal = group?.isPersonal ?? false;

      // Atomic transaction: Soft delete + Queue entry
      await _database.transaction<void>(() async {
        await _groupsDao.softDeleteGroup(id);

        // Only enqueue non-personal groups for sync
        if (!isPersonal) {
          await _syncDao.enqueueOperation(
            ownerId: ownerId,
            entityType: EntityType.group,
            entityId: id,
            operationType: 'delete',
          );
        }
      });

      // Fire events after successful operation
      _eventBroker.fire(GroupDeleted(id));
      if (!isPersonal) {
        _eventBroker.fire(UploadQueueItemAdded('deleteGroup'));
      }
      log.d('Deleted group: $id (personal: $isPersonal) by owner: $ownerId');
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
        await _groupsDao.addGroupMember(member);
        await _syncDao.enqueueOperation(
          ownerId: ownerId,
          entityType: EntityType.groupMember,
          entityId: '${member.groupId}_${member.userId}',
          operationType: 'create',
          metadata: member.groupId,
        );
      });

      // Fire events after successful operation
      _eventBroker.fire(MemberAdded(member));
      _eventBroker.fire(UploadQueueItemAdded('addMember'));
      log.d(
        'Added member ${member.userId} to group ${member.groupId} by owner: $ownerId',
      );
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
        await _groupsDao.removeGroupMember(groupId, userId);
        await _syncDao.enqueueOperation(
          ownerId: ownerId,
          entityType: EntityType.groupMember,
          entityId: '${groupId}_$userId',
          operationType: 'delete',
          metadata: groupId,
        );
      });

      // Fire events after successful operation
      _eventBroker.fire(MemberRemoved(groupId, userId));
      _eventBroker.fire(UploadQueueItemAdded('removeMember'));
      log.d('Removed member $userId from group $groupId by owner: $ownerId');
    } catch (e) {
      log.e('Failed to remove member: $e');
      throw Exception('Failed to remove member: $e');
    }
  }

  @override
  Future<List<GroupEntity>> getUserGroups(String userId) async {
    try {
      final groups = await _groupsDao.getUserGroups(userId);
      return groups;
    } catch (e) {
      log.e('Failed to get user groups: $e');
      throw Exception('Failed to get user groups: $e');
    }
  }

  @override
  Stream<List<GroupEntity>> watchUserGroups(String userId) {
    return _groupsDao.watchUserGroups(userId);
  }

  @override
  Stream<List<GroupEntity>> watchAllGroups() {
    return _groupsDao.watchAllGroups();
  }

  @override
  Future<List<String>> getGroupMembers(String groupId) async {
    try {
      final members = await _groupsDao.getGroupMembers(groupId);
      return members;
    } catch (e) {
      log.e('Failed to get group members: $e');
      throw Exception('Failed to get group members: $e');
    }
  }
}
