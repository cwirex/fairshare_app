import 'package:freezed_annotation/freezed_annotation.dart';

part 'expense_entity.freezed.dart';
part 'expense_entity.g.dart';

/// Shared expense in a group.
///
/// Pure data model. Use ExpenseFormatter for display logic.
/// Sync is handled by comparing expense.updatedAt with group.lastUpdateTimestamp.
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
    DateTime? deletedAt,
  }) = _ExpenseEntity;

  factory ExpenseEntity.fromJson(Map<String, dynamic> json) =>
      _$ExpenseEntityFromJson(json);
}

extension ExpenseEntityX on ExpenseEntity {
  /// Whether this expense has been soft-deleted
  bool get isDeleted => deletedAt != null;

  /// Whether this expense is active (not deleted)
  bool get isActive => deletedAt == null;

  /// Unique key for this object
  String get key => id;
}

/// Firestore field names for ExpenseEntity
abstract class ExpenseFields {
  static const String id = 'id';
  static const String groupId = 'group_id';
  static const String title = 'title';
  static const String amount = 'amount';
  static const String currency = 'currency';
  static const String paidBy = 'paid_by';
  static const String shareWithEveryone = 'share_with_everyone';
  static const String expenseDate = 'expense_date';
  static const String createdAt = 'created_at';
  static const String updatedAt = 'updated_at';
  static const String deletedAt = 'deleted_at';
}
