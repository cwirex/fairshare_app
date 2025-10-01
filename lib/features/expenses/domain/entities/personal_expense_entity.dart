import 'package:freezed_annotation/freezed_annotation.dart';

part 'personal_expense_entity.freezed.dart';
part 'personal_expense_entity.g.dart';

/// Personal expense - simplified expense model for user's personal expenses only.
///
/// Stored under users/{userId}/personal_expenses/{expenseId} in Firestore.
/// No sharing, no group info - just basic expense tracking.
@freezed
abstract class PersonalExpenseEntity with _$PersonalExpenseEntity {
  const factory PersonalExpenseEntity({
    required String id,
    required String userId,
    required String title,
    @Default('') String description,
    required double amount,
    required String currency,
    @Default('') String category,
    required DateTime expenseDate,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _PersonalExpenseEntity;

  factory PersonalExpenseEntity.fromJson(Map<String, dynamic> json) =>
      _$PersonalExpenseEntityFromJson(json);
}
