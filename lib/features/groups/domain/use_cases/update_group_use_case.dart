import 'package:fairshare_app/core/domain/use_case.dart';
import 'package:fairshare_app/features/groups/domain/entities/group_entity.dart';
import 'package:fairshare_app/features/groups/domain/repositories/group_repository.dart';
import 'package:fairshare_app/features/groups/domain/use_cases/group_use_case_interfaces.dart';

/// Use case for updating an existing group.
class UpdateGroupUseCase extends UseCase<GroupEntity, GroupEntity>
    implements IUpdateGroupUseCase {
  final GroupRepository _repository;

  UpdateGroupUseCase(this._repository);

  @override
  void validate(GroupEntity input) {
    if (input.id.trim().isEmpty) {
      throw Exception('Group ID is required');
    }

    if (input.displayName.trim().isEmpty) {
      throw Exception('Group name is required');
    }

    if (input.displayName.trim().length < 2) {
      throw Exception('Group name must be at least 2 characters');
    }

    if (input.displayName.trim().length > 100) {
      throw Exception('Group name must be less than 100 characters');
    }

    if (input.defaultCurrency.trim().isEmpty) {
      throw Exception('Default currency is required');
    }
  }

  @override
  Future<GroupEntity> execute(GroupEntity input) async {
    log.d('Updating group: ${input.displayName}');
    return await _repository.updateGroup(input);
  }
}
