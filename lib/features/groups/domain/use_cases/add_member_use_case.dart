import 'package:fairshare_app/core/domain/use_case.dart';
import 'package:fairshare_app/features/groups/domain/entities/group_member_entity.dart';
import 'package:fairshare_app/features/groups/domain/repositories/group_repository.dart';
import 'package:result_dart/result_dart.dart';

/// Use case for adding a member to a group.
class AddMemberUseCase extends UseCase<GroupMemberEntity, Unit> {
  final GroupRepository _repository;

  AddMemberUseCase(this._repository);

  @override
  void validate(GroupMemberEntity input) {
    if (input.groupId.trim().isEmpty) {
      throw Exception('Group ID is required');
    }

    if (input.userId.trim().isEmpty) {
      throw Exception('User ID is required');
    }
  }

  @override
  Future<Unit> execute(GroupMemberEntity input) async {
    log.d('Adding member ${input.userId} to group ${input.groupId}');
    await _repository.addMember(input);
    return unit;
  }
}
