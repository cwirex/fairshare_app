import 'package:freezed_annotation/freezed_annotation.dart';

part 'group_entity.freezed.dart';
part 'group_entity.g.dart';

/// Group for sharing expenses.
///
/// Uses timestamp-based sync tracking. Groups track their last update time,
/// and users track when they last synced each group.
@freezed
abstract class GroupEntity with _$GroupEntity {
  const factory GroupEntity({
    required String id,
    required String displayName,
    @Default('') String avatarUrl,
    @Default(false) bool isPersonal,
    @Default('USD') String defaultCurrency,
    required DateTime createdAt,
    required DateTime updatedAt,
    required DateTime lastActivityAt,
    DateTime? deletedAt,
  }) = _GroupEntity;

  factory GroupEntity.fromJson(Map<String, dynamic> json) =>
      _$GroupEntityFromJson(json);
}

extension GroupEntityX on GroupEntity {
  /// Unique key for this object
  String get key => id;

  /// Whether this group has been soft-deleted
  bool get isDeleted => deletedAt != null;

  /// Whether this group is active (not deleted)
  bool get isActive => deletedAt == null;
}
