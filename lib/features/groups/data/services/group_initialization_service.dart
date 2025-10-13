import 'package:fairshare_app/core/logging/app_logger.dart';
import 'package:fairshare_app/features/groups/domain/entities/group_entity.dart';
import 'package:fairshare_app/features/groups/domain/entities/group_member_entity.dart';
import 'package:fairshare_app/features/groups/domain/repositories/group_repository.dart';

/// Service to ensure a user's personal group exists.
///
/// This service is called during app initialization to create a personal
/// expense tracking group if it doesn't already exist.
class GroupInitializationService with LoggerMixin {
  final GroupRepository _repository;

  GroupInitializationService(this._repository);

  Future<void> ensurePersonalGroupExists(String userId) async {
    final personalGroupId = 'personal_$userId';

    try {
      // Try to get the personal group
      await _repository.getGroupById(personalGroupId);
      log.d('Personal group already exists for user: $userId');
    } catch (e) {
      // Group doesn't exist, create it
      log.i('Creating personal group for user: $userId');
      await _createPersonalGroup(userId);
    }
  }

  Future<void> _createPersonalGroup(String userId) async {
    final now = DateTime.now();
    final personalGroupId = 'personal_$userId';

    final group = GroupEntity(
      id: personalGroupId,
      displayName: 'Personal Expenses',
      isPersonal: true,
      defaultCurrency: 'USD',
      createdAt: now,
      updatedAt: now,
      lastActivityAt: now,
    );

    final member = GroupMemberEntity(
      groupId: personalGroupId,
      userId: userId,
      joinedAt: now,
    );

    await _repository.createGroup(group);
    await _repository.addMember(member);
  }
}
