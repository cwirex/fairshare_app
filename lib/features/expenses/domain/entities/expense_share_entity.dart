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
