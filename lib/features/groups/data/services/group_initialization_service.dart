import 'package:fairshare_app/features/groups/domain/entities/group_entity.dart';
import 'package:fairshare_app/features/groups/domain/entities/group_member_entity.dart';
import 'package:fairshare_app/features/groups/domain/repositories/group_repository.dart';

class GroupInitializationService {
  final GroupRepository _repository;

  GroupInitializationService(this._repository);

  Future<void> ensurePersonalGroupExists(String userId) async {
    final result = await _repository.getGroupById('personal');

    await result.fold(
      (_) async {},
      (_) async => await _createPersonalGroup(userId),
    );
  }

  Future<void> _createPersonalGroup(String userId) async {
    final now = DateTime.now();

    final group = GroupEntity(
      id: 'personal',
      displayName: 'Personal',
      defaultCurrency: 'USD',
      createdAt: now,
      updatedAt: now,
    );

    final member = GroupMemberEntity(
      groupId: 'personal',
      userId: userId,
      joinedAt: now,
    );

    await _repository.createGroup(group);
    await _repository.addMember(member);
  }
}