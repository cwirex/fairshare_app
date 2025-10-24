import 'dart:math' as math;

import 'package:collection/collection.dart' show PriorityQueue;
import 'package:fairshare_app/core/logging/app_logger.dart';
import 'package:fairshare_app/features/balances/domain/entities/settlement_entity.dart';
import 'package:fairshare_app/features/expenses/domain/entities/expense_entity.dart';
import 'package:fairshare_app/features/expenses/domain/entities/expense_share_entity.dart';
import 'package:fairshare_app/features/groups/domain/entities/group_member_entity.dart';

/// Service for balance calculations and settlements
class BalanceCalculationService with LoggerMixin {
  /// Smallest difference to consider as zero
  static const epsilon = 0.01;

  /// Calculate net balance for each member.
  /// Positive = owed money (creditor), Negative = owes money (debtor)
  Map<String, double> calculateNetBalances(
    List<GroupMemberEntity> members,
    List<ExpenseEntity> expenses,
    List<ExpenseShareEntity> shares,
  ) {
    // Initialize net balances with 0 for each member
    final netBalances = {for (var m in members) m.userId: 0.0};

    // Account for expenses - Credit the PAYER
    for (var e in expenses) {
      netBalances[e.paidBy] = (netBalances[e.paidBy] ?? 0.0) + e.amount;
    }

    // Acount for shares - Debit each PARTICIPANT
    for (var s in shares) {
      netBalances[s.userId] = (netBalances[s.userId] ?? 0.0) - s.shareAmount;
    }

    log.d(
      'Calculated net balances for group ${members.first.groupId}: ${netBalances.entries}',
    );

    // TODO: Later consider of what happens when the members do not match expenses and shares, e.g. user was deleted
    return netBalances;
  }

  /// Calculate settlements to minimize transactions
  List<SettlementEntity> calculateSettlements(Map<String, double> balances) {
    // Define as Priority Queue to minimize cash flow
    final creditors = PriorityQueue<MapEntry<String, double>>(
      (a, b) => b.value.compareTo(a.value), // largest first
    );
    final debtors = PriorityQueue<MapEntry<String, double>>(
      (a, b) => b.value.compareTo(a.value),
    );

    // Fill in creditors and debtors
    for (var balance in balances.entries) {
      final value = balance.value;
      if (value.abs() < epsilon) continue;

      if (value > 0) {
        creditors.add(balance);
      } else {
        // store as positive amount for easier comparison
        debtors.add(MapEntry(balance.key, -value));
      }
    }

    log.d('Creditors: ${creditors.toList()}, Debtors: ${debtors.toList()}');

    // log.d(
    //   'Calculating settlements: '
    //   'Creditors=${creditors.length}, Debtors=${debtors.length}',
    // );

    final settlements = <SettlementEntity>[];

    // Process all balances untill there are participants remaining
    while (creditors.isNotEmpty && debtors.isNotEmpty) {
      final creditor = creditors.removeFirst();
      final debtor = debtors.removeFirst();
      final transferAmount = math.min(creditor.value, debtor.value);

      // Add the transaction to final result
      settlements.add(
        SettlementEntity(
          from: debtor.key,
          to: creditor.key,
          amount: transferAmount,
        ),
      );

      // If debtor still have debt remaining, put back in the queue
      if (debtor.value - transferAmount >= epsilon) {
        debtors.add(MapEntry(debtor.key, debtor.value - transferAmount));
      }
      // If creditor still have debt remaining, put back in the queue
      if (creditor.value - transferAmount >= epsilon) {
        creditors.add(MapEntry(creditor.key, creditor.value - transferAmount));
      }
    }

    log.d('Calculated settlements: ${settlements.length} transactions');

    return settlements;
  }
}
