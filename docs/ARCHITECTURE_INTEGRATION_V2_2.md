# Architecture Integration: v2.1 + v2.2 Enhancements

**Overview:** How Use Cases and Events integrate with Realtime Sync

---

## Complete Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                    PRESENTATION LAYER                            │
│                                                                   │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │
│  │ Expense      │  │ Group        │  │ Dashboard    │          │
│  │ Notifier     │  │ Notifier     │  │ Provider     │          │
│  │              │  │              │  │ (Event-      │          │
│  │ Issues       │  │ Issues       │  │  Driven)     │          │
│  │ Commands     │  │ Commands     │  │              │          │
│  └──────┬───────┘  └──────┬───────┘  └──────▲───────┘          │
│         │                 │                  │                   │
│         │                 │                  │ Listens           │
│         │                 │                  │ to Events         │
└─────────┼─────────────────┼──────────────────┼───────────────────┘
          │                 │                  │
          │                 │                  │
┌─────────▼─────────────────▼──────────────────┼───────────────────┐
│                    DOMAIN LAYER              │                   │
│                                              │                   │
│  ┌─────────────────────────────────────┐   │                   │
│  │         USE CASES (v2.2 NEW)        │   │                   │
│  │                                      │   │                   │
│  │  • CreateExpenseUseCase             │   │                   │
│  │  • UpdateExpenseUseCase             │   │                   │
│  │  • CreateGroupUseCase               │   │                   │
│  │                                      │   │                   │
│  │  (Validation & Business Logic)      │   │                   │
│  └──────────────┬──────────────────────┘   │                   │
│                 │                            │                   │
│                 │ Calls                      │                   │
│                 ↓                            │                   │
│  ┌─────────────────────────────────────┐   │                   │
│  │      REPOSITORY INTERFACES          │   │                   │
│  │                                      │   │                   │
│  │  • ExpenseRepository                │   │                   │
│  │  • GroupRepository                  │   │                   │
│  └─────────────────────────────────────┘   │                   │
│                                              │                   │
└──────────────────────────────────────────────┼───────────────────┘
                                               │
                        Implemented by         │
                                               │
┌──────────────────────────────────────────────┼───────────────────┐
│                    DATA LAYER                │                   │
│                                              │                   │
│  ┌─────────────────────────────────────┐   │                   │
│  │   SYNCED REPOSITORIES (v2.1)        │   │                   │
│  │                                      │   │                   │
│  │  • SyncedExpenseRepository          │   │                   │
│  │  • SyncedGroupRepository            │   │                   │
│  │                                      │   │                   │
│  │  Responsibilities:                  │   │                   │
│  │  1. Atomic DB + Queue writes        │   │                   │
│  │  2. Fire Events (v2.2 NEW)          │   │                   │
│  └──────────────┬───────────┬──────────┘   │                   │
│                 │           │                │                   │
│                 │           │ Fires          │                   │
│                 │           │ Events         │                   │
│                 │           │                │                   │
│                 │           └────────────────┼───────────────────┤
│                 │                            │                   │
│                 │                   ┌────────▼────────┐          │
│                 │                   │  EVENT BROKER   │          │
│                 │                   │  (v2.2 NEW)     │          │
│                 │                   │                 │          │
│                 │                   │  Broadcasts:    │          │
│                 │                   │  • Local events │          │
│                 │                   │  • Sync events  │          │
│                 │                   └─────────────────┘          │
│                 │                            │                   │
│                 │                            └───────────────────┤
│                 ↓                                                │
│  ┌─────────────────────────────────────┐                        │
│  │      LOCAL DATABASE (DRIFT)         │                        │
│  │                                      │                        │
│  │  DAOs:                               │                        │
│  │  • ExpensesDao                       │                        │
│  │  • GroupsDao                         │                        │
│  │  • SyncDao                           │                        │
│  │                                      │                        │
│  │  Methods:                            │                        │
│  │  • insert() → triggers queue         │                        │
│  │  • upsertFromSync() → fires events   │ ─────────────────────┤
│  └──────────────┬──────────┬────────────┘                        │
│                 │          │                                     │
│                 │          │                                     │
│  ┌──────────────▼──────┐  │                                     │
│  │   SYNC QUEUE        │  │                                     │
│  │   (v2.1)            │  │                                     │
│  │                     │  │                                     │
│  │   Pending           │  │                                     │
│  │   Operations        │  │                                     │
│  └──────────┬──────────┘  │                                     │
│             │              │                                     │
│             │              │ Read                                │
│             ↓              │                                     │
│  ┌─────────────────────┐  │                                     │
│  │  UPLOAD QUEUE       │  │                                     │
│  │  SERVICE (v2.1)     │  │                                     │
│  │                     │  │                                     │
│  │  Processes queue →  │  │                                     │
│  │  Uploads to         │  │                                     │
│  │  Firestore          │  │                                     │
│  └──────────┬──────────┘  │                                     │
│             │              │                                     │
│             ↓              │                                     │
│  ┌─────────────────────┐  │                                     │
│  │  FIRESTORE          │  │                                     │
│  │  SERVICES (v2.1)    │  │                                     │
│  │                     │  │                                     │
│  │  • Upload docs      │  │                                     │
│  │  • Watch snapshots  │  │                                     │
│  └──────────┬──────────┘  │                                     │
│             │              │                                     │
│             ↓              │                                     │
│        ┌────────────┐     │                                     │
│        │ FIRESTORE  │     │                                     │
│        └─────┬──────┘     │                                     │
│              │            │                                     │
│              │ Snapshot   │                                     │
│              │ Events     │                                     │
│              ↓            │                                     │
│  ┌─────────────────────┐ │                                     │
│  │  REALTIME SYNC      │ │                                     │
│  │  SERVICE (v2.1)     │ │                                     │
│  │                     │ │                                     │
│  │  Listens to:        │ │                                     │
│  │  • Group changes    │ │                                     │
│  │  • Expense changes  │ │                                     │
│  │                     │ │                                     │
│  │  On change →        │ │                                     │
│  │  Calls DAO          │ │                                     │
│  │  upsertFromSync()   │─┘                                     │
│  └─────────────────────┘                                       │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Data Flow: Local Change (User Creates Expense)

### Complete Flow with Use Cases and Events

```
┌─────────────────────────────────────────────────────┐
│ STEP 1: User taps "Create Expense" button          │
└─────────────────────┬───────────────────────────────┘
                      │
                      ↓
┌─────────────────────────────────────────────────────┐
│ STEP 2: ExpenseNotifier calls Use Case             │
│                                                      │
│   final useCase = ref.read(                         │
│     createExpenseUseCaseProvider                    │
│   );                                                 │
│   final result = await useCase.call(expense);       │
└─────────────────────┬───────────────────────────────┘
                      │
                      ↓
┌─────────────────────────────────────────────────────┐
│ STEP 3: CreateExpenseUseCase validates             │
│                                                      │
│   if (expense.amount <= 0) {                        │
│     return Failure(ValidationException(...));       │
│   }                                                  │
│   return repository.createExpense(expense);         │
└─────────────────────┬───────────────────────────────┘
                      │
                      ↓
┌─────────────────────────────────────────────────────┐
│ STEP 4: SyncedExpenseRepository atomic write       │
│                                                      │
│   await database.transaction(() async {             │
│     await database.insertExpense(expense);          │
│     await database.enqueueOperation(...);           │
│   });                                                │
└─────────────────────┬───────────────────────────────┘
                      │
                      ↓
┌─────────────────────────────────────────────────────┐
│ STEP 5: Repository fires event (v2.2 NEW)          │
│                                                      │
│   eventBroker.fire(ExpenseCreated(expense));        │
└─────────────────────┬───────────────────────────────┘
                      │
                      ↓
┌─────────────────────────────────────────────────────┐
│ STEP 6: Multiple providers react immediately       │
│                                                      │
│   ✅ Expense list updates (Drift stream)           │
│   ✅ Dashboard total recalculates (Event)          │
│   ✅ Activity feed shows new entry (Event)         │
│   ✅ Sync badge updates (Event)                    │
└─────────────────────┬───────────────────────────────┘
                      │
                      ↓ (Background)
┌─────────────────────────────────────────────────────┐
│ STEP 7: UploadQueueService processes queue         │
│                                                      │
│   Uploads expense to Firestore                      │
└─────────────────────┬───────────────────────────────┘
                      │
                      ↓
┌─────────────────────────────────────────────────────┐
│ STEP 8: Other devices receive snapshot event       │
│                                                      │
│   RealtimeSyncService → upsertFromSync() →          │
│   EventBroker.fire(ExpenseCreated(expense))         │
│                                                      │
│   ✅ Other devices' UIs update via events          │
└─────────────────────────────────────────────────────┘
```

**Timeline:**
- **T0:** User action
- **T1 (2ms):** Use Case validates ✅
- **T2 (5ms):** Repository writes to DB ✅
- **T3 (6ms):** Event fires ✅
- **T4 (10ms):** All listeners react, UI updates ✅ **INSTANT!**
- **T5 (500ms):** Background upload starts
- **T6 (800ms):** Upload completes
- **T7 (900ms):** Other devices receive and update ✅

---

## Data Flow: Remote Change (Sync from Another Device)

```
┌─────────────────────────────────────────────────────┐
│ Device B: User creates expense                      │
│   → Goes through same flow as above                 │
└─────────────────────┬───────────────────────────────┘
                      │
                      ↓
┌─────────────────────────────────────────────────────┐
│ Firestore document created/updated                  │
└─────────────────────┬───────────────────────────────┘
                      │
                      ↓
┌─────────────────────────────────────────────────────┐
│ Device A: Firestore snapshot event fires            │
│                                                      │
│   RealtimeSyncService._expenseListener receives     │
└─────────────────────┬───────────────────────────────┘
                      │
                      ↓
┌─────────────────────────────────────────────────────┐
│ RealtimeSyncService calls DAO                       │
│                                                      │
│   await database.expensesDao.upsertExpenseFromSync( │
│     remoteExpense                                    │
│   );                                                 │
└─────────────────────┬───────────────────────────────┘
                      │
                      ↓
┌─────────────────────────────────────────────────────┐
│ ExpensesDao updates DB and fires event (v2.2 NEW)  │
│                                                      │
│   await into(expenses).insertOnConflictUpdate(...); │
│   eventBroker.fire(ExpenseCreated(expense));        │
└─────────────────────┬───────────────────────────────┘
                      │
                      ↓
┌─────────────────────────────────────────────────────┐
│ Device A: All providers react                       │
│                                                      │
│   ✅ Expense list updates (Drift stream)           │
│   ✅ Dashboard total recalculates (Event)          │
│   ✅ Activity feed shows "New from Device B"       │
│   ✅ UI updates instantly                          │
└─────────────────────────────────────────────────────┘
```

**Key Insight:** Both local and remote changes trigger the same event flow!

---

## Key Interactions

### 1. Use Case → Repository

**Purpose:** Validate and delegate

```dart
// Use Case
Future<Result<ExpenseEntity>> call(ExpenseEntity expense) async {
  // Validation (business logic)
  if (expense.amount <= 0) {
    return Failure(ValidationException('Amount must be positive'));
  }

  // Delegate to repository (data layer)
  return await _repository.createExpense(expense);
}
```

### 2. Repository → Event Broker

**Purpose:** Notify of data changes

```dart
// Repository
Future<Result<ExpenseEntity>> createExpense(ExpenseEntity expense) async {
  await _database.transaction(() async {
    await _database.insertExpense(expense);
    await _database.enqueueOperation(...);
  });

  // Fire event after successful write
  _eventBroker.fire(ExpenseCreated(expense));

  return Success(expense);
}
```

### 3. Event Broker → Providers

**Purpose:** Reactive state updates

```dart
// Event-driven provider
@riverpod
Stream<double> groupTotal(GroupTotalRef ref, String groupId) {
  final eventBroker = ref.watch(eventBrokerProvider);
  final repository = ref.watch(expenseRepositoryProvider);

  // React to expense events for this group
  return eventBroker.stream
    .where((event) {
      if (event is ExpenseCreated) return event.expense.groupId == groupId;
      if (event is ExpenseUpdated) return event.expense.groupId == groupId;
      if (event is ExpenseDeleted) return event.groupId == groupId;
      return false;
    })
    .asyncMap((_) async {
      // Recalculate on relevant event
      final result = await repository.getExpensesByGroup(groupId);
      return result.fold(
        (expenses) => expenses.fold(0.0, (sum, e) => sum + e.amount),
        (_) => 0.0,
      );
    });
}
```

### 4. Realtime Sync → Events

**Purpose:** Unified event source

```dart
// DAO (called by RealtimeSyncService)
Future<void> upsertExpenseFromSync(ExpenseEntity expense) async {
  final existing = await getExpenseById(expense.id);

  if (existing == null || expense.updatedAt.isAfter(existing.updatedAt)) {
    await into(expenses).insertOnConflictUpdate(expenseToDb(expense));

    // Fire event so UI updates
    if (existing == null) {
      _eventBroker.fire(ExpenseCreated(expense));
    } else {
      _eventBroker.fire(ExpenseUpdated(expense, existing));
    }
  }
}
```

---

## Benefits Recap

### 1. Clear Separation of Concerns

- **Use Cases:** Business logic and validation
- **Repositories:** Data operations and coordination
- **Event Broker:** Cross-cutting reactive updates
- **Providers:** UI state management

### 2. Testability

- Use Cases testable with mocked repositories
- Repositories testable with mocked database
- Event-driven providers testable with mocked event broker
- Complete isolation at every layer

### 3. Maintainability

- Business logic lives in one place (Use Cases)
- Data operations centralized (Repositories)
- Event handling unified (Event Broker)
- Easy to find and modify code

### 4. Scalability

- Add new use cases without touching existing code
- Add new event listeners without modifying publishers
- Multiple features can react to same events
- Easy to add cross-cutting concerns

### 5. Reactive State

- UI updates automatically via events
- Multiple screens stay in sync
- No manual refresh logic needed
- Consistent behavior everywhere

---

## Migration Strategy Visual

```
┌──────────────────────────────────────────────────────┐
│ CURRENT STATE (v2.1)                                  │
│                                                        │
│  Provider → Repository → DB + Queue                   │
│                                                        │
│  ✅ Working                                           │
│  ✅ Production-ready                                  │
└──────────────────────────────────────────────────────┘
                      ↓
┌──────────────────────────────────────────────────────┐
│ STEP 1: Add Infrastructure (No behavior change)       │
│                                                        │
│  Add EventBroker ✅                                   │
│  Add Use Cases ✅                                     │
│  (Not used yet)                                       │
│                                                        │
│  Provider → Repository → DB + Queue                   │
└──────────────────────────────────────────────────────┘
                      ↓
┌──────────────────────────────────────────────────────┐
│ STEP 2: Wire Events (Non-breaking)                    │
│                                                        │
│  Provider → Repository → DB + Queue → Fire Event ✅   │
│                          ↓                             │
│                    EventBroker                         │
│                    (No listeners yet)                  │
└──────────────────────────────────────────────────────┘
                      ↓
┌──────────────────────────────────────────────────────┐
│ STEP 3: Migrate Providers (Incremental)               │
│                                                        │
│  Provider → Use Case → Repository → DB + Queue        │
│                                  ↓                     │
│                            EventBroker ✅              │
│                                  ↓                     │
│                         Event-Driven Providers ✅     │
│                                                        │
│  ✅ Full v2.2 Architecture                            │
└──────────────────────────────────────────────────────┘
```

---

## Summary

**Version 2.2 = v2.1 (Realtime Sync) + Use Cases + Events**

- ✅ **Backward Compatible:** Existing code works unchanged
- ✅ **Incremental:** Migrate feature by feature
- ✅ **Low Risk:** Easy rollback at any stage
- ✅ **High Value:** Better code quality, testability, and UX

**Next Steps:**
1. Review this integration plan with team
2. Get approval to start Phase 0
3. Create project tickets
4. Begin implementation

**Questions?** See [IMPLEMENTATION_PLAN_V2_2.md](./IMPLEMENTATION_PLAN_V2_2.md) for detailed breakdown.
