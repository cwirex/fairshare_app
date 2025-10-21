# FairShare Development Plan

**Last Updated:** 2025-10-14
**Philosophy:** Build minimally, test thoroughly, iterate quickly.

---

## Current Status: Phase 2.4 Event-Driven Providers 🚀

### Recently Completed ✅

**Phase 1: Event Infrastructure & Use Case Foundation (Week 1)**
- [x] Base `UseCase<Input, Output>` class with `LoggerMixin`
- [x] Event infrastructure complete:
  - [x] `EventBroker` singleton with broadcast streams
  - [x] Event types defined (expenses, groups, sync)
  - [x] Event providers with Riverpod
  - [x] Event filtering and extensions
  - [x] 8 unit tests passing
- [x] Expense use cases implemented (5 files):
  - [x] `CreateExpenseUseCase` with validation
  - [x] `UpdateExpenseUseCase` with validation
  - [x] `DeleteExpenseUseCase` with validation
  - [x] `GetExpenseUseCase`
  - [x] `GetExpensesByGroupUseCase`
- [x] Architectural pattern established:
  - [x] Use Cases handle validation and error wrapping (return `Result<T>`)
  - [x] Repositories throw exceptions (no `Result<T>` wrapping)
  - [x] Clear separation of concerns
- [x] Documentation updated:
  - [x] `REALTIME_SYNC_ARCHITECTURE.md` v2.2
  - [x] `IMPLEMENTATION_PLAN_V2_2.md`
  - [x] `ARCHITECTURE_INTEGRATION_V2_2.md`

### Previously Completed ✅

**Foundation (Phase 1)**
- [x] Firebase Authentication with Google Sign-In
- [x] Offline-first database (Drift/SQLite)
- [x] Basic routing and navigation
- [x] UI foundation (screens, theme)

**Core Functionality (Phase 2.1 & 2.2)**
- [x] Expense creation and tracking
- [x] Personal groups (auto-created)
- [x] Shared groups (create & join)
- [x] Firebase sync with upload queue
- [x] Multi-user architecture (clean schema v1)
- [x] Soft delete support
- [x] Foreign key constraints

---

## Phase 2: v2.2 Architecture Implementation 🎯

**Goal:** Complete the Use Case Layer and Event-Driven Architecture integration

### ✅ Phase 2.1: Use Case Layer - COMPLETED (2025-10-13)

**2.1 Use Cases** ✅ COMPLETED
- [x] **Group Use Cases** (5 files created)
  - [x] `CreateGroupUseCase` with validation
  - [x] `UpdateGroupUseCase` with validation
  - [x] `DeleteGroupUseCase` with validation
  - [x] `AddMemberUseCase` with validation
  - [x] `RemoveMemberUseCase` with validation (with params class)

- [x] **Riverpod Providers**
  - [x] Create `expense_use_case_providers.dart` (moved to presentation/providers/)
  - [x] Create `group_use_case_providers.dart` (moved to presentation/providers/)

- [x] **Presentation Layer Cleanup**
  - [x] Removed `ExpenseNotifier` (UI calls use cases directly)
  - [x] Updated `CreateExpenseScreen` to use use cases
  - [x] Stream providers remain for reactive queries

- [ ] **Unit Tests** ⏳ TODO
  - [ ] Test all expense use cases
  - [ ] Test all group use cases
  - [ ] Aim for >90% test coverage

**Key Achievements:**
- ✅ All 10 use cases implemented with validation
- ✅ Riverpod providers created and moved to presentation layer
- ✅ UI architecture simplified (no Notifiers for commands)
- ✅ Result<T> pattern working correctly
- ✅ Base UseCase pattern established
- ⏳ Unit tests pending

**Architecture Decision:** UI calls use cases directly (no ExpenseNotifier), handles Result<T> with .fold()

---

### ✅ Phase 2.2: Repository Integration - COMPLETED (2025-10-14)

**Goal:** Integrate EventBroker into repositories and update implementations

**Tasks:**
- [x] **Update Repository Implementations**
  - [x] Inject `EventBroker` into `SyncedExpenseRepository`
  - [x] Inject `EventBroker` into `SyncedGroupRepository`
  - [x] Fire events after successful operations
  - [x] Maintain atomic transactions (DB + Queue + Events)
  - [x] Update repository providers

- [x] **Update DAOs**
  - [x] Pass `EventBroker` to DAO sync methods (clean Drift-compatible approach)
  - [x] Update `upsertExpenseFromSync()` to accept EventBroker parameter
  - [x] Update `upsertGroupFromSync()` to accept EventBroker parameter
  - [x] Update `upsertGroupMemberFromSync()` to accept EventBroker parameter
  - [x] Fire correct events for create/update/delete operations

- [x] **RealtimeSyncService Integration**
  - [x] Add EventBroker to RealtimeSyncService constructor
  - [x] Pass EventBroker to all DAO upsert calls
  - [x] Update sync providers to inject EventBroker

- [x] **Testing**
  - [x] Unit tests for repository event firing (137 tests passing)
  - [x] Integration tests for realtime sync service (12 tests passing)
  - [x] Test files updated with EventBroker mocks

**Key Achievement:**
✅ **Clean Architecture Maintained** - DAOs accept EventBroker as method parameters (not constructor), preserving Drift compatibility

**Pattern Implemented:**
```dart
// Repository fires events (local operations)
Future<ExpenseEntity> createExpense(ExpenseEntity expense) async {
  await _database.transaction(() async {
    await _database.expensesDao.insertExpense(expense);
    await _database.syncDao.enqueueOperation(...);
  });
  _eventBroker.fire(ExpenseCreated(expense)); ✅
  return expense;
}

// DAO fires events (sync operations)
Future<void> upsertExpenseFromSync(
  ExpenseEntity expense,
  EventBroker eventBroker, // ✅ Passed as parameter
) async {
  final existing = await getExpenseById(expense.id);
  if (existing == null) {
    await into(expenses).insert(...);
    eventBroker.fire(ExpenseCreated(expense)); ✅
  } else if (expense.updatedAt.isAfter(existing.updatedAt)) {
    await update(expenses).write(...);
    eventBroker.fire(ExpenseUpdated(expense)); ✅
  }
}
```

---

### ✅ Phase 2.3: Realtime Sync with Events - COMPLETED (2025-10-14)

**Goal:** Ensure realtime sync operations fire events correctly

**Tasks:**
- [x] **RealtimeSyncService**
  - [x] Inject EventBroker into service
  - [x] Pass EventBroker to all DAO `upsertFromSync()` calls
  - [x] Verify events fire for remote changes
  - [x] Test hybrid listener strategy (12/12 tests passing)

- [x] **Repository & DAO Event Integration**
  - [x] Repositories fire events on local operations
  - [x] DAOs fire events on sync operations
  - [x] Atomic transactions maintained

- [⏳] **Manual Testing** (deferred)
  - [ ] Test foreground/background lifecycle
  - [ ] Verify < 1 second realtime sync latency
  - [ ] Multi-device testing

**Expected Outcome:**
- ✅ Events fire for BOTH local and remote changes
- ✅ Architecture supports event-driven UI
- ⏳ Manual device testing deferred to later

---

### ⏳ Phase 2.4: Event-Driven Providers - IN PROGRESS

**Goal:** Create computed providers that react to events for reactive UI

**Current Architecture Status:**
- ✅ UI already calls Use Cases directly (no Notifiers needed!)
- ✅ Stream providers exist for queries (`allExpenses`, `userGroups`, etc.)
- ✅ Events fire for both local and remote changes
- ⏳ Need: Computed providers that recalculate when events fire

**Tasks:**

**1. Event-Driven Computed Providers** (Primary Focus)
- [ ] **Group Statistics Providers**
  - [ ] `groupTotalProvider(groupId)` - Sum of expenses, reacts to ExpenseCreated/Updated/Deleted
  - [ ] `groupExpenseCountProvider(groupId)` - Number of expenses per group
  - [ ] `groupBalanceProvider(groupId)` - Per-member balances (future)

- [ ] **Dashboard Providers**
  - [ ] `dashboardStatsProvider` - Aggregate stats across all groups
  - [ ] `recentActivityProvider` - Recent 10 changes (expenses/groups)
  - [ ] `totalSpendingProvider` - Total across all groups

- [ ] **Optional: Activity Feed**
  - [ ] `activityFeedProvider` - Stream of all events for activity log
  - [ ] `groupActivityProvider(groupId)` - Activity stream per group

**2. UI Enhancements**
- [ ] **Validation Error Display**
  - [ ] Show validation errors from Use Cases in snackbars
  - [ ] Form field error states
  - [ ] Improve error messages

- [ ] **Loading & Success States**
  - [ ] Loading indicators during operations
  - [ ] Success feedback (snackbars, animations)
  - [ ] Optimistic UI updates

**3. Testing & Verification**
- [ ] **Reactive Behavior**
  - [ ] Test providers update when events fire
  - [ ] Test multiple screens update simultaneously
  - [ ] Verify no duplicate calculations

- [ ] **Performance**
  - [ ] Profile event overhead (target: < 1ms per event)
  - [ ] Check for memory leaks in providers
  - [ ] Ensure efficient event filtering

**Implementation Pattern:**
```dart
// Event-driven computed provider
@riverpod
Stream<double> groupTotal(Ref ref, String groupId) async* {
  // Initial value
  final expenses = await ref.watch(
    expensesByGroupProvider(groupId).future
  );
  yield expenses.fold(0.0, (sum, e) => sum + e.amount);

  // React to events
  final eventBroker = ref.watch(eventBrokerProvider);
  await for (final event in eventBroker.stream) {
    // Only recalculate if event affects this group
    if (event is ExpenseEvent && event.expense.groupId == groupId) {
      final newExpenses = await ref.read(
        expensesByGroupProvider(groupId).future
      );
      yield newExpenses.fold(0.0, (sum, e) => sum + e.amount);
    }
  }
}

// Alternative: FutureProvider with auto-refresh
@riverpod
Future<double> groupTotalAlt(Ref ref, String groupId) async {
  // Listen to events to trigger refresh
  ref.listen(
    expenseEventStreamProvider,
    (prev, next) {
      if (next.expense.groupId == groupId) {
        ref.invalidateSelf(); // Trigger recalculation
      }
    },
  );

  final expenses = await ref.watch(
    expensesByGroupProvider(groupId).future
  );
  return expenses.fold(0.0, (sum, e) => sum + e.amount);
}
```

**Architecture Notes:**
- ✅ No Notifiers needed - UI already uses Use Cases correctly
- ✅ Stream providers for queries remain unchanged
- ✅ Computed providers layer on top via events
- ✅ Events provide decoupling between data changes and UI updates

**Next Steps:**
1. Survey existing UI screens to identify needed computed values
2. Implement `groupTotalProvider` as proof of concept
3. Add dashboard providers for statistics
4. Enhance UI feedback for operations

---

### 2.5 Testing & Polish (Week 3-4)

**Goal:** Comprehensive testing and documentation

**Tasks:**
- [ ] **Integration Testing**
  - [ ] Test Use Case → Repository → Event flow
  - [ ] Test event-driven providers
  - [ ] Test realtime sync with events
  - [ ] Test offline scenarios
  - [ ] Multi-device testing

- [ ] **End-to-End Scenarios**
  - [ ] Offline expense creation
  - [ ] Realtime sync across devices
  - [ ] Event-driven dashboard updates
  - [ ] Conflict resolution with events
  - [ ] Queue processing validation

- [ ] **Performance & Polish**
  - [ ] Profile event broker performance (< 1ms per event)
  - [ ] Check for memory leaks
  - [ ] Optimize event filtering
  - [ ] Add comprehensive logging
  - [ ] Code review and cleanup

- [ ] **Documentation**
  - [ ] Add dartdoc comments to public APIs
  - [ ] Document event types and usage
  - [ ] Create quick reference guide
  - [ ] Update inline documentation

---

## Phase 3: Core Features Completion

**Goal:** Complete the minimal working app

### 3.1 Balance Calculations
- [ ] **Calculate balances for a group**
  - [ ] Algorithm: Sum expenses per person
  - [ ] Show who paid what
  - [ ] Show who owes what
  - [ ] Simple list format: "Alice owes Bob $25"

- [ ] **Display in BalancesTab**
  - [ ] Replace empty state
  - [ ] Select group (dropdown)
  - [ ] Show calculated balances
  - [ ] "All settled up" when balanced

- [ ] **Balance Service**
  - [ ] Create `BalanceCalculationService`
  - [ ] Update balances when expenses change (event-driven)
  - [ ] Cache calculations in `GroupBalanceEntity` table
  - [ ] Sync balance data to Firestore

### 3.2 Sync Status UI
- [ ] **Sync status indicator**
  - [ ] Show sync icon in app bar
  - [ ] Display unsynced count
  - [ ] Manual "Sync Now" button
  - [ ] Error state handling

### 3.3 Group Invitations
- [ ] Share group code or link
- [ ] Accept/decline invitations
- [ ] Add members to existing groups
- [ ] See expenses created by other members

---

## Phase 4: Enhanced UX

**Goal:** Make the app delightful to use

- [ ] Expense categories with icons
- [ ] Custom split options (percentage, exact amounts)
- [ ] Edit/delete expenses UI
- [ ] Expense detail screen with history
- [ ] Search and filter expenses
- [ ] Date range selection
- [ ] Receipt photo attachment

---

## Phase 5: Settlement & Payments

**Goal:** Help users settle debts efficiently

- [ ] Optimize settlements (minimize transactions)
- [ ] Mark settlements as paid
- [ ] Settlement history
- [ ] Payment reminders
- [ ] Settlement suggestions

---

## Phase 6: Advanced Features

**Goal:** Power user features

- [ ] Multi-currency support with conversion
- [ ] Recurring expenses
- [ ] Expense templates
- [ ] Data export (CSV, PDF)
- [ ] Expense reports and analytics
- [ ] Push notifications
- [ ] Widgets for quick expense entry

---

## Technical Debt & Quality

**Address throughout development**

- [ ] **Testing**
  - [x] Unit tests for EventBroker (8 tests passing)
  - [ ] Unit tests for all Use Cases (>90% coverage)
  - [ ] Unit tests for repositories
  - [ ] Widget tests for key screens
  - [ ] Integration tests for sync flow
  - [ ] E2E tests for critical paths

- [ ] **Code Quality**
  - [x] Architectural pattern established
  - [x] SRP followed (one class per file)
  - [x] No barrel files
  - [ ] No cyclic dependencies
  - [ ] All public APIs documented

- [ ] **Infrastructure**
  - [ ] Implement proper error boundaries
  - [ ] Add analytics/crash reporting
  - [ ] Performance optimization (lazy loading, pagination)
  - [ ] Accessibility improvements
  - [ ] Localization (i18n)
  - [ ] Onboarding flow
  - [ ] App icon and splash screen

---

## Architecture Principles (v2.2)

### Clean Architecture Layers

**Domain Layer** (`lib/features/*/domain/`)
- Pure business logic (entities, repositories, use cases)
- No dependencies on infrastructure
- Repository interfaces only

**Data Layer** (`lib/features/*/data/`)
- Repository implementations
- DAOs and data sources
- Firestore services
- Handles sync and events

**Presentation Layer** (`lib/features/*/presentation/`)
- UI components (screens, widgets)
- State management (Riverpod providers)
- Calls Use Cases, never repositories directly

**Core Layer** (`lib/core/`)
- Shared utilities (events, logging, database)
- Cross-cutting concerns

### Error Handling Pattern

**Use Cases:**
- Handle ALL validation and error wrapping
- Return `Result<T>` (Success or Failure)
- Wrap repository calls in try-catch blocks
- Provide logging via inherited `LoggerMixin`

**Repositories:**
- Focus solely on data operations
- Throw exceptions directly (no Result wrapping)
- Fire events after successful operations
- Maintain atomic transactions

**Benefits:**
- ✅ Single Responsibility: Repositories do data, Use Cases handle business logic
- ✅ Clean Interfaces: Simple return types, no Result wrapping in repos
- ✅ Consistent Error Handling: All errors flow through Use Cases uniformly

### Event-Driven Architecture

**Events:**
- Fired by repositories after successful operations
- Broadcast via singleton `EventBroker`
- Used for reactive UI updates
- Fire for BOTH local and remote changes

**Providers:**
- Can react to events for real-time updates
- Multiple providers can listen to same events
- Event-driven state management

---

## Success Metrics

### Phase 2 Completion Criteria
1. ✅ Event infrastructure working
2. ✅ Base UseCase pattern established
3. ✅ 5 expense use cases implemented
4. ⏳ 5 group use cases implemented
5. ⏳ All repositories fire events
6. ⏳ Realtime sync fires events
7. ⏳ Providers use Use Cases exclusively
8. ⏳ >90% test coverage on Use Cases

### Quality Metrics
- ✅ All unit tests passing
- ⏳ < 1ms overhead per event
- ⏳ No memory leaks detected
- ⏳ < 1 second realtime sync latency
- ✅ Clean, documented codebase

### User Experience
- ✅ User can create an expense and see it in the list
- ✅ User can create a group
- ⏳ User can see balances for a group
- ✅ Expenses sync to Firebase when online
- ✅ App works completely offline
- ✅ No crashes in basic flow
- ✅ Can sign out and sign back in without data loss

**Status:** 7 of 8 core features complete. Balance calculations pending.

---

## Non-Goals (For Now)

Things we're explicitly NOT doing yet:

- ❌ Complex split algorithms (by income, by consumption)
- ❌ Integration with payment platforms (Venmo, PayPal)
- ❌ AI-powered expense categorization
- ❌ Receipt OCR/scanning
- ❌ Web app or desktop versions
- ❌ Social features (comments, likes, activity feed)
- ❌ Gamification
- ❌ Premium/subscription tiers

---

## Next Immediate Actions

**Start here** 👇

### 1. Complete Phase 1 Use Cases
- Create 5 group use cases with validation
- Create Riverpod providers for all use cases
- Write unit tests (>90% coverage goal)

### 2. Repository Integration
- Inject EventBroker into repositories
- Fire events after successful operations
- Update DAOs with sync event firing

### 3. Presentation Layer
- Refactor notifiers to use Use Cases
- Remove direct repository calls
- Create event-driven providers

**One feature at a time. Make it work, test it, then move on.**

---

## Development Guidelines

### Standard Pattern for All Features

```dart
// 1. Create Use Case
class CreateFeatureUseCase extends UseCase<Input, Output> {
  final FeatureRepository _repository;

  CreateFeatureUseCase(this._repository);

  @override
  Future<Result<Output>> call(Input input) async {
    log.d('Creating feature: $input');

    // Validation
    if (input.isInvalid) {
      return Failure(Exception('Invalid input'));
    }

    // Execute and handle errors
    try {
      final result = await _repository.createFeature(input);
      return Success(result);
    } catch (e) {
      log.e('Error creating feature: $e');
      return Failure(Exception('Failed to create feature'));
    }
  }
}

// 2. Repository fires event
class SyncedFeatureRepository implements FeatureRepository {
  final AppDatabase _database;
  final EventBroker _eventBroker;

  @override
  Future<Output> createFeature(Input input) async {
    await _database.transaction(() async {
      await _database.featureDao.insert(input);
      await _database.syncDao.enqueueOperation(...);
    });

    _eventBroker.fire(FeatureCreated(result));
    return result; // Throws on error
  }
}

// 3. Provider calls Use Case
class FeatureNotifier extends _$FeatureNotifier {
  Future<void> createFeature(Input input) async {
    state = const AsyncLoading();

    final useCase = ref.read(createFeatureUseCaseProvider);
    final result = await useCase.call(input);

    result.fold(
      (_) => state = const AsyncData(null),
      (error) => state = AsyncError(error, StackTrace.current),
    );
  }
}
```

### Code Style
- ✅ One class per file (SRP)
- ✅ No barrel files (direct imports)
- ✅ Extensions stay with base class
- ✅ Concise comments (code should be self-documenting)
- ✅ LoggerMixin for logging in Use Cases and Repositories

---

## Resources

- [REALTIME_SYNC_ARCHITECTURE.md](./REALTIME_SYNC_ARCHITECTURE.md) - Complete architecture documentation
- [IMPLEMENTATION_PLAN_V2_2.md](./IMPLEMENTATION_PLAN_V2_2.md) - Detailed implementation phases
- [ARCHITECTURE_INTEGRATION_V2_2.md](./ARCHITECTURE_INTEGRATION_V2_2.md) - Visual diagrams and flows
- [DATABASE_SCHEMA.md](./DATABASE_SCHEMA.md) - Schema v5 documentation

---

**Remember:** Build minimally, test thoroughly, iterate quickly. Focus on completing Phase 2.2 architecture before adding new features.
