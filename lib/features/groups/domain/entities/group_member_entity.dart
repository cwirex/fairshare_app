import 'package:freezed_annotation/freezed_annotation.dart';

part 'group_member_entity.freezed.dart';
part 'group_member_entity.g.dart';

/// User membership in a group.
@freezed
abstract class GroupMemberEntity with _$GroupMemberEntity {
  const factory GroupMemberEntity({
    required String groupId,
    required String userId,
    required DateTime joinedAt,
    @Default(false) bool isSynced,
  }) = _GroupMemberEntity;

  factory GroupMemberEntity.fromJson(Map<String, dynamic> json) =>
      _$GroupMemberEntityFromJson(json);
}
