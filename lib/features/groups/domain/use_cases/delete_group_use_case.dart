import 'package:fairshare_app/core/domain/use_case.dart';
import 'package:fairshare_app/features/groups/domain/repositories/group_repository.dart';
import 'package:fairshare_app/features/groups/domain/use_cases/group_use_case_interfaces.dart';
import 'package:result_dart/result_dart.dart';

/// Use case for deleting a group.
class DeleteGroupUseCase extends UseCase<String, Unit>
    implements IDeleteGroupUseCase {
  final GroupRepository _repository;

  DeleteGroupUseCase(this._repository);

  @override
  void validate(String input) {
    if (input.trim().isEmpty) {
      throw Exception('Group ID is required');
    }
  }

  @override
  Future<Unit> execute(String input) async {
    log.d('Deleting group: $input');
    await _repository.deleteGroup(input);
    return unit;
  }
}
