import 'package:fairshare_app/features/groups/domain/entities/group_entity.dart';
import 'package:fairshare_app/features/groups/domain/entities/group_member_entity.dart';
import 'package:result_dart/result_dart.dart';

/// Abstract interface for remote group operations.
///
/// This service handles all network-based group operations (e.g., Firestore).
/// It abstracts the remote data source implementation from the domain layer,
/// following clean architecture and dependency inversion principles.
///
/// Implementations should handle:
/// - Network operations (upload, download, delete)
/// - Real-time streaming (watch operations)
/// - Error handling and logging
///
/// This interface is used by use cases to orchestrate remote + local operations.
abstract class RemoteGroupService {
  /// Upload a group to the remote database.
  Future<Result<void>> uploadGroup(GroupEntity group);

  /// Upload a group member to the remote database.
  Future<Result<void>> uploadGroupMember(
    GroupMemberEntity member, {
    bool isPersonalGroup = false,
  });

  /// Download a specific group by ID from the remote database.
  ///
  /// Used when joining a group by code to verify it exists and get its info.
  Future<Result<GroupEntity>> downloadGroup(String groupId);

  /// Download all groups that a user is a member of.
  ///
  /// Used during sync to fetch groups the user belongs to.
  Future<Result<List<GroupEntity>>> downloadUserGroups(String userId);

  /// Download all members of a specific group.
  Future<Result<List<GroupMemberEntity>>> downloadGroupMembers(String groupId);

  /// Delete a group from the remote database.
  Future<Result<void>> deleteGroup(String groupId);

  /// Remove a member from a group in the remote database.
  Future<Result<void>> removeGroupMember(String groupId, String userId);

  /// Watch real-time changes to a specific group.
  Stream<GroupEntity> watchGroup(String groupId);

  /// Watch real-time changes to all groups a user is a member of.
  Stream<List<GroupEntity>> watchUserGroups(String userId);
}
