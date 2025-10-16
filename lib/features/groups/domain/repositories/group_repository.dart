import 'package:fairshare_app/features/groups/domain/entities/group_entity.dart';
import 'package:fairshare_app/features/groups/domain/entities/group_member_entity.dart';

/// Repository interface for group data operations.
///
/// Abstracts the data source (local database, remote API, etc.)
/// to keep the domain layer independent of implementation details.
///
/// All methods throw exceptions on failure (no `Result<T>` wrapping).
/// Use cases are responsible for catching exceptions and wrapping in `Result<T>`.
///
/// For multi-user offline-first architecture:
/// - Repository implementations are user-scoped (created with a specific ownerId)
/// - The ownerId is injected via constructor, not passed to each method
/// - This ensures sync queue entries are scoped to the correct user
/// - Prevents cross-user data leakage during sign-out/sign-in
abstract class GroupRepository {
  /// Create a new group
  Future<GroupEntity> createGroup(GroupEntity group);

  /// Get group by ID
  Future<GroupEntity> getGroupById(String id);

  /// Get all groups
  Future<List<GroupEntity>> getAllGroups();

  /// Update an existing group
  Future<GroupEntity> updateGroup(GroupEntity group);

  /// Delete a group
  Future<void> deleteGroup(String id);

  /// Add a member to a group
  Future<void> addMember(GroupMemberEntity member);

  /// Remove a member from a group
  Future<void> removeMember(String groupId, String userId);

  /// Get all member IDs for a group
  Future<List<String>> getGroupMembers(String groupId);

  /// Get all groups for a user
  Future<List<GroupEntity>> getUserGroups(String userId);

  /// Watch all groups (stream)
  Stream<List<GroupEntity>> watchAllGroups();

  /// Watch all groups for a user (stream)
  Stream<List<GroupEntity>> watchUserGroups(String userId);

  /// Join a group by code (requires internet connection)
  Future<GroupEntity> joinGroupByCode(String groupCode, String userId);
}
