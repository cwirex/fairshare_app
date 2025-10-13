import 'package:freezed_annotation/freezed_annotation.dart';

part 'group_balance_entity.freezed.dart';
part 'group_balance_entity.g.dart';

/// Balance information for a user in a specific group.
///
/// A positive balance means the group owes the user money.
/// A negative balance means the user owes the group money.
@freezed
abstract class GroupBalanceEntity with _$GroupBalanceEntity {
  const factory GroupBalanceEntity({
    required String groupId,
    required String userId,
    @Default(0.0) double balance,
    required DateTime updatedAt,
  }) = _GroupBalanceEntity;

  factory GroupBalanceEntity.fromJson(Map<String, dynamic> json) =>
      _$GroupBalanceEntityFromJson(json);
}

extension GroupBalanceEntityX on GroupBalanceEntity {
  /// Unique key for this object
  String get key => '$groupId-$userId';

  /// Whether the user is owed money (positive balance)
  bool get isOwed => balance > 0;

  /// Whether the user owes money (negative balance)
  bool get owes => balance < 0;

  /// Whether the balance is settled (zero)
  bool get isSettled => balance == 0;

  /// Absolute value of the balance
  double get absoluteBalance => balance.abs();
}
