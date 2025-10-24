import 'package:fairshare_app/features/balances/domain/entities/settlement_entity.dart';
import 'package:fairshare_app/features/balances/domain/services/balance_calculation_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late BalanceCalculationService service;

  setUp(() {
    service = BalanceCalculationService();
  });

  group('BalanceSettlementService', () {
    test('returns empty list when all balances are zero', () {
      // Arrange
      final balances = {'alice': 0.0, 'bob': 0.0};

      // Act
      final result = service.calculateSettlements(balances);

      // Assert
      expect(result, isEmpty);
    });

    test('handles simple two-person settlement', () {
      // Arrange
      final balances = {'alice': 50.0, 'bob': -50.0};

      // Act
      final result = service.calculateSettlements(balances);

      // Assert
      expect(result.length, 1);
      expect(result[0].from, 'bob');
      expect(result[0].to, 'alice');
      expect(result[0].amount, 50.0);
    });

    test('minimizes transactions for three people', () {
      // Arrange
      final balances = {
        'alice': 50.0, // Owed
        'bob': -20.0, // Owes
        'charlie': -30.0, // Owes
      };

      // Act
      final result = service.calculateSettlements(balances);

      // Assert
      expect(result.length, 2); // Should be 2 transactions, not 3

      // Verify total amounts match
      final totalPaid = result.fold(0.0, (sum, s) => sum + s.amount);
      expect(totalPaid, 50.0);

      // Verify settlements are to alice
      expect(result.every((s) => s.to == 'alice'), isTrue);
    });

    test('handles complex scenario with multiple creditors and debtors', () {
      // Arrange
      final balances = {
        'alice': 100.0, // Creditor
        'bob': 50.0, // Creditor
        'charlie': -80.0, // Debtor
        'dave': -70.0, // Debtor
      };

      // Act
      final result = service.calculateSettlements(balances);

      // Assert
      // Should produce 3 transactions (optimal)
      expect(result.length, 3);

      // Verify total amounts balance
      final totalPaid = result.fold(0.0, (sum, s) => sum + s.amount);
      expect(totalPaid, closeTo(150.0, 0.01));

      // Verify all transactions are from debtors to creditors
      for (final settlement in result) {
        expect(['charlie', 'dave'].contains(settlement.from), isTrue);
        expect(['alice', 'bob'].contains(settlement.to), isTrue);
      }
    });

    test('handles single creditor, multiple debtors', () {
      // Arrange
      final balances = {
        'alice': 150.0,
        'bob': -50.0,
        'charlie': -50.0,
        'dave': -50.0,
      };

      // Act
      final result = service.calculateSettlements(balances);

      // Assert
      expect(result.length, 3); // 3 people pay alice

      // All settlements go to alice
      expect(result.every((s) => s.to == 'alice'), isTrue);

      // Total equals alice's credit
      final totalPaid = result.fold(0.0, (sum, s) => sum + s.amount);
      expect(totalPaid, 150.0);
    });

    test('handles single debtor, multiple creditors', () {
      // Arrange
      final balances = {
        'alice': 50.0,
        'bob': 50.0,
        'charlie': 50.0,
        'dave': -150.0,
      };

      // Act
      final result = service.calculateSettlements(balances);

      // Assert
      expect(result.length, 3); // Dave pays 3 people

      // All settlements from dave
      expect(result.every((s) => s.from == 'dave'), isTrue);

      // Total equals dave's debt
      final totalPaid = result.fold(0.0, (sum, s) => sum + s.amount);
      expect(totalPaid, 150.0);
    });

    test('handles floating point precision', () {
      // Arrange
      final balances = {'alice': 33.33, 'bob': -16.67, 'charlie': -16.66};

      // Act
      final result = service.calculateSettlements(balances);

      // Assert
      expect(result.isNotEmpty, isTrue);

      // Total should roughly balance
      final totalPaid = result.fold(0.0, (sum, s) => sum + s.amount);
      expect(totalPaid, closeTo(33.33, 0.01));
    });

    test('ignores very small balances (rounding tolerance)', () {
      // Arrange
      final balances = {
        'alice': 50.0,
        'bob': -50.0,
        'charlie': 0.001, // Should be ignored
      };

      // Act
      final result = service.calculateSettlements(balances);

      // Assert
      expect(result.length, 1); // Only alice-bob settlement
    });

    test('produces deterministic results', () {
      // Arrange
      final balances = {'alice': 100.0, 'bob': -50.0, 'charlie': -50.0};

      // Act
      final result1 = service.calculateSettlements(balances);
      final result2 = service.calculateSettlements(balances);

      // Assert - should produce same result every time
      expect(result1.length, result2.length);
      for (int i = 0; i < result1.length; i++) {
        expect(result1[i].from, result2[i].from);
        expect(result1[i].to, result2[i].to);
        expect(result1[i].amount, result2[i].amount);
      }
    });

    test('handles 3-v-3 scenario with partial settlements', () {
      // Arrange
      final balances = {
        'alice': 100.0, // Large Creditor
        'bob': 60.0, // Medium Creditor
        'chris': 10.0, // Small Creditor
        'dave': -80.0, // Large Debtor
        'eve': -70.0, // Medium Debtor
        'frank': -20.0, // Small Debtor
      }; // Total Credit: 170.0, Total Debit: -170.0

      // Act
      final result = service.calculateSettlements(balances);

      // Assert
      // 1. Check for the optimal number of transactions
      expect(result.length, 4);

      // 2. Check total amount transferred
      final totalPaid = result.fold(0.0, (sum, s) => sum + s.amount);
      expect(totalPaid, closeTo(170.0, 0.01));

      // 3. Check each specific transaction
      final tx1 = findSettlement(result, from: 'dave', to: 'alice');
      expect(tx1.amount, closeTo(80.0, 0.01));

      final tx2 = findSettlement(result, from: 'eve', to: 'bob');
      expect(tx2.amount, closeTo(60.0, 0.01));

      final tx3 = findSettlement(result, from: 'frank', to: 'alice');
      expect(tx3.amount, closeTo(20.0, 0.01));

      final tx4 = findSettlement(result, from: 'eve', to: 'chris');
      expect(tx4.amount, closeTo(10.0, 0.01));
    });

    test('handles all positive balances (everyone is owed)', () {
      // Arrange
      final balances = {'alice': 50.0, 'bob': 30.0};

      // Act
      final result = service.calculateSettlements(balances);

      // Assert
      expect(result, isEmpty); // No one owes money
    });

    test('handles all negative balances (everyone owes)', () {
      // Arrange
      final balances = {'alice': -50.0, 'bob': -30.0};

      // Act
      final result = service.calculateSettlements(balances);

      // Assert
      expect(result, isEmpty); // No one is owed money
    });

    test('handles large number of people', () {
      // Arrange
      final balances = {
        'alice': 100.0,
        'bob': 50.0,
        'charlie': -30.0,
        'dave': -40.0,
        'eve': -50.0,
        'frank': -30.0,
      };

      // Act
      final result = service.calculateSettlements(balances);

      // Assert
      // Should minimize transactions (not necessarily N-1, but close)
      expect(result.length, lessThan(6)); // Less than naive approach

      // Verify total balances out
      final totalPaid = result.fold(0.0, (sum, s) => sum + s.amount);
      expect(totalPaid, closeTo(150.0, 0.01));

      // Verify all transactions are valid
      for (final settlement in result) {
        expect(settlement.amount, greaterThan(0));
        expect(balances[settlement.from], lessThan(0)); // Debtor
        expect(balances[settlement.to], greaterThan(0)); // Creditor
      }
    });
  });
}

/// Helper function to find a specific settlement in a list
SettlementEntity findSettlement(
  List<SettlementEntity> settlements, {
  required String from,
  required String to,
}) {
  return settlements.firstWhere(
    (s) => s.from == from && s.to == to,
    orElse: () => SettlementEntity(from: 'not', to: 'found', amount: -1),
  );
}
