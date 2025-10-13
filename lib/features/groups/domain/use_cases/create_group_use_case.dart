import 'package:fairshare_app/core/domain/use_case.dart';
import 'package:fairshare_app/features/groups/domain/entities/group_entity.dart';
import 'package:fairshare_app/features/groups/domain/repositories/group_repository.dart';

/// Use case for creating a new group.
class CreateGroupUseCase extends UseCase<GroupEntity, GroupEntity> {
  final GroupRepository _repository;

  CreateGroupUseCase(this._repository);

  @override
  void validate(GroupEntity input) {
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
    log.d('Creating group: ${input.displayName}');
    return await _repository.createGroup(input);
  }
}
