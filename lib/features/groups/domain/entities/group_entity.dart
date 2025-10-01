import 'package:freezed_annotation/freezed_annotation.dart';

part 'group_entity.freezed.dart';
part 'group_entity.g.dart';

/// Group for sharing expenses.
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
    @Default(false) bool isSynced,
  }) = _GroupEntity;

  factory GroupEntity.fromJson(Map<String, dynamic> json) =>
      _$GroupEntityFromJson(json);
}
