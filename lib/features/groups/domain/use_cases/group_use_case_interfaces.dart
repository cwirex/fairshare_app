import 'package:fairshare_app/features/groups/domain/entities/group_entity.dart';
import 'package:fairshare_app/features/groups/domain/entities/group_member_entity.dart';
import 'package:fairshare_app/features/groups/domain/use_cases/join_group_by_code_use_case.dart';
import 'package:fairshare_app/features/groups/domain/use_cases/remove_member_use_case.dart';
import 'package:result_dart/result_dart.dart';

/// Interface for creating a new group.
abstract class ICreateGroupUseCase {
  Future<Result<GroupEntity>> call(GroupEntity group);
}

/// Interface for updating an existing group.
abstract class IUpdateGroupUseCase {
  Future<Result<GroupEntity>> call(GroupEntity group);
}

/// Interface for deleting a group.
abstract class IDeleteGroupUseCase {
  Future<Result<Unit>> call(String groupId);
}

/// Interface for adding a member to a group.
abstract class IAddMemberUseCase {
  Future<Result<Unit>> call(GroupMemberEntity member);
}

/// Interface for removing a member from a group.
abstract class IRemoveMemberUseCase {
  Future<Result<Unit>> call(RemoveMemberParams params);
}

/// Interface for joining a group using an invite code.
abstract class IJoinGroupByCodeUseCase {
  Future<Result<GroupEntity>> call(JoinGroupByCodeParams params);
}
