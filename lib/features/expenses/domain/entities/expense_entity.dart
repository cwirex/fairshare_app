import 'package:freezed_annotation/freezed_annotation.dart';

part 'expense_entity.freezed.dart';
part 'expense_entity.g.dart';

/// Shared expense in a group.
///
/// Pure data model. Use ExpenseFormatter for display logic.
@freezed
abstract class ExpenseEntity with _$ExpenseEntity {
  const factory ExpenseEntity({
    required String id,
    required String groupId,
    required String title,
    required double amount,
    required String currency,
    required String paidBy,
    @Default(true) bool shareWithEveryone,
    required DateTime expenseDate,
    required DateTime createdAt,
    required DateTime updatedAt,
    @Default(false) bool isSynced,
  }) = _ExpenseEntity;

  factory ExpenseEntity.fromJson(Map<String, dynamic> json) =>
      _$ExpenseEntityFromJson(json);
}
