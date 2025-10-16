import 'package:drift/drift.dart';
import 'package:fairshare_app/core/database/app_database.dart';
import 'package:fairshare_app/core/database/tables/groups_table.dart';
import 'package:fairshare_app/core/database/tables/members_table.dart';
import 'package:fairshare_app/core/events/event_broker.dart';
import 'package:fairshare_app/core/events/group_events.dart';
import 'package:fairshare_app/core/logging/app_logger.dart';
import 'package:fairshare_app/features/groups/domain/entities/group_entity.dart';
import 'package:fairshare_app/features/groups/domain/entities/group_member_entity.dart';

part 'groups_dao.g.dart';

@DriftAccessor(tables: [AppGroups, AppGroupMembers])
class GroupsDao extends DatabaseAccessor<AppDatabase>
    with _$GroupsDaoMixin, LoggerMixin {
  final AppDatabase db;

  GroupsDao(this.db) : super(db);

  // Add your group-related database methods here
  Future<void> insertGroup(GroupEntity group) async {
    try {
      await into(appGroups).insert(
        AppGroupsCompanion(
          id: Value(group.id),
          displayName: Value(group.displayName),
          avatarUrl: Value(group.avatarUrl),
          isPersonal: Value(group.isPersonal),
          defaultCurrency: Value(group.defaultCurrency),
          createdAt: Value(group.createdAt),
          updatedAt: Value(group.updatedAt),
          lastActivityAt: Value(group.lastActivityAt),
          deletedAt: Value(group.deletedAt),
        ),
      );
      log.d('✅ Inserted group: ${group.id} (${group.displayName})');
    } catch (e) {
      log.e('❌ Failed to insert group ${group.id}: $e');
      // Check if it already exists
      final existing = await getGroupById(group.id);
      if (existing != null) {
        log.w('⚠️ Group ${group.id} already exists, updating instead');
        await updateGroup(group);
      } else {
        rethrow;
      }
    }
  }

  /// Get group by ID
  /// Set [includeDeleted] to true to also query soft-deleted groups
  Future<GroupEntity?> getGroupById(
    String id, {
    bool includeDeleted = false,
  }) async {
    final query = select(appGroups)..where((g) => g.id.equals(id));
    if (!includeDeleted) {
      query.where((g) => g.deletedAt.isNull());
    }
    final result = await query.getSingleOrNull();
    return result != null ? _groupFromDb(result) : null;
  }

  Future<List<GroupEntity>> getAllGroups() async {
    final query =
        select(appGroups)
          ..where((g) => g.deletedAt.isNull())
          ..orderBy([(g) => OrderingTerm.desc(g.createdAt)]);
    final results = await query.get();
    return results.map(_groupFromDb).toList();
  }

  Future<void> updateGroup(GroupEntity group) async {
    final now = DateTime.now();
    await update(appGroups).replace(
      AppGroupsCompanion(
        id: Value(group.id),
        displayName: Value(group.displayName),
        avatarUrl: Value(group.avatarUrl),
        isPersonal: Value(group.isPersonal),
        defaultCurrency: Value(group.defaultCurrency),
        createdAt: Value(group.createdAt),
        updatedAt: Value(now),
        lastActivityAt: Value(
          now,
        ), // Update activity timestamp on any group change
        deletedAt: Value(group.deletedAt),
      ),
    );
  }

  Future<void> deleteGroup(String id) async {
    await (delete(appGroups)..where((g) => g.id.equals(id))).go();
  }

  Future<void> addGroupMember(GroupMemberEntity member) async {
    try {
      await into(appGroupMembers).insert(
        AppGroupMembersCompanion(
          groupId: Value(member.groupId),
          userId: Value(member.userId),
          joinedAt: Value(member.joinedAt),
        ),
      );
      log.d('✅ Added member: ${member.userId} to group ${member.groupId}');
    } catch (e) {
      log.e('❌ Failed to add member: $e');
      log.e('   Group: ${member.groupId}, User: ${member.userId}');
      rethrow;
    }
  }

  Future<void> removeGroupMember(String groupId, String userId) async {
    await (delete(appGroupMembers)
      ..where((m) => m.groupId.equals(groupId) & m.userId.equals(userId))).go();
  }

  Future<List<String>> getGroupMembers(String groupId) async {
    final query = select(appGroupMembers)
      ..where((m) => m.groupId.equals(groupId));
    final results = await query.get();
    return results.map((m) => m.userId).toList();
  }

  Future<List<GroupEntity>> getUserGroups(String userId) async {
    final query =
        select(appGroups).join([
            innerJoin(
              appGroupMembers,
              appGroupMembers.groupId.equalsExp(appGroups.id),
            ),
          ])
          ..where(
            appGroupMembers.userId.equals(userId) &
                appGroups.deletedAt.isNull(),
          )
          ..orderBy([OrderingTerm.desc(appGroups.createdAt)]);

    final results = await query.get();
    final groups =
        results.map((row) => _groupFromDb(row.readTable(appGroups))).toList();

    log.d('📊 getUserGroups($userId): Found ${groups.length} groups');
    for (final group in groups) {
      log.d('   - ${group.displayName} (${group.id})');
    }

    return groups;
  }

  Stream<List<GroupEntity>> watchAllGroups() {
    final query =
        select(appGroups)
          ..where((g) => g.deletedAt.isNull())
          ..orderBy([(g) => OrderingTerm.desc(g.createdAt)]);
    return query.watch().map((rows) => rows.map(_groupFromDb).toList());
  }

  Stream<List<GroupEntity>> watchUserGroups(String userId) {
    log.d('🔄 watchUserGroups($userId): Starting stream');

    final query =
        select(appGroups).join([
            innerJoin(
              appGroupMembers,
              appGroupMembers.groupId.equalsExp(appGroups.id),
            ),
          ])
          ..where(
            appGroupMembers.userId.equals(userId) &
                appGroups.deletedAt.isNull(),
          )
          ..orderBy([OrderingTerm.desc(appGroups.createdAt)]);

    return query.watch().map((rows) {
      final groups =
          rows.map((row) => _groupFromDb(row.readTable(appGroups))).toList();
      log.d('🔄 watchUserGroups($userId): Emitting ${groups.length} groups');
      for (final group in groups) {
        log.d('   - ${group.displayName} (${group.id})');
      }
      return groups;
    });
  }

  /// Get all group members as entities
  Future<List<GroupMemberEntity>> getAllGroupMembers(String groupId) async {
    final query = select(appGroupMembers)
      ..where((m) => m.groupId.equals(groupId));
    final results = await query.get();
    return results.map(_groupMemberFromDb).toList();
  }

  /// Update group timestamp after server upload
  Future<void> updateGroupTimestamp(String id, DateTime serverTimestamp) async {
    await (update(appGroups)..where(
      (g) => g.id.equals(id),
    )).write(AppGroupsCompanion(updatedAt: Value(serverTimestamp)));
  }

  /// Update group's lastActivityAt timestamp
  Future<void> updateGroupActivity(String groupId) async {
    await (update(appGroups)..where(
      (g) => g.id.equals(groupId),
    )).write(AppGroupsCompanion(lastActivityAt: Value(DateTime.now())));
  }

  /// Insert or update a group member from remote sync (bypasses queue)
  /// Fires events to update UI when remote changes arrive
  ///
  /// [eventBroker] is passed in to maintain clean DAO architecture
  Future<void> upsertGroupMemberFromSync(
    GroupMemberEntity member,
    EventBroker eventBroker,
  ) async {
    final existingMembers = await getGroupMembers(member.groupId);
    final alreadyExists = existingMembers.contains(member.userId);

    await into(appGroupMembers).insert(
      AppGroupMembersCompanion(
        groupId: Value(member.groupId),
        userId: Value(member.userId),
        joinedAt: Value(member.joinedAt),
      ),
      mode: InsertMode.insertOrReplace,
    );

    // Fire event for remote member addition (only if new)
    if (!alreadyExists) {
      eventBroker.fire(MemberAdded(member));
      log.d('Remote member added: ${member.userId} to group ${member.groupId}');
    }
  }

  /// Insert or update a group from remote sync (bypasses queue)
  /// Fires events to update UI when remote changes arrive
  ///
  /// [eventBroker] is passed in to maintain clean DAO architecture
  Future<void> upsertGroupFromSync(
    GroupEntity group,
    EventBroker eventBroker,
  ) async {
    final existing = await getGroupById(group.id, includeDeleted: true);

    if (existing == null) {
      // New group from server - insert directly
      // Use insertOrIgnore to handle race condition where initial sync and listener both try to insert
      final inserted = await into(appGroups).insert(
        AppGroupsCompanion(
          id: Value(group.id),
          displayName: Value(group.displayName),
          avatarUrl: Value(group.avatarUrl),
          isPersonal: Value(group.isPersonal),
          defaultCurrency: Value(group.defaultCurrency),
          createdAt: Value(group.createdAt),
          updatedAt: Value(group.updatedAt),
          lastActivityAt: Value(group.lastActivityAt),
          deletedAt: Value(group.deletedAt),
        ),
        mode: InsertMode.insertOrIgnore,
      );

      // Fire event for remote creation (only if actually inserted, not ignored)
      if (inserted > 0) {
        eventBroker.fire(GroupCreated(group));
        log.d('Remote group created: ${group.displayName}');
      }
    } else {
      // Only update if remote version is newer (Last Write Wins)
      if (group.updatedAt.isAfter(existing.updatedAt)) {
        await (update(appGroups)..where((g) => g.id.equals(group.id))).write(
          AppGroupsCompanion(
            displayName: Value(group.displayName),
            avatarUrl: Value(group.avatarUrl),
            isPersonal: Value(group.isPersonal),
            defaultCurrency: Value(group.defaultCurrency),
            updatedAt: Value(group.updatedAt),
            lastActivityAt: Value(group.lastActivityAt),
            deletedAt: Value(group.deletedAt),
          ),
        );

        // Fire event for remote update
        eventBroker.fire(GroupUpdated(group));
        log.d('Remote group updated: ${group.displayName}');
      }
    }
  }

  GroupEntity _groupFromDb(AppGroup dbGroup) {
    return GroupEntity(
      id: dbGroup.id,
      displayName: dbGroup.displayName,
      avatarUrl: dbGroup.avatarUrl,
      isPersonal: dbGroup.isPersonal,
      defaultCurrency: dbGroup.defaultCurrency,
      createdAt: dbGroup.createdAt,
      updatedAt: dbGroup.updatedAt,
      lastActivityAt: dbGroup.lastActivityAt,
      deletedAt: dbGroup.deletedAt,
    );
  }

  /// Soft delete a group (sets deletedAt timestamp)
  Future<void> softDeleteGroup(String id) async {
    await (update(appGroups)..where((g) => g.id.equals(id))).write(
      AppGroupsCompanion(
        deletedAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Restore a soft-deleted group (clears deletedAt)
  Future<void> restoreGroup(String id) async {
    await (update(appGroups)..where((g) => g.id.equals(id))).write(
      AppGroupsCompanion(
        deletedAt: const Value(null),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Hard delete a group (permanent deletion).
  /// Call after successful server deletion.
  Future<void> hardDeleteGroup(String id) async {
    await (delete(appGroups)..where((g) => g.id.equals(id))).go();
  }

  GroupMemberEntity _groupMemberFromDb(AppGroupMember dbMember) {
    return GroupMemberEntity(
      groupId: dbMember.groupId,
      userId: dbMember.userId,
      joinedAt: dbMember.joinedAt,
    );
  }
}
