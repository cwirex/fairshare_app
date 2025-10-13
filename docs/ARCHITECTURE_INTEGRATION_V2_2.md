# Architecture Integration: v2.1 + v2.2 Enhancements

**Overview:** How Use Cases and Events integrate with Realtime Sync

---

## Complete Architecture Diagram (✅ IMPLEMENTED v2.2)

```
┌─────────────────────────────────────────────────────────────────┐
│                    PRESENTATION LAYER                            │
│                                                                   │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │
│  │ UI Screens   │  │ Stream       │  │ Dashboard    │          │
│  │              │  │ Providers    │  │ Provider     │          │
│  │ Calls Use    │  │              │  │ (Event-      │          │
│  │ Cases        │  │ Watch Repos  │  │  Driven)     │          │
│  │ Directly     │  │ Streams      │  │              │          │
│  └──────┬───────┘  └──────────────┘  └──────▲───────┘          │
│         │                                    │                   │
│         │ ref.read(                          │ Listens           │
│         │   createExpenseUseCaseProvider     │ to Events         │
│         │ )                                  │                   │
│         │                                    │                   │
│  ┌──────┴────────────────────────────┐      │                   │
│  │  USE CASE PROVIDERS               │      │                   │
│  │  (presentation/providers/)        │      │                   │
│  │                                    │      │                   │
│  │  • expense_use_case_providers.dart│      │                   │
│  │  • group_use_case_providers.dart  │      │                   │
│  └──────┬────────────────────────────┘      │                   │
└─────────┼─────────────────────────────────────┼──────────────────┘
          │                                    │
          │ Provides Use Case Instances        │
          ↓                                    │
┌─────────────────────────────────────────────┼───────────────────┐
│                    DOMAIN LAYER             │                   │
│                                             │                   │
│  ┌─────────────────────────────────────┐  │                   │
│  │    USE CASES (✅ IMPLEMENTED)       │  │                   │
│  │                                      │  │                   │
│  │  COMMANDS (Write):                  │  │                   │
│  │  • CreateExpenseUseCase ✅          │  │                   │
│  │  • UpdateExpenseUseCase ✅          │  │                   │
│  │  • DeleteExpenseUseCase ✅          │  │                   │
│  │  • CreateGroupUseCase ✅            │  │                   │
│  │  • UpdateGroupUseCase ✅            │  │                   │
│  │  • DeleteGroupUseCase ✅            │  │                   │
│  │  • AddMemberUseCase ✅              │  │                   │
│  │  • RemoveMemberUseCase ✅           │  │                   │
│  │                                      │  │                   │
│  │  QUERIES (Read):                    │  │                   │
│  │  • GetExpenseUseCase ✅             │  │                   │
│  │  • GetExpensesByGroupUseCase ✅     │  │                   │
│  │                                      │  │                   │
│  │  (Validation & Business Logic)      │  │                   │
│  │  Returns: Result<T>                 │  │                   │
│  └──────────────┬──────────────────────┘  │                   │
│                 │                           │                   │
│                 │ Calls                     │                   │
│                 ↓                           │                   │
│  ┌─────────────────────────────────────┐  │                   │
│  │      REPOSITORY INTERFACES          │  │                   │
│  │                                      │  │                   │
│  │  • ExpenseRepository                │  │                   │
│  │    (throws exceptions) ✅           │  │                   │
│  │  • GroupRepository                  │  │                   │
│  │    (returns Result<T>) ⚠️           │  │                   │
│  └─────────────────────────────────────┘  │                   │
│                                             │                   │
└─────────────────────────────────────────────┼───────────────────┘
                                              │
                        Implemented by        │
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

## Data Flow: Local Change (User Creates Expense) ✅ IMPLEMENTED

### Complete Flow with Use Cases (No Notifier!)

```
┌─────────────────────────────────────────────────────┐
│ STEP 1: User taps "Save" button in UI              │
└─────────────────────┬───────────────────────────────┘
                      │
                      ↓
┌─────────────────────────────────────────────────────┐
│ STEP 2: UI builds ExpenseEntity and calls Use Case │
│                                                      │
│   final expense = ExpenseEntity(...);               │
│   final useCase = ref.read(                         │
│     createExpenseUseCaseProvider                    │
│   );                                                 │
│   final result = await useCase(expense);            │
└─────────────────────┬───────────────────────────────┘
                      │
                      ↓
┌─────────────────────────────────────────────────────┐
│ STEP 3: CreateExpenseUseCase validates             │
│                                                      │
│   void validate(ExpenseEntity input) {              │
│     if (input.amount <= 0) {                        │
│       throw Exception('Amount must be > 0');        │
│     }                                                │
│     if (input.title.trim().isEmpty) {               │
│       throw Exception('Title is required');         │
│     }                                                │
│   }                                                  │
│                                                      │
│   Future<ExpenseEntity> execute(input) async {      │
│     return await _repository.createExpense(input);  │
│   }                                                  │
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

---

## ✅ ACTUAL IMPLEMENTATION STATUS (2025-10-13)

### Phase 2.1: Use Case Layer - COMPLETED

**Use Cases Created:**

**Expenses (5 use cases):**
- ✅ `CreateExpenseUseCase` - validates amount > 0, title not empty
- ✅ `UpdateExpenseUseCase` - validates ID, amount, title
- ✅ `DeleteExpenseUseCase` - validates ID, returns `Unit`
- ✅ `GetExpenseUseCase` - one-time fetch by ID
- ✅ `GetExpensesByGroupUseCase` - one-time fetch by group

**Groups (5 use cases):**
- ✅ `CreateGroupUseCase` - validates name length (2-100 chars)
- ✅ `UpdateGroupUseCase` - validates ID and name
- ✅ `DeleteGroupUseCase` - validates ID, returns `Unit`
- ✅ `AddMemberUseCase` - validates groupId and userId
- ✅ `RemoveMemberUseCase` - validates groupId and userId (with params class)

**Base Architecture:**
- ✅ `UseCase<Input, Output extends Object>` base class
- ✅ `validate(Input)` method for business rules
- ✅ `execute(Input)` method for repository calls
- ✅ `call(Input)` returns `Result<Output>`

**Riverpod Providers:**
- ✅ `expense_use_case_providers.dart` (moved to `presentation/providers/`)
- ✅ `group_use_case_providers.dart` (moved to `presentation/providers/`)

**Presentation Layer Cleanup:**
- ✅ **Removed `ExpenseNotifier`** completely
- ✅ UI calls use cases directly via `ref.read(createExpenseUseCaseProvider)`
- ✅ UI handles `Result<T>` with `.fold()` for success/error
- ✅ Stream providers remain for reactive queries (`allExpenses`, `expensesByGroup`)

**Key Architecture Decisions:**

1. **No Command Notifiers** - UI calls use cases directly
   ```dart
   // UI code
   final useCase = ref.read(createExpenseUseCaseProvider);
   final result = await useCase(expense);
   result.fold(
     (success) => showSuccess(),
     (error) => showError(),
   );
   ```

2. **Stream Providers for Queries** - Reactive data stays simple
   ```dart
   @riverpod
   Stream<List<ExpenseEntity>> expensesByGroup(Ref ref, String groupId) {
     return ref.watch(expenseRepositoryProvider).watchExpensesByGroup(groupId);
   }
   ```

3. **Use Cases for Commands** - Business logic centralized
   - Validation in `validate()`
   - Repository call in `execute()`
   - Result wrapping in `call()`

4. **Provider Location** - Moved to presentation layer
   - Use case providers are Riverpod infrastructure
   - Belong in `presentation/providers/`, not `domain/use_cases/`

**Files Modified:**
- `lib/core/domain/use_case.dart` - Updated generics to `Output extends Object`
- `lib/features/expenses/domain/use_cases/delete_expense_use_case.dart` - Fixed to return `Unit`
- `lib/features/expenses/presentation/providers/expense_providers.dart` - Removed ExpenseNotifier
- `lib/features/expenses/presentation/screens/create_expense_screen.dart` - Uses use cases directly

### Phase 2.2: Event-Driven Architecture - TODO

**Remaining Tasks:**
1. ⏳ Update `GroupRepository` interface to throw exceptions (match ExpenseRepository)
2. ⏳ Inject `EventBroker` into `SyncedExpenseRepository`
3. ⏳ Inject `EventBroker` into `SyncedGroupRepository`
4. ⏳ Update `ExpensesDao.upsertFromSync()` to fire events
5. ⏳ Update `GroupsDao.upsertFromSync()` to fire events
6. ⏳ Write unit tests for all use cases (>90% coverage)

**Next Steps:**
1. Update repository interfaces for consistency
2. Integrate EventBroker into repositories
3. Update DAOs to fire events on sync operations
4. Write comprehensive unit tests

**Questions?** See [IMPLEMENTATION_PLAN_V2_2.md](./IMPLEMENTATION_PLAN_V2_2.md) for detailed breakdown.
