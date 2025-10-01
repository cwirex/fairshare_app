import 'package:result_dart/result_dart.dart';

import 'package:fairshare_app/features/groups/domain/entities/group_entity.dart';
import 'package:fairshare_app/features/groups/domain/entities/group_member_entity.dart';

abstract class GroupRepository {
  Future<Result<GroupEntity>> createGroup(GroupEntity group);

  Future<Result<GroupEntity>> getGroupById(String id);

  Future<Result<List<GroupEntity>>> getAllGroups();

  Future<Result<GroupEntity>> updateGroup(GroupEntity group);

  Future<Result<void>> deleteGroup(String id);

  Future<Result<void>> addMember(GroupMemberEntity member);

  Future<Result<void>> removeMember(String groupId, String userId);

  Future<Result<List<String>>> getGroupMembers(String groupId);

  Future<Result<List<GroupEntity>>> getUserGroups(String userId);

  Stream<List<GroupEntity>> watchAllGroups();

  Stream<List<GroupEntity>> watchUserGroups(String userId);
}