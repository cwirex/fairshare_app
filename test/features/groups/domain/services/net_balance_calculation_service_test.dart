import 'package:fairshare_app/features/balances/domain/services/balance_calculation_service.dart';
import 'package:fairshare_app/features/expenses/domain/entities/expense_entity.dart';
import 'package:fairshare_app/features/expenses/domain/entities/expense_share_entity.dart';
import 'package:fairshare_app/features/groups/domain/entities/group_member_entity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late BalanceCalculationService service;

  setUp(() {
    service = BalanceCalculationService();
  });

  group('NetBalanceCalculationService', () {
    test('returns zero balances for empty expenses', () {
      // Arrange
      final members = [
        GroupMemberEntity(
          userId: 'alice',
          groupId: 'g1',
          joinedAt: DateTime(2025, 1, 1),
        ),
        GroupMemberEntity(
          userId: 'bob',
          groupId: 'g1',
          joinedAt: DateTime(2025, 1, 1),
        ),
      ];
      final expenses = <ExpenseEntity>[];
      final shares = <ExpenseShareEntity>[];

      // Act
      final result = service.calculateNetBalances(members, expenses, shares);

      // Assert
      expect(result['alice'], 0.0);
      expect(result['bob'], 0.0);
    });

    test('calculates simple two-person equal split', () {
      // Arrange
      final members = [
        GroupMemberEntity(
          userId: 'alice',
          groupId: 'g1',
          joinedAt: DateTime(2025, 1, 1),
        ),
        GroupMemberEntity(
          userId: 'bob',
          groupId: 'g1',
          joinedAt: DateTime(2025, 1, 1),
        ),
      ];

      final now = DateTime.now();
      final expenses = [
        ExpenseEntity(
          id: 'e1',
          groupId: 'g1',
          title: 'Dinner',
          amount: 100.0,
          paidBy: 'alice',
          currency: 'USD',
          expenseDate: now,
          createdAt: now,
          updatedAt: now,
          shareWithEveryone: true,
        ),
      ];

      final shares = [
        const ExpenseShareEntity(
          expenseId: 'e1',
          userId: 'alice',
          shareAmount: 50.0,
        ),
        const ExpenseShareEntity(
          expenseId: 'e1',
          userId: 'bob',
          shareAmount: 50.0,
        ),
      ];

      // Act
      final result = service.calculateNetBalances(members, expenses, shares);

      // Assert
      expect(result['alice'], 50.0); // Paid 100, owes 50 → net +50
      expect(result['bob'], -50.0); // Paid 0, owes 50 → net -50
    });

    test('calculates unequal split correctly', () {
      // Arrange
      final members = [
        GroupMemberEntity(
          userId: 'alice',
          groupId: 'g1',
          joinedAt: DateTime(2025, 1, 1),
        ),
        GroupMemberEntity(
          userId: 'bob',
          groupId: 'g1',
          joinedAt: DateTime(2025, 1, 1),
        ),
      ];

      final now = DateTime.now();
      final expenses = [
        ExpenseEntity(
          id: 'e1',
          groupId: 'g1',
          title: 'Dinner',
          amount: 100.0,
          paidBy: 'alice',
          currency: 'USD',
          expenseDate: now,
          createdAt: now,
          updatedAt: now,
          shareWithEveryone: false,
        ),
      ];

      final shares = [
        const ExpenseShareEntity(
          expenseId: 'e1',
          userId: 'alice',
          shareAmount: 30.0,
        ),
        const ExpenseShareEntity(
          expenseId: 'e1',
          userId: 'bob',
          shareAmount: 70.0,
        ),
      ];

      // Act
      final result = service.calculateNetBalances(members, expenses, shares);

      // Assert
      expect(result['alice'], 70.0); // Paid 100, owes 30 → net +70
      expect(result['bob'], -70.0); // Paid 0, owes 70 → net -70
    });

    test('calculates multiple expenses correctly', () {
      // Arrange
      final members = [
        GroupMemberEntity(
          userId: 'alice',
          groupId: 'g1',
          joinedAt: DateTime(2025, 1, 1),
        ),
        GroupMemberEntity(
          userId: 'bob',
          groupId: 'g1',
          joinedAt: DateTime(2025, 1, 1),
        ),
      ];

      final now = DateTime.now();
      final expenses = [
        ExpenseEntity(
          id: 'e1',
          groupId: 'g1',
          title: 'Dinner',
          amount: 100.0,
          paidBy: 'alice',
          currency: 'USD',
          expenseDate: now,
          createdAt: now,
          updatedAt: now,
          shareWithEveryone: true,
        ),
        ExpenseEntity(
          id: 'e2',
          groupId: 'g1',
          title: 'Taxi',
          amount: 40.0,
          paidBy: 'bob',
          currency: 'USD',
          expenseDate: now,
          createdAt: now,
          updatedAt: now,
          shareWithEveryone: true,
        ),
      ];

      final shares = [
        const ExpenseShareEntity(
          expenseId: 'e1',
          userId: 'alice',
          shareAmount: 50.0,
        ),
        const ExpenseShareEntity(
          expenseId: 'e1',
          userId: 'bob',
          shareAmount: 50.0,
        ),
        const ExpenseShareEntity(
          expenseId: 'e2',
          userId: 'alice',
          shareAmount: 20.0,
        ),
        const ExpenseShareEntity(
          expenseId: 'e2',
          userId: 'bob',
          shareAmount: 20.0,
        ),
      ];

      // Act
      final result = service.calculateNetBalances(members, expenses, shares);

      // Assert
      expect(result['alice'], 30.0); // Paid 100, owes 70 → net +30
      expect(result['bob'], -30.0); // Paid 40, owes 70 → net -30
    });

    test('handles three-person group', () {
      // Arrange
      final members = [
        GroupMemberEntity(
          userId: 'alice',
          groupId: 'g1',
          joinedAt: DateTime(2025, 1, 1),
        ),
        GroupMemberEntity(
          userId: 'bob',
          groupId: 'g1',
          joinedAt: DateTime(2025, 1, 1),
        ),
        GroupMemberEntity(
          userId: 'charlie',
          groupId: 'g1',
          joinedAt: DateTime(2025, 1, 1),
        ),
      ];

      final now = DateTime.now();
      final expenses = [
        ExpenseEntity(
          id: 'e1',
          groupId: 'g1',
          title: 'Dinner',
          amount: 150.0,
          paidBy: 'alice',
          currency: 'USD',
          expenseDate: now,
          createdAt: now,
          updatedAt: now,
          shareWithEveryone: true,
        ),
      ];

      final shares = [
        const ExpenseShareEntity(
          expenseId: 'e1',
          userId: 'alice',
          shareAmount: 50.0,
        ),
        const ExpenseShareEntity(
          expenseId: 'e1',
          userId: 'bob',
          shareAmount: 50.0,
        ),
        const ExpenseShareEntity(
          expenseId: 'e1',
          userId: 'charlie',
          shareAmount: 50.0,
        ),
      ];

      // Act
      final result = service.calculateNetBalances(members, expenses, shares);

      // Assert
      expect(result['alice'], 100.0); // Paid 150, owes 50 → net +100
      expect(result['bob'], -50.0); // Paid 0, owes 50 → net -50
      expect(result['charlie'], -50.0); // Paid 0, owes 50 → net -50
    });

    test('handles complex scenario with multiple payers', () {
      // Arrange
      final members = [
        GroupMemberEntity(
          userId: 'alice',
          groupId: 'g1',
          joinedAt: DateTime(2025, 1, 1),
        ),
        GroupMemberEntity(
          userId: 'bob',
          groupId: 'g1',
          joinedAt: DateTime(2025, 1, 1),
        ),
        GroupMemberEntity(
          userId: 'charlie',
          groupId: 'g1',
          joinedAt: DateTime(2025, 1, 1),
        ),
      ];

      final now = DateTime.now();
      final expenses = [
        ExpenseEntity(
          id: 'e1',
          groupId: 'g1',
          title: 'Hotel',
          amount: 300.0,
          paidBy: 'alice',
          currency: 'USD',
          expenseDate: now,
          createdAt: now,
          updatedAt: now,
          shareWithEveryone: true,
        ),
        ExpenseEntity(
          id: 'e2',
          groupId: 'g1',
          title: 'Food',
          amount: 150.0,
          paidBy: 'bob',
          currency: 'USD',
          expenseDate: now,
          createdAt: now,
          updatedAt: now,
          shareWithEveryone: true,
        ),
        ExpenseEntity(
          id: 'e3',
          groupId: 'g1',
          title: 'Gas',
          amount: 60.0,
          paidBy: 'charlie',
          currency: 'USD',
          expenseDate: now,
          createdAt: now,
          updatedAt: now,
          shareWithEveryone: true,
        ),
      ];

      final shares = [
        // e1 shares
        const ExpenseShareEntity(
          expenseId: 'e1',
          userId: 'alice',
          shareAmount: 100.0,
        ),
        const ExpenseShareEntity(
          expenseId: 'e1',
          userId: 'bob',
          shareAmount: 100.0,
        ),
        const ExpenseShareEntity(
          expenseId: 'e1',
          userId: 'charlie',
          shareAmount: 100.0,
        ),
        // e2 shares
        const ExpenseShareEntity(
          expenseId: 'e2',
          userId: 'alice',
          shareAmount: 50.0,
        ),
        const ExpenseShareEntity(
          expenseId: 'e2',
          userId: 'bob',
          shareAmount: 50.0,
        ),
        const ExpenseShareEntity(
          expenseId: 'e2',
          userId: 'charlie',
          shareAmount: 50.0,
        ),
        // e3 shares
        const ExpenseShareEntity(
          expenseId: 'e3',
          userId: 'alice',
          shareAmount: 20.0,
        ),
        const ExpenseShareEntity(
          expenseId: 'e3',
          userId: 'bob',
          shareAmount: 20.0,
        ),
        const ExpenseShareEntity(
          expenseId: 'e3',
          userId: 'charlie',
          shareAmount: 20.0,
        ),
      ];

      // Act
      final result = service.calculateNetBalances(members, expenses, shares);

      // Assert
      // Alice: paid 300, owes 170 → +130
      // Bob: paid 150, owes 170 → -20
      // Charlie: paid 60, owes 170 → -110
      expect(result['alice'], 130.0);
      expect(result['bob'], -20.0);
      expect(result['charlie'], -110.0);
    });

    test('handles floating point precision', () {
      // Arrange
      final members = [
        GroupMemberEntity(
          userId: 'alice',
          groupId: 'g1',
          joinedAt: DateTime(2025, 1, 1),
        ),
        GroupMemberEntity(
          userId: 'bob',
          groupId: 'g1',
          joinedAt: DateTime(2025, 1, 1),
        ),
        GroupMemberEntity(
          userId: 'charlie',
          groupId: 'g1',
          joinedAt: DateTime(2025, 1, 1),
        ),
      ];

      final now = DateTime.now();
      final expenses = [
        ExpenseEntity(
          id: 'e1',
          groupId: 'g1',
          title: 'Odd amount',
          amount: 100.0,
          paidBy: 'alice',
          currency: 'USD',
          expenseDate: now,
          createdAt: now,
          updatedAt: now,
          shareWithEveryone: true,
        ),
      ];

      final shares = [
        const ExpenseShareEntity(
          expenseId: 'e1',
          userId: 'alice',
          shareAmount: 33.33,
        ),
        const ExpenseShareEntity(
          expenseId: 'e1',
          userId: 'bob',
          shareAmount: 33.33,
        ),
        const ExpenseShareEntity(
          expenseId: 'e1',
          userId: 'charlie',
          shareAmount: 33.34,
        ),
      ];

      // Act
      final result = service.calculateNetBalances(members, expenses, shares);

      // Assert
      expect(result['alice'], closeTo(66.67, 0.01));
      expect(result['bob'], closeTo(-33.33, 0.01));
      expect(result['charlie'], closeTo(-33.34, 0.01));
    });

    test('handles member with no expenses', () {
      // Arrange
      final members = [
        GroupMemberEntity(
          userId: 'alice',
          groupId: 'g1',
          joinedAt: DateTime(2025, 1, 1),
        ),
        GroupMemberEntity(
          userId: 'bob',
          groupId: 'g1',
          joinedAt: DateTime(2025, 1, 1),
        ),
        GroupMemberEntity(
          userId: 'charlie',
          groupId: 'g1',
          joinedAt: DateTime(2025, 1, 1),
        ),
      ];

      // Charlie doesn't participate
      final now = DateTime.now();
      final expenses = [
        ExpenseEntity(
          id: 'e1',
          groupId: 'g1',
          title: 'Dinner',
          amount: 100.0,
          paidBy: 'alice',
          currency: 'USD',
          expenseDate: now,
          createdAt: now,
          updatedAt: now,
          shareWithEveryone: false,
        ),
      ];

      final shares = [
        const ExpenseShareEntity(
          expenseId: 'e1',
          userId: 'alice',
          shareAmount: 50.0,
        ),
        const ExpenseShareEntity(
          expenseId: 'e1',
          userId: 'bob',
          shareAmount: 50.0,
        ),
      ];

      // Act
      final result = service.calculateNetBalances(members, expenses, shares);

      // Assert
      expect(result['alice'], 50.0);
      expect(result['bob'], -50.0);
      expect(result['charlie'], 0.0);
    });
  });
}
