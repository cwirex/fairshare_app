import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fairshare_app/features/expenses/domain/entities/expense_entity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ExpenseEntity', () {
    final now = DateTime.now();
    final testExpense = ExpenseEntity(
      id: 'expense123',
      groupId: 'group456',
      title: 'Dinner',
      amount: 50.0,
      currency: 'USD',
      paidBy: 'user789',
      shareWithEveryone: true,
      expenseDate: now,
      createdAt: now,
      updatedAt: now,
      deletedAt: null,
    );

    group('JSON serialization', () {
      test('toJson should serialize correctly', () {
        final json = testExpense.toJson();

        expect(json['id'], 'expense123');
        expect(json['group_id'], 'group456');
        expect(json['title'], 'Dinner');
        expect(json['amount'], 50.0);
        expect(json['currency'], 'USD');
        expect(json['paid_by'], 'user789');
        expect(json['share_with_everyone'], true);
        expect(json['expense_date'], isA<String>());
        expect(json['created_at'], isA<String>());
        expect(json['updated_at'], isA<String>());
        expect(json['deleted_at'], null);
      });

      test('fromJson should deserialize from ISO8601 strings', () {
        final json = {
          'id': 'expense123',
          'group_id': 'group456',
          'title': 'Dinner',
          'amount': 50.0,
          'currency': 'USD',
          'paid_by': 'user789',
          'share_with_everyone': true,
          'expense_date': now.toIso8601String(),
          'created_at': now.toIso8601String(),
          'updated_at': now.toIso8601String(),
          'deleted_at': null,
        };

        final expense = ExpenseEntity.fromJson(json);

        expect(expense.id, 'expense123');
        expect(expense.groupId, 'group456');
        expect(expense.title, 'Dinner');
        expect(expense.amount, 50.0);
        expect(expense.currency, 'USD');
        expect(expense.paidBy, 'user789');
        expect(expense.shareWithEveryone, true);
        expect(expense.expenseDate, isA<DateTime>());
        expect(expense.createdAt, isA<DateTime>());
        expect(expense.updatedAt, isA<DateTime>());
        expect(expense.deletedAt, null);
      });

      test('fromJson should deserialize from Firestore Timestamps', () {
        final timestamp = Timestamp.fromDate(now);
        final json = {
          'id': 'expense123',
          'group_id': 'group456',
          'title': 'Dinner',
          'amount': 50.0,
          'currency': 'USD',
          'paid_by': 'user789',
          'share_with_everyone': true,
          'expense_date': timestamp,
          'created_at': timestamp,
          'updated_at': timestamp,
          'deleted_at': null,
        };

        final expense = ExpenseEntity.fromJson(json);

        expect(expense.id, 'expense123');
        expect(expense.groupId, 'group456');
        expect(expense.title, 'Dinner');
        expect(expense.expenseDate, isA<DateTime>());
        expect(expense.createdAt, isA<DateTime>());
        expect(expense.updatedAt, isA<DateTime>());
      });

      test('roundtrip serialization preserves data', () {
        final json = testExpense.toJson();
        final deserialized = ExpenseEntity.fromJson(json);

        expect(deserialized.id, testExpense.id);
        expect(deserialized.groupId, testExpense.groupId);
        expect(deserialized.title, testExpense.title);
        expect(deserialized.amount, testExpense.amount);
        expect(deserialized.currency, testExpense.currency);
        expect(deserialized.paidBy, testExpense.paidBy);
        expect(deserialized.shareWithEveryone, testExpense.shareWithEveryone);
      });
    });

    group('default values', () {
      test('should apply default shareWithEveryone', () {
        final json = {
          'id': 'expense123',
          'group_id': 'group456',
          'title': 'Dinner',
          'amount': 50.0,
          'currency': 'USD',
          'paid_by': 'user789',
          'expense_date': now.toIso8601String(),
          'created_at': now.toIso8601String(),
          'updated_at': now.toIso8601String(),
        };

        final expense = ExpenseEntity.fromJson(json);

        expect(expense.shareWithEveryone, true);
        expect(expense.deletedAt, null);
      });
    });

    group('extensions', () {
      test('isDeleted should return true when deletedAt is set', () {
        final deletedExpense = testExpense.copyWith(deletedAt: now);
        expect(deletedExpense.isDeleted, true);
      });

      test('isDeleted should return false when deletedAt is null', () {
        expect(testExpense.isDeleted, false);
      });

      test('isActive should return true when deletedAt is null', () {
        expect(testExpense.isActive, true);
      });

      test('isActive should return false when deletedAt is set', () {
        final deletedExpense = testExpense.copyWith(deletedAt: now);
        expect(deletedExpense.isActive, false);
      });

      test('key should return id', () {
        expect(testExpense.key, 'expense123');
      });
    });
  });
}
