import 'package:fairshare_app/core/database/database_provider.dart';
import 'package:fairshare_app/core/events/app_event.dart';
import 'package:fairshare_app/core/events/event_providers.dart';
import 'package:fairshare_app/core/events/expense_events.dart';
import 'package:fairshare_app/core/logging/app_logger.dart';
import 'package:fairshare_app/features/balances/domain/entities/settlement_entity.dart';
import 'package:fairshare_app/features/balances/domain/services/balance_calculation_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'balance_providers.g.dart';

/// Provider for BalanceCalculationService singleton
@riverpod
BalanceCalculationService balanceCalculationService(Ref ref) {
  return BalanceCalculationService();
}

/// Event-driven provider for group net balances.
///
/// Returns a map of userId -> net balance (positive = owed, negative = owes).
/// Automatically recalculates when expenses or shares change for the group.
@riverpod
class GroupBalance extends _$GroupBalance with LoggerMixin {
  @override
  Stream<Map<String, double>> build(String groupId) async* {
    log.d('Initializing GroupBalance for group: $groupId');

    // Calculate initial balances
    final balances = await _calculateBalances(groupId);
    yield balances;

    // Listen to events and recalculate when relevant changes occur
    final eventBroker = ref.watch(eventBrokerProvider);

    await for (final event in eventBroker.stream) {
      if (_shouldRecalculate(event, groupId)) {
        log.d(
          'Recalculating balances for group $groupId due to event: ${event.runtimeType}',
        );
        final updatedBalances = await _calculateBalances(groupId);
        yield updatedBalances;
      }
    }
  }

  /// Calculate balances for a group
  Future<Map<String, double>> _calculateBalances(String groupId) async {
    final database = ref.read(appDatabaseProvider);
    final service = ref.read(balanceCalculationServiceProvider);

    // Fetch all required data
    final members = await database.groupsDao.getAllGroupMembers(groupId);
    final expenses = await database.expensesDao.getExpensesByGroup(groupId);
    final shares = await database.expenseSharesDao.getSharesByGroup(groupId);

    // Calculate net balances
    final balances = service.calculateNetBalances(members, expenses, shares);

    log.i('Calculated balances for group $groupId: ${balances.length} members');
    return balances;
  }

  /// Determine if we should recalculate based on the event
  bool _shouldRecalculate(AppEvent event, String groupId) {
    // Recalculate on any expense event for this group
    if (event is ExpenseCreated) {
      return event.expense.groupId == groupId;
    }
    if (event is ExpenseUpdated) {
      return event.expense.groupId == groupId;
    }
    if (event is ExpenseDeleted) {
      return event.groupId == groupId;
    }

    // Recalculate on expense share events
    // Note: ExpenseShareAdded/Updated don't have groupId directly,
    // so we recalculate for all groups when shares change
    // This is conservative but ensures accuracy
    if (event is ExpenseShareAdded || event is ExpenseShareUpdated) {
      // We'd need to query the expense to get the groupId, so for now
      // we recalculate (shares don't change frequently)
      return true;
    }

    // TODO: Add MemberEvent handling when member events are implemented
    // if (event is MemberAddedToGroup || event is MemberRemovedFromGroup) {
    //   return event.groupId == groupId;
    // }

    return false;
  }
}

/// Event-driven provider for optimal settlement calculations.
///
/// Returns a list of settlements to minimize transactions.
/// Automatically updates when balances change.
@riverpod
class GroupSettlements extends _$GroupSettlements with LoggerMixin {
  @override
  Stream<List<SettlementEntity>> build(String groupId) async* {
    log.d('Initializing GroupSettlements for group: $groupId');

    // Calculate initial settlements from balances
    final balances = await ref.watch(groupBalanceProvider(groupId).future);
    final service = ref.read(balanceCalculationServiceProvider);
    yield service.calculateSettlements(balances);

    // Listen to events and recalculate when balances would change
    final eventBroker = ref.watch(eventBrokerProvider);

    await for (final event in eventBroker.stream) {
      // Use the same logic as GroupBalance to determine if we should recalculate
      if (_shouldRecalculate(event, groupId)) {
        log.d(
          'Recalculating settlements for group $groupId due to event: ${event.runtimeType}',
        );
        final updatedBalances =
            await ref.read(groupBalanceProvider(groupId).future);
        final settlements = service.calculateSettlements(updatedBalances);
        log.i(
          'Calculated ${settlements.length} settlements for group $groupId',
        );
        yield settlements;
      }
    }
  }

  /// Same logic as GroupBalance for consistency
  bool _shouldRecalculate(AppEvent event, String groupId) {
    if (event is ExpenseCreated) {
      return event.expense.groupId == groupId;
    }
    if (event is ExpenseUpdated) {
      return event.expense.groupId == groupId;
    }
    if (event is ExpenseDeleted) {
      return event.groupId == groupId;
    }
    if (event is ExpenseShareAdded || event is ExpenseShareUpdated) {
      return true;
    }
    return false;
  }
}

/// Provider for checking if a group is settled (all balances are zero).
///
/// Returns true if all members have net balance of approximately zero.
@riverpod
class GroupIsSettled extends _$GroupIsSettled with LoggerMixin {
  static const double epsilon = 0.01; // Same as BalanceCalculationService

  @override
  Stream<bool> build(String groupId) async* {
    log.d('Initializing GroupIsSettled for group: $groupId');

    // Check initial state
    final balances = await ref.watch(groupBalanceProvider(groupId).future);
    yield _isSettled(balances);

    // Listen to events (same as GroupBalance)
    final eventBroker = ref.watch(eventBrokerProvider);

    await for (final event in eventBroker.stream) {
      if (_shouldRecalculate(event, groupId)) {
        log.d(
          'Rechecking settled status for group $groupId due to event: ${event.runtimeType}',
        );
        final updatedBalances =
            await ref.read(groupBalanceProvider(groupId).future);
        final settled = _isSettled(updatedBalances);
        log.d('Group $groupId settled status: $settled');
        yield settled;
      }
    }
  }

  /// Check if all balances are effectively zero
  bool _isSettled(Map<String, double> balances) {
    return balances.values.every((balance) => balance.abs() < epsilon);
  }

  /// Same logic as GroupBalance for consistency
  bool _shouldRecalculate(AppEvent event, String groupId) {
    if (event is ExpenseCreated) {
      return event.expense.groupId == groupId;
    }
    if (event is ExpenseUpdated) {
      return event.expense.groupId == groupId;
    }
    if (event is ExpenseDeleted) {
      return event.groupId == groupId;
    }
    if (event is ExpenseShareAdded || event is ExpenseShareUpdated) {
      return true;
    }
    return false;
  }
}
