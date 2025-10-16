import 'package:freezed_annotation/freezed_annotation.dart';

part 'expense_share_entity.freezed.dart';
part 'expense_share_entity.g.dart';

/// Individual user's share of an expense.
@freezed
abstract class ExpenseShareEntity with _$ExpenseShareEntity {
  const factory ExpenseShareEntity({
    required String expenseId,
    required String userId,
    required double shareAmount,
  }) = _ExpenseShareEntity;

  factory ExpenseShareEntity.fromJson(Map<String, dynamic> json) =>
      _$ExpenseShareEntityFromJson(json);
}

extension ExpenseShareEntityX on ExpenseShareEntity {
  /// Unique key for this object
  String get key => '$expenseId-$userId';
}

/// Firestore field names for ExpenseShareEntity
abstract class ExpenseShareFields {
  static const String expenseId = 'expense_id';
  static const String userId = 'user_id';
  static const String shareAmount = 'share_amount';
}
