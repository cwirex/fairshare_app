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
    @Default(true) bool optimizeSharing,
    @Default(true) bool isOpen,
    @Default(false) bool autoExchangeCurrency,
    @Default('USD') String defaultCurrency,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _GroupEntity;

  factory GroupEntity.fromJson(Map<String, dynamic> json) =>
      _$GroupEntityFromJson(json);
}

extension GroupEntityX on GroupEntity {
  /// Whether this is a personal (local-only) group
  bool get isPersonal => id.startsWith('personal_');

  /// Whether this group should be synced to Firestore
  bool get shouldSync => !isPersonal;
}
