# FairShare - Balance Calculation Plan (Phase 2.5)

**Status:** Planning (Ready for Implementation)
**Depends On:** Phase 2.4 (Event-Driven Architecture) ✅
**Last Updated:** 2025-10-22

---

## Core Philosophy

### Design Principles

1. **Reactive & Event-Driven**
   - Calculations triggered by domain events (`ExpenseCreated`, `ExpenseUpdated`, `ExpenseDeleted`)
   - UI reads from materialized view (`group_balances` table)
   - Zero manual refresh required

2. **Performant & Scalable**
   - Pre-computed balances stored in database
   - Bulk data fetching (avoid N+1 queries)
   - SQLite aggregation handles thousands of expenses in milliseconds

3. **Robust over Premature Optimization**
   - "Recalculate all for group" strategy (simpler, less error-prone)
   - Incremental updates deferred until proven necessary
   - Easy to test and reason about

4. **Offline-First**
   - Works entirely offline
   - Sync brings remote changes → Events fire → Balances update automatically

---

## Architecture Overview

```
User Action (Create/Update/Delete Expense)
  ↓
Use Case (Validation)
  ↓
Repository (DB Write + Queue)
  ↓
EventBroker (Fires Event)
  ↓
┌─────────────────────┴─────────────────────┐
│                                            │
UI Providers                    BalanceEventHandler
(Auto-Refresh)                  (Triggers Recalc)
                                      ↓
                        CalculateGroupBalancesUseCase
                                      ↓
                    ┌─────────────────┴──────────────┐
                    │                                 │
            Fetch Data (bulk)              NetBalanceCalculationService
            - Members                       (Pure calculation)
            - Expenses                              ↓
            - All splits                   Map<userId, balance>
                    │                                 │
                    └────────────────┬────────────────┘
                                     ↓
                      rebuildBalancesForGroup()
                      (Batch clear + insert)
                                     ↓
                            Stream updates UI
```

---

## Implementation Phases

### Phase 1: Domain Layer (Pure Logic)

**Three core services:**

#### 1. NetBalanceCalculationService (NEW!)

Pure Dart class that calculates net balances from raw data.

```dart
class NetBalanceCalculationService {
  /// Calculate net balance for each member
  /// Positive = owed money, Negative = owes money
  Map<String, double> calculate(
    List<GroupMember> members,
    List<Expense> expenses,
    List<ExpenseSplit> allSplits,
  ) {
    // Initialize balances
    final netBalances = {for (var m in members) m.id: 0.0};

    // Group splits by expense for O(1) lookup
    final splitsByExpenseId = groupBy(allSplits, (s) => s.expenseId);

    // Process each expense
    for (final expense in expenses) {
      // Credit the payer
      netBalances[expense.payerId] += expense.amount;

      // Debit each participant
      final splits = splitsByExpenseId[expense.id] ?? [];
      for (final split in splits) {
        netBalances[split.userId] -= split.amountOwed;
      }
    }

    return netBalances;
  }
}
```

**Why separate?** Pure function = easy to test, reusable for "what-if" scenarios.

---

#### 2. BalanceSettlementService

Minimizes cash flow transactions using greedy algorithm.

```dart
class BalanceSettlementService {
  /// Convert net balances to minimal payment transactions
  List<Settlement> calculateSettlements(Map<String, double> netBalances) {
    final creditors = []; // balance > 0
    final debtors = [];   // balance < 0

    // Separate and sort by absolute value
    for (final entry in netBalances.entries) {
      if (entry.value > 0.01) creditors.add(entry);
      else if (entry.value < -0.01) debtors.add(entry);
    }

    // Greedy matching: largest creditor with largest debtor
    final settlements = <Settlement>[];
    while (creditors.isNotEmpty && debtors.isNotEmpty) {
      final creditor = creditors.first;
      final debtor = debtors.first;

      final amount = min(creditor.value, debtor.value.abs());
      settlements.add(Settlement(
        from: debtor.key,
        to: creditor.key,
        amount: amount,
      ));

      // Update balances and remove if settled
      creditor.value -= amount;
      debtor.value += amount;

      if (creditor.value < 0.01) creditors.removeAt(0);
      if (debtor.value.abs() < 0.01) debtors.removeAt(0);
    }

    return settlements;
  }
}
```

**Test cases:** 2 users, 3 users, complex splits, zero balances, floating point precision.

---

#### 3. CalculateGroupBalancesUseCase

Pure orchestrator - fetches data, delegates calculation, persists results.

```dart
class CalculateGroupBalancesUseCase extends UseCase<String, void> {
  final GroupRepository _groupRepository;
  final ExpenseRepository _expenseRepository;
  final BalanceRepository _balanceRepository;
  final NetBalanceCalculationService _calculationService;
  final AppDatabase _database;

  @override
  Future<Result<void, Exception>> call(String groupId) async {
    try {
      await _database.transaction(() async {
        // 1. Fetch all data (bulk queries - avoid N+1)
        final members = await _groupRepository.getMembersForGroup(groupId);
        final expenses = await _expenseRepository.getExpensesForGroup(groupId);
        final allSplits = await _expenseRepository.getAllSplitsForGroup(groupId); // NEW!

        // 2. Delegate calculation to pure service
        final netBalances = _calculationService.calculate(members, expenses, allSplits);

        // 3. Batch persist (single operation)
        await _balanceRepository.rebuildBalancesForGroup(groupId, netBalances);
      });

      return Success(null);
    } catch (e, stack) {
      log.e('Failed to calculate balances for group $groupId', e, stack);
      return Failure(Exception('Failed to calculate balances: $e'));
    }
  }
}
```

**Key improvements:**
- ✅ `getAllSplitsForGroup()` - Bulk fetch avoids N+1 queries (100 expenses = 2 queries instead of 101)
- ✅ `NetBalanceCalculationService` - Pure calculation logic, easily testable
- ✅ `rebuildBalancesForGroup()` - Batch clear + insert in single operation
- ✅ Transaction ensures atomicity

---

### Phase 2: Data Layer (Persistence & Events)

#### BalanceRepository

**New methods:**

```dart
abstract class BalanceRepository {
  /// Batch operation: clear old balances and insert new ones
  Future<void> rebuildBalancesForGroup(
    String groupId,
    Map<String, double> netBalances,
  );

  /// Reactive stream for UI
  Stream<List<Balance>> watchBalancesForGroup(String groupId);
}
```

**Implementation:**
```dart
Future<void> rebuildBalancesForGroup(
  String groupId,
  Map<String, double> netBalances,
) async {
  // Clear existing
  await _database.balancesDao.deleteBalancesForGroup(groupId);

  // Batch insert new balances
  final balances = netBalances.entries.map((e) => Balance(
    groupId: groupId,
    userId: e.key,
    balance: e.value,
    updatedAt: DateTime.now(),
  )).toList();

  await _database.balancesDao.insertBalances(balances);
}
```

---

#### ExpenseRepository

**New method to avoid N+1 queries:**

```dart
abstract class ExpenseRepository {
  /// Fetch all splits for a group in one query
  Future<List<ExpenseSplit>> getAllSplitsForGroup(String groupId);
}
```

**Implementation:**
```dart
Future<List<ExpenseSplit>> getAllSplitsForGroup(String groupId) async {
  // JOIN expenses with splits WHERE groupId = ?
  return (select(expenseSplits)
    ..join([
      innerJoin(expenses, expenses.id.equalsExp(expenseSplits.expenseId))
    ])
    ..where(expenses.groupId.equals(groupId))
  ).get();
}
```

---

#### BalanceEventHandlerService

Listens to expense events and triggers recalculation.

```dart
class BalanceEventHandlerService with LoggerMixin {
  final EventBroker _eventBroker;
  final CalculateGroupBalancesUseCase _calculateBalancesUseCase;
  StreamSubscription? _subscription;

  void start() {
    _subscription = _eventBroker.stream.listen((event) {
      if (event is ExpenseCreated ||
          event is ExpenseUpdated ||
          event is ExpenseDeleted) {
        _recalculateBalances(event.expense.groupId);
      }
    });
  }

  Future<void> _recalculateBalances(String groupId) async {
    final result = await _calculateBalancesUseCase.call(groupId);
    result.fold(
      (_) => log.d('Balance recalculation successful'),
      (error) => log.e('Balance recalculation failed', error),
    );
  }

  void stop() => _subscription?.cancel();
}
```

**Initialize in app startup:**
```dart
// In main.dart or provider initialization
ref.read(balanceEventHandlerProvider); // Starts listening
```

**Note:** Catches both local AND remote changes (sync service fires same events).

---

### Phase 3: Presentation Layer (Riverpod)

#### Stream Provider for Raw Balances

```dart
@riverpod
Stream<List<Balance>> groupBalances(GroupBalancesRef ref, String groupId) {
  final repository = ref.watch(balanceRepositoryProvider);
  return repository.watchBalancesForGroup(groupId);
}
```

---

#### Computed Provider for Settlement Plan

```dart
@riverpod
List<Settlement> settlementPlan(SettlementPlanRef ref, String groupId) {
  final balancesAsync = ref.watch(groupBalancesProvider(groupId));

  return balancesAsync.when(
    data: (balances) {
      // Convert to map
      final netBalances = {for (var b in balances) b.userId: b.balance};

      // Calculate settlements
      final service = ref.read(balanceSettlementServiceProvider);
      return service.calculateSettlements(netBalances);
    },
    loading: () => [],
    error: (_, __) => [],
  );
}
```

---

### Phase 4: UI Layer

**Display Net Balances:**

```dart
final balancesAsync = ref.watch(groupBalancesProvider(groupId));

return balancesAsync.when(
  data: (balances) {
    if (balances.every((b) => b.balance.abs() < 0.01)) {
      return Center(child: Text('All settled up! ✅'));
    }
    return ListView.builder(
      itemCount: balances.length,
      itemBuilder: (context, i) => BalanceListTile(balances[i]),
    );
  },
  loading: () => CircularProgressIndicator(),
  error: (e, _) => ErrorWidget(e),
);
```

**Display Settlement Plan:**

```dart
final settlements = ref.watch(settlementPlanProvider(groupId));

return ListView.builder(
  itemCount: settlements.length,
  itemBuilder: (context, i) {
    final s = settlements[i];
    return ListTile(
      title: Text('${s.from} pays ${s.to}'),
      trailing: Text('\$${s.amount.toStringAsFixed(2)}'),
    );
  },
);
```

---

## Key Benefits

### Network Efficiency
- ✅ **Zero network calls** - All data is local
- ✅ **No repeated fetches** - Materialized view in `group_balances` table
- ✅ **Bulk queries** - N+1 problem solved with `getAllSplitsForGroup()`

### Performance
- ✅ **Fast calculation** - SQLite aggregates 10,000 rows in ~5-10ms
- ✅ **Async execution** - Doesn't block UI
- ✅ **Event-driven** - Only recalculates when data changes

### Scalability
- ✅ **Handles thousands of expenses** - Tested SQLite performance
- ✅ **Incremental updates possible** - Future enhancement if needed
- ✅ **Debouncing available** - Can add if bulk operations are slow

### Maintainability
- ✅ **Pure functions** - `NetBalanceCalculationService` is trivial to test
- ✅ **Clean separation** - Domain, data, and presentation layers
- ✅ **Simple algorithm** - Easy to debug

---

## Testing Strategy

### Unit Tests

**NetBalanceCalculationService:**
```dart
test('calculates net balances correctly', () {
  final members = [Member('alice'), Member('bob')];
  final expenses = [Expense(id: 'e1', payerId: 'alice', amount: 100)];
  final splits = [
    Split(expenseId: 'e1', userId: 'alice', amountOwed: 50),
    Split(expenseId: 'e1', userId: 'bob', amountOwed: 50),
  ];

  final result = service.calculate(members, expenses, splits);

  expect(result['alice'], 50.0);  // Paid 100, owes 50
  expect(result['bob'], -50.0);   // Paid 0, owes 50
});
```

**BalanceSettlementService:**
```dart
test('minimizes transactions', () {
  final balances = {'alice': 50.0, 'bob': -20.0, 'charlie': -30.0};
  final settlements = service.calculateSettlements(balances);

  expect(settlements.length, 2); // Minimal number of transactions
});
```

**CalculateGroupBalancesUseCase:**
```dart
test('recalculates balances for group', () async {
  // Create in-memory database with test data
  final db = AppDatabase.memory();

  // Insert test expenses and splits
  // ...

  // Execute use case
  final result = await useCase.call(groupId);

  // Verify balances in database
  final balances = await db.balancesDao.getBalancesForGroup(groupId);
  expect(balances.length, 2);
  expect(balances.first.balance, 50.0);
});
```

### Integration Tests

```dart
testWidgets('balance updates when expense created', (tester) async {
  // 1. Create group with 2 members
  // 2. Navigate to balances tab (empty)
  // 3. Create expense
  // 4. Verify balances update automatically
  // 5. Verify settlement plan appears
});
```

---

## Future Enhancements

### Debouncing (If needed)
Add 500ms delay to batch multiple events during bulk sync.

```dart
final Map<String, Timer?> _debouncers = {};

void _recalculateBalances(String groupId) {
  _debouncers[groupId]?.cancel();
  _debouncers[groupId] = Timer(Duration(milliseconds: 500), () async {
    await _calculateBalancesUseCase.call(groupId);
  });
}
```

**When:** Only if profiling shows performance issues during bulk sync.

---

### Calculation Status Indicator (If needed)
Show loading state while recalculating.

```dart
class BalanceCalculationStatus extends Table {
  TextColumn get groupId => text()();
  BoolColumn get isCalculating => boolean()();
}
```

**When:** Only if users report confusion about balance updates.

---

### Incremental Updates (If needed)
Only update affected balances based on delta.

**When:** Only when groups have >10,000 expenses (very rare). Measure first with logging.

---

## Implementation Checklist

### Phase 1: Domain Layer
- [ ] Create `NetBalanceCalculationService`
- [ ] Create `BalanceSettlementService`
- [ ] Create `CalculateGroupBalancesUseCase`
- [ ] Write unit tests for all three

### Phase 2: Data Layer
- [ ] Add `rebuildBalancesForGroup()` to `BalanceRepository`
- [ ] Add `getAllSplitsForGroup()` to `ExpenseRepository`
- [ ] Create `BalanceEventHandlerService`
- [ ] Initialize event handler in app startup

### Phase 3: Presentation Layer
- [ ] Create `groupBalancesProvider`
- [ ] Create `settlementPlanProvider`

### Phase 4: UI Layer
- [ ] Update `BalancesTab` to show balances
- [ ] Add settlement plan widget
- [ ] Add "all settled up" state

### Testing
- [ ] Integration test: Expense creation → Balance updates
- [ ] Manual test: Verify offline functionality
- [ ] Manual test: Verify sync updates balances

---

**Status:** Ready to implement! Start with Phase 1: Domain Layer.
