import 'package:fairshare_app/core/domain/use_case.dart';
import 'package:fairshare_app/features/groups/domain/entities/group_entity.dart';
import 'package:fairshare_app/features/groups/domain/entities/group_member_entity.dart';
import 'package:fairshare_app/features/groups/domain/repositories/group_repository.dart';
import 'package:fairshare_app/features/groups/domain/services/remote_group_service.dart';
import 'package:fairshare_app/features/groups/domain/use_cases/group_use_case_interfaces.dart';

/// Parameters for joining a group by code.
class JoinGroupByCodeParams {
  final String groupCode;
  final String userId;

  const JoinGroupByCodeParams({required this.groupCode, required this.userId});
}

/// Use case for joining a group using an invite code.
///
/// This use case orchestrates both remote and local operations:
/// 1. Fetches the group from remote service (Firestore) to verify it exists
/// 2. Uploads the new member to remote service
/// 3. Saves the group and member locally via repository
///
/// This is the orchestration layer that coordinates RemoteGroupService and GroupRepository.
class JoinGroupByCodeUseCase
    extends UseCase<JoinGroupByCodeParams, GroupEntity>
    implements IJoinGroupByCodeUseCase {
  final GroupRepository _repository;
  final RemoteGroupService _remoteService;

  JoinGroupByCodeUseCase(this._repository, this._remoteService);

  @override
  void validate(JoinGroupByCodeParams input) {
    if (input.groupCode.trim().isEmpty) {
      throw Exception('Group code is required');
    }
    if (input.userId.trim().isEmpty) {
      throw Exception('User ID is required');
    }
    // Validate 6-digit format
    if (input.groupCode.length != 6 || !RegExp(r'^\d{6}$').hasMatch(input.groupCode)) {
      throw Exception('Group code must be exactly 6 digits');
    }
  }

  @override
  Future<GroupEntity> execute(JoinGroupByCodeParams input) async {
    log.i('Attempting to join group with code: ${input.groupCode} for user: ${input.userId}');

    // 1. Check if user is already a member of this group locally
    try {
      final userGroups = await _repository.getUserGroups(input.userId);
      final existingGroup = userGroups.where((g) => g.id == input.groupCode).firstOrNull;

      if (existingGroup != null) {
        log.w('User ${input.userId} is already a member of group ${input.groupCode}. Returning existing group.');
        return existingGroup;
      }

      log.d('User is not a member of group ${input.groupCode}, proceeding to join.');
    } catch (e) {
      log.d('Error checking local membership: $e. Proceeding to join from remote.');
      // Continue with join flow
    }

    // 2. Fetch group from remote service to verify it exists
    log.d('Fetching group ${input.groupCode} from remote service...');
    final groupResult = await _remoteService.downloadGroup(input.groupCode);

    final remoteGroup = await groupResult.fold(
      (group) async => group,
      (error) async => throw Exception('Group not found: ${error.toString()}'),
    );

    log.i('Found group: ${remoteGroup.displayName}');

    // 3. Create new member entity
    final newMember = GroupMemberEntity(
      groupId: input.groupCode,
      userId: input.userId,
      joinedAt: DateTime.now().toUtc(),
    );

    // 4. Upload new member to remote service first
    log.d('Adding user ${input.userId} as member to remote group...');
    final uploadResult = await _remoteService.uploadGroupMember(newMember);

    await uploadResult.fold(
      (_) async => log.d('Successfully added member to remote group'),
      (error) async => throw Exception('Failed to join group remotely: ${error.toString()}'),
    );

    // 5. Save group locally via repository
    log.d('Saving group locally...');
    final savedGroup = await _repository.createGroup(remoteGroup);

    // 6. Add member locally via repository
    log.d('Adding member locally...');
    await _repository.addMember(newMember);

    log.i('Successfully joined group: ${remoteGroup.displayName}');
    return savedGroup;
  }
}
