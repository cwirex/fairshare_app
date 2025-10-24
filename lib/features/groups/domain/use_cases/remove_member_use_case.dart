import 'package:fairshare_app/core/domain/use_case.dart';
import 'package:fairshare_app/features/groups/domain/repositories/group_repository.dart';
import 'package:fairshare_app/features/groups/domain/use_cases/group_use_case_interfaces.dart';
import 'package:result_dart/result_dart.dart';

/// Parameters for removing a member from a group.
class RemoveMemberParams {
  final String groupId;
  final String userId;

  const RemoveMemberParams({
    required this.groupId,
    required this.userId,
  });
}

/// Use case for removing a member from a group.
class RemoveMemberUseCase extends UseCase<RemoveMemberParams, Unit>
    implements IRemoveMemberUseCase {
  final GroupRepository _repository;

  RemoveMemberUseCase(this._repository);

  @override
  void validate(RemoveMemberParams input) {
    if (input.groupId.trim().isEmpty) {
      throw Exception('Group ID is required');
    }

    if (input.userId.trim().isEmpty) {
      throw Exception('User ID is required');
    }
  }

  @override
  Future<Unit> execute(RemoveMemberParams input) async {
    log.d('Removing member ${input.userId} from group ${input.groupId}');
    await _repository.removeMember(input.groupId, input.userId);
    return unit;
  }
}
