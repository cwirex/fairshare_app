import 'package:fairshare_app/features/expenses/domain/entities/expense_share_entity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ExpenseShareEntity', () {
    test('should serialize to JSON correctly', () {
      // Arrange
      final share = ExpenseShareEntity(
        expenseId: 'exp1',
        userId: 'user1',
        shareAmount: 50.0,
      );

      // Act
      final json = share.toJson();

      // Assert
      expect(json['expense_id'], 'exp1');
      expect(json['user_id'], 'user1');
      expect(json['share_amount'], 50.0);
    });

    test('should deserialize from JSON correctly', () {
      // Arrange
      final json = {
        'expense_id': 'exp1',
        'user_id': 'user1',
        'share_amount': 50.0,
      };

      // Act
      final share = ExpenseShareEntity.fromJson(json);

      // Assert
      expect(share.expenseId, 'exp1');
      expect(share.userId, 'user1');
      expect(share.shareAmount, 50.0);
    });

    test('key should return composite key of expenseId and userId', () {
      // Arrange
      final share = ExpenseShareEntity(
        expenseId: 'exp1',
        userId: 'user1',
        shareAmount: 50.0,
      );

      // Assert
      expect(share.key, 'exp1-user1');
    });

    test('copyWith should create copy with updated fields', () {
      // Arrange
      final share = ExpenseShareEntity(
        expenseId: 'exp1',
        userId: 'user1',
        shareAmount: 50.0,
      );

      // Act
      final updated = share.copyWith(shareAmount: 75.0);

      // Assert
      expect(updated.expenseId, 'exp1');
      expect(updated.userId, 'user1');
      expect(updated.shareAmount, 75.0);
    });

    test('should handle decimal share amounts correctly', () {
      // Arrange
      final share = ExpenseShareEntity(
        expenseId: 'exp1',
        userId: 'user1',
        shareAmount: 33.33,
      );

      // Assert
      expect(share.shareAmount, 33.33);
    });

    test('equality should work correctly', () {
      // Arrange
      final share1 = ExpenseShareEntity(
        expenseId: 'exp1',
        userId: 'user1',
        shareAmount: 50.0,
      );
      final share2 = ExpenseShareEntity(
        expenseId: 'exp1',
        userId: 'user1',
        shareAmount: 50.0,
      );
      final share3 = ExpenseShareEntity(
        expenseId: 'exp1',
        userId: 'user2',
        shareAmount: 50.0,
      );

      // Assert
      expect(share1, equals(share2));
      expect(share1, isNot(equals(share3)));
    });
  });
}
