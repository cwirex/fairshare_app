# Dependency Inversion Analysis - FairShare App

**Date:** 2025-10-24
**Status:** Architecture Review
**Priority:** HIGH - Critical architectural gaps identified

---

## Executive Summary

This document analyzes all business logic components that the UI/presentation layer depends on, identifying concrete implementations that lack abstractions. The analysis covers **Services, Use Cases, DAOs, Providers, and all other business logic**.

### Key Findings:
- ✅ **Good:** 4 repository interfaces exist (`AuthRepository`, `ExpenseRepository`, `GroupRepository`, `RemoteGroupService`)
- ❌ **Critical Gap:** 5 DAOs are concrete (blocks repository testing)
- ❌ **Critical Gap:** 11 Use Cases are concrete (blocks UI testing)
- ❌ **Critical Gap:** 3 Core Sync Services are concrete (blocks sync testing)
- ❌ **Inconsistency:** Only 1 of 3 Firestore services has an interface

**Total Components Needing Interfaces:** ~22 critical components

### 🎯 Key Architectural Decisions

Based on review feedback, the following decisions have been made:

1. **✅ Use Case Abstraction: Option A (Individual Interfaces)**
   - Each use case gets its own interface (e.g., `ICreateExpenseUseCase`)
   - **Rationale:** Architecturally purer, clearer semantic intent, better long-term maintainability
   - **Trade-off:** More files (11 interfaces) but significantly better code clarity

2. **✅ EventBroker: Remove Singleton Pattern**
   - Remove static `_instance` and factory constructor
   - Let Riverpod manage the singleton lifecycle via provider
   - **Rationale:** Anti-pattern to have static singleton when using DI container
   - **Benefit:** Consistent with Riverpod architecture, testable, no global state pollution

---

## 🔴 CRITICAL PRIORITY - Must Add Interfaces

### 1. DAOs (Data Access Objects) - 5 Files

**Impact:** Cannot test repositories without full Drift database setup

#### Current State vs Proposed Solution

**Current:** Repositories depend on concrete DAOs
```dart
// ❌ Current: lib/features/expenses/data/repositories/synced_expense_repository.dart
class SyncedExpenseRepository implements ExpenseRepository {
  final AppDatabase _database;  // Exposes concrete DAOs

  @override
  Future<Result<ExpenseEntity>> createExpense(ExpenseEntity expense) async {
    // Direct dependency on concrete DAO
    await _database.expensesDao.insertExpense(expense);
  }
}

// ❌ Current: lib/core/database/DAOs/expenses_dao.dart
class ExpensesDao extends DatabaseAccessor<AppDatabase> {
  // Concrete Drift implementation - cannot mock
  Future<void> insertExpense(ExpenseEntity expense) { ... }
  Stream<List<ExpenseEntity>> watchExpensesByGroup(String groupId) { ... }
}
```

**Proposed:** Abstract DAOs with interfaces
```dart
// ✅ Proposed: Create lib/core/database/interfaces/i_expenses_dao.dart
abstract class IExpensesDao {
  Future<void> insertExpense(ExpenseEntity expense);
  Future<ExpenseEntity?> getExpenseById(String id);
  Stream<List<ExpenseEntity>> watchExpensesByGroup(String groupId);
  Future<void> updateExpense(ExpenseEntity expense);
  Future<void> deleteExpense(String id);
  // ... all other methods
}

// ✅ Proposed: Implement interface
class ExpensesDao extends DatabaseAccessor<AppDatabase> implements IExpensesDao {
  // Same implementation, now abstracted
}

// ✅ Proposed: Repository depends on interface
class SyncedExpenseRepository implements ExpenseRepository {
  final IExpensesDao _expensesDao;

  SyncedExpenseRepository({required IExpensesDao expensesDao})
    : _expensesDao = expensesDao;

  @override
  Future<Result<ExpenseEntity>> createExpense(ExpenseEntity expense) async {
    await _expensesDao.insertExpense(expense);  // Now mockable!
  }
}
```

**Files Affected:**
- `lib/core/database/DAOs/expenses_dao.dart` → Need `IExpensesDao`
- `lib/core/database/DAOs/groups_dao.dart` → Need `IGroupsDao`
- `lib/core/database/DAOs/expense_shares_dao.dart` → Need `IExpenseSharesDao`
- `lib/core/database/DAOs/user_dao.dart` → Need `IUserDao`
- `lib/core/database/DAOs/sync_dao.dart` → Need `ISyncDao`

**Benefits:**
- ✅ Test repositories with mock DAOs (no database setup)
- ✅ Swap database implementations (Hive, Isar, SQLite)
- ✅ Follow Dependency Inversion Principle
- ✅ Consistent with repository pattern you already use

---

### 2. Use Cases - 11 Files

**Impact:** Cannot mock business logic for presentation layer tests

#### Current State vs Proposed Solution

**Current:** Providers depend on concrete use cases
```dart
// ❌ Current: lib/features/expenses/domain/use_cases/create_expense_use_case.dart
class CreateExpenseUseCase extends UseCase<ExpenseEntity, ExpenseEntity> {
  final ExpenseRepository _repository;

  CreateExpenseUseCase(this._repository);

  @override
  Future<Result<ExpenseEntity>> execute(ExpenseEntity expense) async {
    return await _repository.createExpense(expense);
  }

  @override
  Result<void> validate(ExpenseEntity expense) {
    if (expense.amount <= 0) return Failure(Exception('Amount must be > 0'));
    return Success.unit();
  }
}

// ❌ Current: Providers directly use concrete classes
final createExpenseUseCase = Provider<CreateExpenseUseCase>((ref) {
  return CreateExpenseUseCase(ref.watch(expenseRepository));
});
```

**Proposed - Option A:** Individual interfaces (✅ **RECOMMENDED** - Architecturally purer)
```dart
// ✅ Proposed: Create lib/features/expenses/domain/interfaces/i_create_expense_use_case.dart
abstract class ICreateExpenseUseCase {
  Future<Result<ExpenseEntity>> call(ExpenseEntity expense);
}

// ✅ Proposed: Implement interface
class CreateExpenseUseCase extends UseCase<ExpenseEntity, ExpenseEntity>
    implements ICreateExpenseUseCase {
  // Same implementation
}

// ✅ Proposed: Provider depends on interface (Clear semantic intent!)
final createExpenseUseCase = Provider<ICreateExpenseUseCase>((ref) {
  return CreateExpenseUseCase(ref.watch(expenseRepository));
});
```

**Why Option A is Better:**
- ✅ **Clear semantic intent:** `ICreateExpenseUseCase` is explicit about behavior
- ✅ **Better DI:** Dependencies declare *what* they do, not just types
- ✅ **Better long-term:** Easier to understand code 6 months later
- ✅ **IDE support:** Better autocomplete and navigation
- ⚠️ **Trade-off:** More interfaces (11 files), but the clarity is worth it

**Proposed - Option B:** Generic interface (Simpler, less boilerplate)
```dart
// ✅ Proposed: Update lib/core/domain/use_case.dart
abstract class IUseCase<Input, Output> {
  Future<Result<Output>> call(Input input);
}

// ✅ Proposed: Base class implements interface
abstract class UseCase<Input, Output> implements IUseCase<Input, Output> {
  @override
  Future<Result<Output>> call(Input input) async {
    final validationResult = validate(input);
    if (validationResult.isError()) return validationResult.toFailure();
    return await execute(input);
  }

  Result<void> validate(Input input) => Success.unit();
  Future<Result<Output>> execute(Input input);
}

// ✅ Proposed: Providers use generic interface
final createExpenseUseCase = Provider<IUseCase<ExpenseEntity, ExpenseEntity>>((ref) {
  return CreateExpenseUseCase(ref.watch(expenseRepository));
});
```

**Why Option B is Less Ideal:**
- ✅ **Pro:** Simple, one interface to rule them all
- ✅ **Pro:** Less boilerplate (no 11 interface files)
- ❌ **Con:** Less semantically clear - "thing that takes Expense and returns Expense"
- ❌ **Con:** Harder to read: What does `IUseCase<ExpenseEntity, ExpenseEntity>` do?
- ⚠️ **Trade-off:** Simpler but sacrifices clarity

**Final Recommendation:** **Go with Option A** for architectural purity and better long-term maintainability.

**Files Affected:**

**Expense Use Cases:**
- `create_expense_use_case.dart`
- `update_expense_use_case.dart`
- `delete_expense_use_case.dart`
- `get_expense_use_case.dart`
- `get_expenses_by_group_use_case.dart`

**Group Use Cases:**
- `create_group_use_case.dart`
- `update_group_use_case.dart`
- `delete_group_use_case.dart`
- `add_member_use_case.dart`
- `remove_member_use_case.dart`
- `join_group_by_code_use_case.dart`

**Benefits:**
- ✅ Test notifiers/ViewModels with mock use cases
- ✅ Add decorators: `LoggingUseCase`, `CachedUseCase`, `RetryUseCase`
- ✅ Follow Open/Closed Principle
- ✅ Consistent with repository abstraction pattern

---

### 3. Core Sync Services - 3 Files

**Impact:** Cannot test sync architecture without live Firestore

#### Current State vs Proposed Solution

**Current:** Concrete sync services
```dart
// ❌ Current: lib/core/sync/sync_service.dart
class SyncService with LoggerMixin, WidgetsBindingObserver {
  final UploadQueueService _uploadQueueService;
  final RealtimeSyncService _realtimeSyncService;
  // Concrete dependencies

  void startAutoSync(String? userId) {
    _uploadQueueService.processQueue();
    _realtimeSyncService.startRealtimeSync(userId);
  }
}

// ❌ Current: Providers expose concrete classes
final syncService = Provider<SyncService>((ref) {
  return SyncService(
    database: ref.watch(appDatabase),
    uploadQueueService: ref.watch(uploadQueueService),
    // ...
  );
});
```

**Proposed:** Abstract with interfaces
```dart
// ✅ Proposed: Create lib/core/sync/interfaces/i_sync_service.dart
abstract class ISyncService {
  void startAutoSync(String? userId);
  void stopAutoSync();
  Future<Result<void>> syncAll(String userId);
  Future<int> getPendingUploadCount();
  Map<String, dynamic> getSyncStatus();
  void dispose();
}

// ✅ Proposed: Create lib/core/sync/interfaces/i_upload_queue_service.dart
abstract class IUploadQueueService {
  Future<UploadQueueResult> processQueue();
  Future<int> getPendingCount();
}

// ✅ Proposed: Create lib/core/sync/interfaces/i_realtime_sync_service.dart
abstract class IRealtimeSyncService {
  Future<void> startRealtimeSync(String userId);
  Future<void> stopRealtimeSync();
  void listenToActiveGroup(String groupId);
  void stopListeningToActiveGroup();
  Map<String, dynamic> getStatus();
}

// ✅ Proposed: Implementations
class SyncService with LoggerMixin, WidgetsBindingObserver implements ISyncService {
  // Same implementation
}

// ✅ Proposed: Providers use interfaces
final syncService = Provider<ISyncService>((ref) {
  return SyncService(/* ... */);
});
```

**Files Affected:**
- `lib/core/sync/sync_service.dart`
- `lib/core/sync/upload_queue_service.dart`
- `lib/core/sync/realtime_sync_service.dart`

**Benefits:**
- ✅ Test presentation layer without Firestore
- ✅ Mock sync behavior for offline testing
- ✅ Enable alternative sync strategies
- ✅ Isolate sync logic from infrastructure

---

### 4. Firestore Services - 2 Files (Missing Interfaces)

**Impact:** Inconsistent abstraction, sync services tightly coupled to Firestore

#### Current State vs Proposed Solution

**Current:** Only groups have interface, expenses and users don't
```dart
// ✅ Already exists: lib/features/groups/domain/services/remote_group_service.dart
abstract class RemoteGroupService {
  Future<Result<void>> uploadGroup(GroupEntity group);
  Future<Result<GroupEntity>> downloadGroup(String groupId);
  // ... other methods
}

// ❌ Current: No interface for expenses
// lib/features/expenses/data/services/firestore_expense_service.dart
class FirestoreExpenseService with LoggerMixin {
  final FirebaseFirestore _firestore;

  Future<Result<void>> uploadExpense(ExpenseEntity expense) { ... }
  Stream<List<ExpenseEntity>> watchGroupExpenses(String groupId) { ... }
}

// ❌ Current: UploadQueueService depends on concrete class
class UploadQueueService {
  final FirestoreExpenseService _expenseService;  // Concrete!

  Future<void> _processExpenseOperation(SyncQueueData operation) async {
    await _expenseService.uploadExpense(expense);  // Cannot mock
  }
}
```

**Proposed:** Match the groups pattern
```dart
// ✅ Proposed: Create lib/features/expenses/domain/services/remote_expense_service.dart
abstract class RemoteExpenseService {
  Future<Result<void>> uploadExpense(ExpenseEntity expense);
  Future<Result<void>> uploadExpenseShare(ExpenseShareEntity share);
  Future<Result<ExpenseEntity>> downloadExpense(String groupId, String expenseId);
  Future<Result<List<ExpenseEntity>>> downloadGroupExpenses(String groupId);
  Future<Result<List<ExpenseShareEntity>>> downloadExpenseShares(String groupId, String expenseId);
  Future<Result<void>> deleteExpense(String groupId, String expenseId);
  Stream<List<ExpenseEntity>> watchGroupExpenses(String groupId);
  Stream<ExpenseEntity> watchExpense(String groupId, String expenseId);
  Stream<List<ExpenseShareEntity>> watchExpenseShares(String groupId, String expenseId);
}

// ✅ Proposed: Implement interface
class FirestoreExpenseService with LoggerMixin implements RemoteExpenseService {
  // Same implementation
}

// ✅ Proposed: Create lib/features/auth/domain/services/remote_user_service.dart
abstract class RemoteUserService {
  Future<Result<void>> uploadUser(User user);
  Future<Result<User>> downloadUser(String userId);
  Stream<User> watchUser(String userId);
}

// ✅ Proposed: UploadQueueService depends on interface
class UploadQueueService {
  final RemoteExpenseService _expenseService;  // Now mockable!
}
```

**Files Affected:**
- `lib/features/expenses/data/services/firestore_expense_service.dart`
- `lib/features/auth/data/services/firestore_user_service.dart`

**Benefits:**
- ✅ Consistent pattern across all remote services
- ✅ Test sync services without Firestore
- ✅ Enable alternative backends (REST, GraphQL)
- ✅ Match existing `RemoteGroupService` pattern

---

### 5. GroupInitializationService - 1 File

**Impact:** Cannot test `SyncService.startAutoSync()` without side effects

#### Current State vs Proposed Solution

**Current:** Concrete service with side effects
```dart
// ❌ Current: lib/features/groups/data/services/group_initialization_service.dart
class GroupInitializationService with LoggerMixin {
  final GroupRepository _repository;

  Future<void> ensurePersonalGroupExists(String userId) async {
    try {
      await _repository.getGroupById(userId);
    } catch (e) {
      await _createPersonalGroup(userId);  // Side effect!
    }
  }
}

// ❌ Current: SyncService depends on concrete class
class SyncService {
  final GroupInitializationService _groupInitializationService;

  void startAutoSync(String? userId) {
    _groupInitializationService.ensurePersonalGroupExists(userId);
    // Cannot test without creating actual group!
  }
}
```

**Proposed:** Abstract with interface
```dart
// ✅ Proposed: Create lib/features/groups/domain/services/i_group_initialization_service.dart
abstract class IGroupInitializationService {
  Future<void> ensurePersonalGroupExists(String userId);
}

// ✅ Proposed: Implement interface
class GroupInitializationService with LoggerMixin
    implements IGroupInitializationService {
  // Same implementation
}

// ✅ Proposed: SyncService depends on interface
class SyncService {
  final IGroupInitializationService _groupInitializationService;
  // Now mockable!
}
```

**Files Affected:**
- `lib/features/groups/data/services/group_initialization_service.dart`

**Benefits:**
- ✅ Test SyncService without database side effects
- ✅ Mock group initialization behavior
- ✅ Simple to implement (single method)

---

## 🟡 MEDIUM PRIORITY - Should Add Interfaces

### 6. EventBroker - 1 File

**Impact:** Hard to verify event flows in tests

#### Current State vs Proposed Solution

**Current:** Concrete singleton (Anti-pattern with Riverpod!)
```dart
// ❌ Current: lib/core/events/event_broker.dart
class EventBroker {
  static final EventBroker _instance = EventBroker._internal();  // ❌ Anti-pattern!
  factory EventBroker() => _instance;

  final _controller = StreamController<AppEvent>.broadcast();

  void fire(AppEvent event) => _controller.add(event);
  Stream<T> on<T extends AppEvent>() => _controller.stream.where((e) => e is T).cast<T>();
}

// ❌ Current: Cannot verify events in tests
class SyncedExpenseRepository {
  final EventBroker _eventBroker;

  Future<Result<ExpenseEntity>> createExpense(ExpenseEntity expense) async {
    await _expensesDao.insertExpense(expense);
    _eventBroker.fire(ExpenseCreated(expense));  // Cannot verify!
  }
}
```

**Why Current is Anti-Pattern:**
- ❌ **Riverpod IS your service locator** - using static singleton bypasses DI
- ❌ **Cannot mock in tests** - static instance always returns real broker
- ❌ **Global state pollution** - singleton persists across tests
- ❌ **Pattern inconsistency** - other services use Riverpod, EventBroker doesn't

**Proposed:** Abstract with interface AND remove singleton pattern
```dart
// ✅ Proposed: Create lib/core/events/i_event_broker.dart
abstract class IEventBroker {
  void fire(AppEvent event);
  Stream<T> on<T extends AppEvent>();
  void dispose();
}

// ✅ Proposed: Remove static singleton, implement interface
class EventBroker implements IEventBroker {
  // NO static instance, NO private constructor, NO factory
  final _controller = StreamController<AppEvent>.broadcast();

  void fire(AppEvent event) => _controller.add(event);
  Stream<T> on<T extends AppEvent>() => _controller.stream.where((e) => e is T).cast<T>();
  void dispose() => _controller.close();
}

// ✅ Proposed: Riverpod manages the singleton (already exists, just update type)
// lib/core/events/event_providers.dart
final eventBrokerProvider = Provider<IEventBroker>((ref) {
  final broker = EventBroker();  // Riverpod manages lifecycle
  ref.onDispose(() => broker.dispose());
  return broker;
});

// ✅ Proposed: Repository depends on interface
class SyncedExpenseRepository {
  final IEventBroker _eventBroker;

  Future<Result<ExpenseEntity>> createExpense(ExpenseEntity expense) async {
    await _expensesDao.insertExpense(expense);
    _eventBroker.fire(ExpenseCreated(expense));

    // ✅ In tests: verify(mockEventBroker.fire(any));
  }
}
```

**Why This is Better:**
- ✅ **Riverpod manages singleton** - consistent with your architecture
- ✅ **Mockable in tests** - provider can be overridden
- ✅ **No global state** - each test gets fresh broker via ProviderContainer
- ✅ **Proper disposal** - Riverpod handles lifecycle
- ✅ **Pattern consistency** - matches how you use other services

**Files Affected:**
- `lib/core/events/event_broker.dart`

**Benefits:**
- ✅ Verify event firing in tests
- ✅ Mock event subscribers
- ✅ Enable alternative event bus implementations
- ✅ Test event-driven flows in isolation

---

## 🟢 LOW PRIORITY - Acceptable As-Is

### 7. BalanceCalculationService

**Status:** ✅ Pure business logic, no external dependencies
```dart
// ✅ Current: Already testable
class BalanceCalculationService {
  Map<String, double> calculateNetBalances(
    List<GroupMemberEntity> members,
    List<ExpenseEntity> expenses,
    List<ExpenseShareEntity> shares,
  ) {
    // Pure calculation - easy to test
  }
}
```

**Recommendation:** Interface optional, current implementation acceptable

---

### 8. Formatters & Converters

**Status:** ✅ Pure utility functions
```dart
// ✅ Current: Already testable
class ExpenseFormatter {
  static String formatAmount(double amount) { ... }
  static String formatDate(DateTime date) { ... }
}
```

**Recommendation:** No interface needed

---

### 9. Monitoring & Logging

**Status:** ✅ Infrastructure singletons
```dart
// ✅ Current: Acceptable pattern
class SyncMetrics {
  static final instance = SyncMetrics._();
  void recordSyncSuccess() { ... }
}
```

**Recommendation:** Standard pattern, no interface needed

---

### 10. Providers/Notifiers

**Status:** ✅ Riverpod handles testing
```dart
// ✅ Current: Testable with ProviderContainer
class AuthNotifier extends _$AuthNotifier {
  Future<void> signInWithGoogle() { ... }
}

// ✅ Test without interface:
final container = ProviderContainer(overrides: [
  authNotifierProvider.overrideWith(() => MockAuthNotifier()),
]);
```

**Recommendation:** Riverpod's design handles this, interface optional

---

### 11. Entities & Value Objects

**Status:** ✅ Pure data models (Freezed)
```dart
// ✅ Current: Correct pattern
@freezed
class ExpenseEntity with _$ExpenseEntity {
  const factory ExpenseEntity({ ... }) = _ExpenseEntity;
}
```

**Recommendation:** Entities should remain concrete

---

## 📊 Comprehensive Criticality Matrix

| Component | Files | Priority | Testing Impact | Interfaces Needed |
|-----------|-------|----------|----------------|-------------------|
| **DAOs** | 5 | 🔴 CRITICAL | Cannot test repos | 5 |
| **Use Cases** | 11 | 🔴 CRITICAL | Cannot mock for UI | 11 (or 1 generic) |
| **Sync Services** | 3 | 🔴 CRITICAL | Cannot test sync | 3 |
| **Firestore Services** | 2 | 🔴 CRITICAL | Inconsistent pattern | 2 |
| **GroupInitService** | 1 | 🔴 CRITICAL | Blocks testing | 1 |
| **EventBroker** | 1 | 🟡 MEDIUM | Hard to verify | 1 |
| **Notifiers** | ~10 | 🟡 MEDIUM | Riverpod handles | 0 (optional) |
| **BalanceCalcService** | 1 | 🟢 LOW | Already testable | 0 (optional) |
| **Formatters** | 2 | 🟢 LOW | Pure functions | 0 |
| **Metrics/Logging** | 2 | 🟢 LOW | Infrastructure | 0 |
| **Entities** | ~10 | 🟢 LOW | Data models | 0 |

**Total Interfaces Needed:**
- **Critical:** 22 interfaces (using individual use case interfaces - Option A)
- **Optional:** 1-2 interfaces (EventBroker, others)

**Note:** We're going with Option A (individual use case interfaces) for semantic clarity and long-term maintainability.

---

## 🎯 Implementation Roadmap

### Phase 1: Foundation (Highest ROI) - 2-3 Days
**Goal:** Enable repository and sync testing

1. ✅ Create DAO interfaces (5 interfaces)
   - `IExpensesDao`, `IGroupsDao`, `IExpenseSharesDao`, `IUserDao`, `ISyncDao`
   - Update repositories to depend on interfaces
   - Update `AppDatabase` to return interfaces
   - **Files:** ~15 modified

2. ✅ Create Firestore service interfaces (2 interfaces)
   - `RemoteExpenseService`, `RemoteUserService`
   - Match existing `RemoteGroupService` pattern
   - **Files:** ~8 modified

3. ✅ Create Sync service interfaces (3 interfaces)
   - `ISyncService`, `IUploadQueueService`, `IRealtimeSyncService`
   - Update providers to use interfaces
   - **Files:** ~10 modified

**Deliverable:** Can test entire data and sync layers with mocks

---

### Phase 2: Use Case Abstraction - 1-2 Days
**Goal:** Enable presentation layer testing

4. ✅ Create use case interfaces (**Use Option A - Individual Interfaces**)
   - **RECOMMENDED:** 11 individual interfaces (e.g., `ICreateExpenseUseCase`)
   - Provides clear semantic intent and better long-term maintainability
   - Update providers to depend on interfaces
   - **Files:** ~25 modified

5. ✅ Create `IGroupInitializationService` interface
   - **Files:** ~3 modified

**Deliverable:** Can test notifiers/ViewModels with mock business logic

---

### Phase 3: Event System Refinement - 0.5-1 Day
**Goal:** Better event testing and proper DI pattern

6. ✅ Create `IEventBroker` interface AND remove singleton pattern
   - Enable event verification in tests
   - Remove static `_instance` and let Riverpod manage lifecycle
   - Update `eventBrokerProvider` to return `IEventBroker`
   - **Files:** ~15 modified (many components use EventBroker)
   - **IMPORTANT:** This fixes an anti-pattern (static singleton + DI container)

**Deliverable:** Can verify event flows in tests + proper Riverpod pattern

---

### Phase 4: Optional Refinements - 1-2 Days
**Goal:** Architectural perfectionism

7. 🔘 Abstract notifiers if desired (optional)
8. 🔘 Add use case decorators (logging, caching, analytics)
9. 🔘 Consider interface for `BalanceCalculationService` for DDD purity

**Deliverable:** Ultra-clean architecture

---

## 📈 Estimated Effort

| Phase | Files | Effort | ROI |
|-------|-------|--------|-----|
| Phase 1 | ~33 | 2-3 days | 🔥 Very High |
| Phase 2 | ~28 | 1-2 days | 🔥 High |
| Phase 3 | ~15 | 0.5-1 day | 🔥 Medium |
| Phase 4 | ~15 | 1-2 days | 🔥 Low |
| **TOTAL** | **~91** | **4-8 days** | - |

---

## 🏆 What You're Already Doing Right

Your codebase demonstrates excellent architecture in several areas:

✅ **Repository Pattern:** `ExpenseRepository`, `GroupRepository`, `AuthRepository` (interfaces + implementations)
✅ **One Firestore Interface:** `RemoteGroupService` → `FirestoreGroupService`
✅ **Use Case Base Class:** `UseCase<Input, Output>` abstract pattern
✅ **Event-Driven Architecture:** Domain events with `EventBroker`
✅ **User-Scoped Dependencies:** Prevents data leakage in multi-user scenarios
✅ **Clean Domain Entities:** Immutable Freezed models
✅ **Result Type Wrapping:** Functional error handling with `Result<T>`
✅ **Offline-First:** Local database as source of truth

---

## ❌ Critical Architectural Gaps

### Current Issues:

1. **DAOs are concrete**
   - Biggest DIP violation
   - Repositories tightly coupled to Drift
   - Cannot test repositories without full database

2. **Use cases are concrete**
   - Presentation layer tightly coupled to business logic
   - Cannot mock use cases for UI tests
   - Cannot add decorators for cross-cutting concerns

3. **Sync services are concrete**
   - Core architecture tightly coupled to Firestore
   - Cannot test sync flows without live backend
   - Cannot swap sync strategies

4. **Inconsistent Firestore abstraction**
   - Groups have interface, expenses and users don't
   - Pattern inconsistency across features
   - Some services mockable, others not

5. **EventBroker is concrete singleton**
   - Hard to verify event flows in tests
   - Cannot mock event system
   - Testing event-driven behavior requires real broker
   - **Anti-pattern:** Static singleton when using Riverpod DI container

### Consequences:

- 🚫 **High coupling to Drift** - Cannot swap database
- 🚫 **High coupling to Firestore** - Cannot swap backend
- 🚫 **Difficult to test** - Most layers require full infrastructure
- 🚫 **Cannot swap implementations** - Locked into tech stack
- 🚫 **Violates SOLID principles** - Dependency Inversion violated

---

## 💡 Benefits of Proposed Changes

### Testing Benefits:
- ✅ Unit test repositories without database
- ✅ Unit test use cases in isolation
- ✅ Unit test presentation layer with mocks
- ✅ Verify event flows in tests
- ✅ Test sync logic without Firestore

### Architecture Benefits:
- ✅ Follow Dependency Inversion Principle
- ✅ Enable alternative implementations
- ✅ Add decorators for cross-cutting concerns
- ✅ Consistent abstraction patterns
- ✅ Loose coupling between layers

### Maintenance Benefits:
- ✅ Easier to refactor implementations
- ✅ Technology stack flexibility
- ✅ Better separation of concerns
- ✅ Clearer architectural boundaries
- ✅ Future-proof design

---

## 📝 Next Steps

### Immediate Actions (Recommended):
1. **Review this analysis** with the team
2. **Prioritize Phase 1** (DAOs + Firestore + Sync services)
3. **Create feature branch** for abstraction work
4. **Start with DAOs** (highest impact, foundational)

### Discussion Points:
- ✅ **DECIDED:** Use Option A (individual use case interfaces) for semantic clarity
- ✅ **DECIDED:** Remove EventBroker static singleton, let Riverpod manage lifecycle
- Should we tackle all phases or just Phase 1-2?
- What's our testing strategy once interfaces exist?
- Do we want to add use case decorators (logging, analytics) in Phase 4?

### Success Criteria:
- [ ] All repositories testable without database
- [ ] All use cases mockable for UI tests
- [ ] Sync services testable without Firestore
- [ ] Consistent abstraction patterns across features
- [ ] 80%+ unit test coverage enabled

---

## 🔗 Related Documentation

- [Architecture Overview](./architecture-overview.md)
- [Testing Strategy](./testing-strategy.md)
- [Sync Architecture](./sync-architecture.md)
- [Repository Pattern](./repository-pattern.md)

---

**Document Owner:** Architecture Team
**Last Updated:** 2025-10-24
**Next Review:** After Phase 1 implementation
