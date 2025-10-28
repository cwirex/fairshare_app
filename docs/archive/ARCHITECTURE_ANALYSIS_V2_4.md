# Architecture Analysis: Dependency Inversion Refactor (v2.4)

**Status:** ✅ COMPLETED
**Date:** October 2025
**Context:** Phase 2.5 - Architectural Refactoring
**Problem:** Concrete dependencies blocking testability
**Solution:** Interface abstraction across data access, business logic, sync services, and event system
**Result:** Isolated unit tests for core business logic + 302 tests passing

> This refactoring is now complete. All 24 interfaces have been implemented, tested (44 DAO tests, 13 use case test files), and entity serialization is covered. See [PLAN.md](../current/PLAN.md) for current Phase 3 progress.

---

## Table of Contents

1. [Problem Statement](#problem-statement)
2. [Analysis & Approach](#analysis--approach)
3. [Implementation Details](#implementation-details)
4. [Testing Impact](#testing-impact)
5. [Technical Decisions](#technical-decisions)
6. [References](#references)

---

## Problem Statement

### Initial State (v2.4)

The application was functional but had architectural issues that made it difficult to test:

**The Core Issue:**
- Business logic (use cases, repositories) depended on concrete implementations
- UI layer (Riverpod providers) depended on concrete use cases
- Data layer (repositories) depended on concrete DAOs
- EventBroker was a singleton, making it difficult to reset between tests

**Testing Problems:**
```dart
// Repository test - required full database
test('createExpense', () async {
  final database = AppDatabase();  // ❌ Full Drift database required
  final repository = SyncedExpenseRepository(database: database);
  // Can't isolate repository logic from database
});

// UI test - coupled to concrete implementations
final container = ProviderContainer(
  overrides: [
    createExpenseUseCaseProvider.overrideWithValue(
      CreateExpenseUseCase(mockRepo), // ❌ Concrete class, can't swap
    ),
  ],
);
```

**Identified Gaps:**
- DAOs (data access) without interfaces → blocking repository tests
- Use Cases (business logic) without interfaces → blocking UI tests
- Sync Services (Firestore coordination) without interfaces → blocking sync tests
- EventBroker as singleton → hard to mock/reset in tests

For the original analysis, see [dependency-inversion-analysis.md](../current/dependency-inversion-analysis.md).

---

## Analysis & Approach

### Decision: Interface Per Component

**Option A (Chosen):** Individual interfaces per component
- `ICreateExpenseUseCase`, `IUpdateExpenseUseCase`, etc.
- More files, but semantically clear
- Better IDE support and navigation

**Option B (Rejected):** Generic interfaces
- `IUseCase<Input, Output>`
- Fewer files, but loss of semantic meaning
- Harder to understand intent

**Rationale:** Chose A for clarity and maintainability. In a codebase with 11 use cases, having 11 clear interface names is more valuable than saving a few files.

### Phases

**Phase 1: DAOs & Sync Services**
- Abstract data access layer
- Enable repository testing without database

**Phase 2: Use Cases**
- Abstract business logic
- Enable UI testing without repositories

**Phase 3: EventBroker**
- Remove singleton pattern
- Make event system lifecycle-managed

---

## Implementation Details

### Phase 1: DAO Interfaces (5 interfaces)

**Location:** [`lib/core/database/interfaces/dao_interfaces.dart`](../../lib/core/database/interfaces/dao_interfaces.dart)

| Interface | Implementation | Methods | Purpose |
|-----------|---------------|---------|---------|
| `IExpensesDao` | `ExpensesDao` | 14 | Expense CRUD + soft delete + streams |
| `IGroupsDao` | `GroupsDao` | 20 | Group CRUD + members + soft delete |
| `IExpenseSharesDao` | `ExpenseSharesDao` | 3 | Manage expense splits |
| `ISyncDao` | `SyncDao` | 5 | Upload queue management |
| `IUserDao` | `UserDao` | 4 | Local user cache |

**Before:**
```dart
class SyncedExpenseRepository implements ExpenseRepository {
  final AppDatabase _database;

  Future<ExpenseEntity> createExpense(ExpenseEntity expense) async {
    await _database.expensesDao.insertExpense(expense); // ❌ Concrete DAO
  }
}
```

**After:**
```dart
class SyncedExpenseRepository implements ExpenseRepository {
  final IExpensesDao _expensesDao;  // ✅ Interface
  final ISyncDao _syncDao;          // ✅ Interface
  final IEventBroker _eventBroker;  // ✅ Interface

  SyncedExpenseRepository({
    required IExpensesDao expensesDao,
    required ISyncDao syncDao,
    required IEventBroker eventBroker,
    // ...
  }) : _expensesDao = expensesDao,
       _syncDao = syncDao,
       _eventBroker = eventBroker;

  Future<ExpenseEntity> createExpense(ExpenseEntity expense) async {
    await _expensesDao.insertExpense(expense); // ✅ Mockable
  }
}
```

### Phase 2: Use Case Interfaces (11 interfaces)

**Expense Use Cases:** [`lib/features/expenses/domain/use_cases/expense_use_case_interfaces.dart`](../../lib/features/expenses/domain/use_cases/expense_use_case_interfaces.dart)

| Interface | Implementation |
|-----------|---------------|
| `ICreateExpenseUseCase` | `CreateExpenseUseCase` |
| `IUpdateExpenseUseCase` | `UpdateExpenseUseCase` |
| `IDeleteExpenseUseCase` | `DeleteExpenseUseCase` |
| `IGetExpenseUseCase` | `GetExpenseUseCase` |
| `IGetExpensesByGroupUseCase` | `GetExpensesByGroupUseCase` |

**Group Use Cases:** [`lib/features/groups/domain/use_cases/group_use_case_interfaces.dart`](../../lib/features/groups/domain/use_cases/group_use_case_interfaces.dart)

| Interface | Implementation |
|-----------|---------------|
| `ICreateGroupUseCase` | `CreateGroupUseCase` |
| `IUpdateGroupUseCase` | `UpdateGroupUseCase` |
| `IDeleteGroupUseCase` | `DeleteGroupUseCase` |
| `IAddMemberUseCase` | `AddMemberUseCase` |
| `IRemoveMemberUseCase` | `RemoveMemberUseCase` |
| `IJoinGroupByCodeUseCase` | `JoinGroupByCodeUseCase` |

**Provider Integration:**
```dart
// Before: Provider exposed concrete type
@riverpod
CreateExpenseUseCase createExpenseUseCase(Ref ref) {
  return CreateExpenseUseCase(ref.watch(expenseRepositoryProvider));
}

// After: Provider exposes interface
@riverpod
ICreateExpenseUseCase createExpenseUseCase(Ref ref) {
  return CreateExpenseUseCase(ref.watch(expenseRepositoryProvider));
}
```

This seemingly small change enables complete UI testing:
```dart
// Now possible: Override with mock in tests
final container = ProviderContainer(
  overrides: [
    createExpenseUseCaseProvider.overrideWithValue(mockUseCase),
  ],
);
```

### Phase 3: Sync Service Interfaces (3 interfaces)

**Location:** [`lib/core/sync/sync_service_interfaces.dart`](../../lib/core/sync/sync_service_interfaces.dart)

| Interface | Implementation | Responsibility |
|-----------|---------------|----------------|
| `ISyncService` | `SyncService` | Orchestrates sync (main entry point) |
| `IUploadQueueService` | `UploadQueueService` | Processes upload queue |
| `IRealtimeSyncService` | `RealtimeSyncService` | Manages Firestore listeners |

**Benefits:**
- Sync logic testable without Firestore
- Can swap sync strategy without touching business logic
- Enables offline testing scenarios

### Phase 4: EventBroker Refactor

**Problem:** Singleton pattern made testing difficult.

**Before:**
```dart
class EventBroker {
  static EventBroker? _instance;
  factory EventBroker() => _instance ??= EventBroker._internal();

  EventBroker._internal();
  // ...
}

// Usage: Global state
final broker = EventBroker(); // Always same instance
```

**After:**
```dart
// Interface
abstract class IEventBroker {
  Stream<AppEvent> get stream;
  void fire(AppEvent event);
  Stream<T> on<T extends AppEvent>();
  void dispose();
  bool get isClosed;
  bool get hasListeners;
}

// Implementation (no singleton)
class EventBroker implements IEventBroker {
  final _controller = StreamController<AppEvent>.broadcast();
  // ... implementation
}

// Riverpod provider
@Riverpod(keepAlive: true)
IEventBroker eventBroker(Ref ref) {
  final broker = EventBroker();
  ref.onDispose(broker.dispose);
  return broker;
}
```

**Location:**
- Interface: [`lib/core/events/event_broker_interface.dart`](../../lib/core/events/event_broker_interface.dart)
- Implementation: [`lib/core/events/event_broker.dart`](../../lib/core/events/event_broker.dart)
- Provider: [`lib/core/events/event_providers.dart`](../../lib/core/events/event_providers.dart)

---

## Testing Impact

### Before: Difficult to Test

```dart
test('repository creates expense', () async {
  // ❌ Required full database setup
  final database = AppDatabase();
  final repository = SyncedExpenseRepository(database: database);

  // ❌ Real database operations
  await repository.createExpense(testExpense);

  // ❌ Hard to isolate logic from DB
});
```

### After: Isolated Unit Tests

```dart
@GenerateMocks([IExpensesDao, ISyncDao, IEventBroker])
test('repository creates expense', () async {
  // ✅ Lightweight mocks
  final mockExpensesDao = MockIExpensesDao();
  final mockSyncDao = MockISyncDao();
  final mockEventBroker = MockIEventBroker();

  final repository = SyncedExpenseRepository(
    database: mockDatabase,
    expensesDao: mockExpensesDao,  // ✅ Injected mock
    syncDao: mockSyncDao,
    eventBroker: mockEventBroker,
    ownerId: 'user123',
  );

  // ✅ Test repository logic in complete isolation
  await repository.createExpense(testExpense);

  // ✅ Verify specific DAO method was called
  verify(mockExpensesDao.insertExpense(testExpense)).called(1);

  // ✅ Verify event was fired
  verify(mockEventBroker.fire(any)).called(2);
});
```

### Test Suite Results

```
✓ 302 tests passing

Breakdown by layer:
├─ DAO Tests: 44 tests
│  └─ ExpensesDao (14), GroupsDao (11), SyncDao (9), others (10)
├─ Use Case Tests: 13 test files
│  └─ All use mocked repositories
├─ Repositories: 137 tests
│  └─ All use mocked DAOs (no database required)
├─ Sync Services: 12 tests
│  └─ All use mocked Firestore services
├─ Balance Calculations: 14 tests
│  └─ Algorithm correctness, settlement optimization
├─ Balance Providers: 10 tests
│  └─ Event-driven reactive updates
├─ Entity Serialization: 24 tests
│  └─ User, ExpenseShareEntity, GroupMemberEntity, schema validation
└─ Integration: 2 flows
   └─ End-to-end with real implementations
```

**Note:** Overall coverage is ~32%, but the critical business logic paths (repositories, use cases, sync coordination) have significantly higher coverage. UI layer tests are planned for Phase 3.

---

## Technical Decisions

### 1. Interface Naming Convention

**Decision:** Prefix with `I` (e.g., `IExpensesDao`)

**Rationale:**
- Clear distinction between interface and implementation
- Common in C#, TypeScript ecosystems
- Dart doesn't have a strong convention, so we chose clarity

### 2. Use Case Interfaces: One Per Use Case

**Decision:** `ICreateExpenseUseCase` instead of `IUseCase<ExpenseEntity, ExpenseEntity>`

**Tradeoff:**
- More files (11 interface files)
- But: Clearer semantic meaning, better IDE support

**Example:**
```dart
// ❌ Generic: What does this do?
Provider<IUseCase<ExpenseEntity, ExpenseEntity>> somethingProvider;

// ✅ Semantic: Clear intent
Provider<ICreateExpenseUseCase> createExpenseUseCaseProvider;
```

### 3. Provider Types: Interfaces, Not Concrete

**Decision:** All providers return interface types

```dart
// ❌ Before
@riverpod
CreateExpenseUseCase createExpenseUseCase(Ref ref) { ... }

// ✅ After
@riverpod
ICreateExpenseUseCase createExpenseUseCase(Ref ref) { ... }
```

**Impact:** Enables test overrides without type errors.

### 4. EventBroker: Riverpod-Managed, Not Singleton

**Decision:** Remove singleton pattern, use Riverpod for lifecycle

**Rationale:**
- Riverpod already manages singletons via `@Riverpod(keepAlive: true)`
- Automatic cleanup via `ref.onDispose`
- Testable: Can provide mock in tests
- Consistent with rest of architecture

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│ Presentation Layer                                           │
│ - Riverpod Providers: depend on IUseCase                    │
│ - UI Widgets: watch providers                                │
└─────────────────────────────────────────────────────────────┘
                            ↓
              (depends on interfaces only)
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ Domain Layer                                                 │
│ - Use Cases: implement ICreateExpenseUseCase                │
│ - Entities: ExpenseEntity, GroupEntity                      │
│ - Repository Interfaces: ExpenseRepository                  │
└─────────────────────────────────────────────────────────────┘
                            ↓
              (implements interfaces)
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ Data Layer                                                   │
│ - Repositories: implement ExpenseRepository                  │
│   - Depend on: IExpensesDao, ISyncDao, IEventBroker        │
│ - DAOs: implement IExpensesDao, IGroupsDao                  │
│ - Sync Services: implement ISyncService                     │
└─────────────────────────────────────────────────────────────┘
```

**Dependency Rule:** All dependencies point inward. The domain layer has zero knowledge of the data or presentation layers.

---

## Metrics

| Metric | Before | After |
|--------|--------|-------|
| Data access layer | Concrete DAOs | Interface-based (5 interfaces) |
| Business logic layer | Concrete use cases | Interface-based (11 interfaces) |
| Sync layer | Concrete services | Interface-based (3 interfaces) |
| Event system | Singleton | Interface + Riverpod-managed |
| Repository testing | Required full database | Mocked DAOs only |
| Use case testing | Required repositories | Mocked repositories only |
| Singleton anti-patterns | 1 (EventBroker) | 0 |
| Test coverage | ~32% (200+ tests) | ~32% (302 tests, now isolated) |

---

## References

- **[Original Analysis](dependency-inversion-analysis.md)** - The document that identified the 24 components needing interfaces
- **[Project Plan](../current/PLAN.md)** - Overall development roadmap
- **[Current Architecture](../current/CURRENT_ARCHITECTURE.md)** - High-level architectural overview
- **[Data Schema](../current/DATA_SCHEMA_COMPLETE.md)** - Database schema documentation

---

## Lessons Learned

1. **Interfaces aren't overhead if they enable testing.** The 24 interface files are worth it.
2. **Name interfaces semantically.** `ICreateExpenseUseCase` > `IUseCase<T, R>`.
3. **Providers should expose interfaces.** This is critical for test overrides.
4. **Singletons and DI containers don't mix.** If you have Riverpod, don't use singletons.
5. **Refactoring working code is hard but necessary.** The app worked before this refactor, but it wasn't maintainable.
