import 'package:fairshare_app/core/events/app_event.dart';
import 'package:fairshare_app/features/groups/domain/entities/group_entity.dart';
import 'package:fairshare_app/features/groups/domain/entities/group_member_entity.dart';

/// Event fired when a group is created.
class GroupCreated extends AppEvent {
  final GroupEntity group;

  GroupCreated(this.group);

  @override
  String toString() => 'GroupCreated(${group.id}, ${group.displayName})';
}

/// Event fired when a group is updated.
class GroupUpdated extends AppEvent {
  final GroupEntity group;
  final GroupEntity? previousVersion;

  GroupUpdated(this.group, [this.previousVersion]);

  @override
  String toString() => 'GroupUpdated(${group.id}, ${group.displayName})';
}

/// Event fired when a group is deleted.
class GroupDeleted extends AppEvent {
  final String groupId;

  GroupDeleted(this.groupId);

  @override
  String toString() => 'GroupDeleted($groupId)';
}

/// Event fired when a member is added to a group.
class MemberAdded extends AppEvent {
  final GroupMemberEntity member;

  MemberAdded(this.member);

  @override
  String toString() =>
      'MemberAdded(group: ${member.groupId}, user: ${member.userId})';
}

/// Event fired when a member is removed from a group.
class MemberRemoved extends AppEvent {
  final String groupId;
  final String userId;

  MemberRemoved(this.groupId, this.userId);

  @override
  String toString() => 'MemberRemoved(group: $groupId, user: $userId)';
}
