import 'package:fairshare_app/features/groups/domain/entities/group_entity.dart';
import 'package:fairshare_app/features/groups/domain/entities/group_member_entity.dart';
import 'package:fairshare_app/features/groups/domain/use_cases/join_group_by_code_use_case.dart';
import 'package:fairshare_app/features/groups/domain/use_cases/remove_member_use_case.dart';
import 'package:result_dart/result_dart.dart';

/// Interface for creating a new group.
///
/// Validates the group (name not empty) and creates it in the repository.
/// Automatically adds the creator as the first member.
/// The operation is queued for Firestore sync.
///
/// Returns [Result<GroupEntity>] with the created group on success,
/// or a failure with validation/repository errors.
abstract class ICreateGroupUseCase {
  /// Create a new group.
  ///
  /// [group] - The group entity to create.
  /// Returns the created group or a failure.
  Future<Result<GroupEntity>> call(GroupEntity group);
}

/// Interface for updating an existing group.
///
/// Validates the group (ID exists, name not empty) and updates it in the repository.
/// The operation is queued for Firestore sync.
///
/// Returns [Result<GroupEntity>] with the updated group on success,
/// or a failure with validation/repository errors.
abstract class IUpdateGroupUseCase {
  /// Update an existing group.
  ///
  /// [group] - The group entity with updated values.
  /// Returns the updated group or a failure.
  Future<Result<GroupEntity>> call(GroupEntity group);
}

/// Interface for deleting a group.
///
/// Validates the group ID and soft-deletes the group from the repository.
/// The operation is queued for Firestore sync.
///
/// Returns [Result<Unit>] on success, or a failure with validation/repository errors.
abstract class IDeleteGroupUseCase {
  /// Delete a group by ID.
  ///
  /// [groupId] - The ID of the group to delete.
  /// Returns Unit on success or a failure.
  Future<Result<Unit>> call(String groupId);
}

/// Interface for adding a member to a group.
///
/// Validates the member data and adds them to the group in the repository.
/// The operation is queued for Firestore sync.
///
/// Returns [Result<Unit>] on success, or a failure with validation/repository errors.
abstract class IAddMemberUseCase {
  /// Add a member to a group.
  ///
  /// [member] - The group member entity to add.
  /// Returns Unit on success or a failure.
  Future<Result<Unit>> call(GroupMemberEntity member);
}

/// Interface for removing a member from a group.
///
/// Validates the parameters and removes the member from the group in the repository.
/// The operation is queued for Firestore sync.
///
/// Returns [Result<Unit>] on success, or a failure with validation/repository errors.
abstract class IRemoveMemberUseCase {
  /// Remove a member from a group.
  ///
  /// [params] - Parameters containing groupId and userId to remove.
  /// Returns Unit on success or a failure.
  Future<Result<Unit>> call(RemoveMemberParams params);
}

/// Interface for joining a group using an invite code.
///
/// Validates the invite code, fetches the group from Firestore,
/// and adds the user as a member both locally and remotely.
///
/// Returns [Result<GroupEntity>] with the joined group on success,
/// or a failure if the code is invalid or operation fails.
abstract class IJoinGroupByCodeUseCase {
  /// Join a group using a 6-digit invite code.
  ///
  /// [params] - Parameters containing the invite code and user ID.
  /// Returns the joined group or a failure.
  Future<Result<GroupEntity>> call(JoinGroupByCodeParams params);
}
