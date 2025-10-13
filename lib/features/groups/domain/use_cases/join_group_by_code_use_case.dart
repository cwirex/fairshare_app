import 'package:fairshare_app/core/domain/use_case.dart';
import 'package:fairshare_app/features/groups/domain/entities/group_entity.dart';
import 'package:fairshare_app/features/groups/domain/repositories/group_repository.dart';

/// Parameters for joining a group by code.
class JoinGroupByCodeParams {
  final String groupCode;
  final String userId;

  const JoinGroupByCodeParams({required this.groupCode, required this.userId});
}

/// Use case for joining a group using an invite code.
///
/// This use case handles fetching the group from Firestore and adding the user as a member.
class JoinGroupByCodeUseCase
    extends UseCase<JoinGroupByCodeParams, GroupEntity> {
  final GroupRepository _repository;

  JoinGroupByCodeUseCase(this._repository);

  @override
  void validate(JoinGroupByCodeParams input) {
    if (input.groupCode.trim().isEmpty) {
      throw Exception('Group code is required');
    }

    if (input.userId.trim().isEmpty) {
      throw Exception('User ID is required');
    }
  }

  @override
  Future<GroupEntity> execute(JoinGroupByCodeParams input) async {
    log.d(
      'Joining group with code: ${input.groupCode} for user: ${input.userId}',
    );
    return await _repository.joinGroupByCode(input.groupCode, input.userId);
  }
}
