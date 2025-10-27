# FairShare Development Plan

**Last Updated:** 2025-10-14
**Philosophy:** Build minimally, test thoroughly, iterate quickly.

---

## Current Status: Phase 2.5 COMPLETE - Ready for Phase 3! 🎉

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

### ✅ Phase 2.4: Event-Driven Providers - COMPLETED (2025-10-27)

**Goal:** Create computed providers that react to events for reactive UI

**Completed Tasks:**
- ✅ **Dashboard Providers** (existing)
  - ✅ `dashboardStatsProvider` - Aggregate stats across all groups
  - ✅ `recentActivityProvider` - Recent 10 changes (expenses/groups)
  - ✅ `totalSpendingProvider` - Total across all groups

**Achievements:**
- ✅ Event-driven provider pattern established
- ✅ Dashboard updates automatically on expense/group events
- ✅ Activity feed tracks all changes in real-time
- ✅ UI architecture complete (Use Cases + Stream Providers + Event-Driven Computed Providers)

---

### ✅ Phase 2.5: Balance Providers & Testing - COMPLETED (2025-10-27)

**Goal:** Implement balance calculations and comprehensive testing

**Completed Tasks:**
- ✅ **Balance Providers**
  - ✅ `groupBalanceProvider(groupId)` - Net balances per member (who owes whom)
  - ✅ `groupSettlementsProvider(groupId)` - Optimal settlement transactions
  - ✅ `groupIsSettledProvider(groupId)` - Boolean for "all settled up" status
  - ✅ `balanceCalculationServiceProvider` - Service singleton

- ✅ **Group Statistics Providers**
  - ✅ `groupTotalSpendingProvider(groupId)` - Sum of expenses per group
  - ✅ `groupExpenseCountProvider(groupId)` - Number of expenses
  - ✅ `groupMemberCountProvider(groupId)` - Number of members
  - ✅ `groupStatsProvider(groupId)` - Aggregate statistics object
  - ✅ `groupAverageExpenseProvider(groupId)` - Average expense amount

- ✅ **Balance Calculation Service**
  - ✅ Net balance algorithm (credits and debits)
  - ✅ Settlement optimization (minimizes transactions using greedy algorithm)
  - ✅ Epsilon handling for floating-point precision
  - ✅ 14 comprehensive tests for edge cases

- ✅ **Provider Testing**
  - ✅ 10 balance provider tests (initial calc, event recalculation, edge cases)
  - ✅ Event filtering verified (only relevant groupId triggers update)
  - ✅ Mock setup with EventBroker and DAOs
  - ✅ Pattern established for future provider tests

- ✅ **Database Enhancement**
  - ✅ Added `getSharesByGroup(groupId)` to ExpenseSharesDao
  - ✅ Efficient JOIN query for balance calculations

**Test Results:**
```
✓ 230/230 tests passing (100%)
├─ Event System: 8 tests
├─ Use Cases: 11 test suites
├─ Repositories: 137+ tests
├─ Sync Services: 12+ tests
├─ Balance Services: 14 tests
├─ Balance Providers: 10 tests ⬅ NEW!
└─ Integration: 2 flows
```

**Achievements:**
- ✅ Complete event-driven provider layer (11 providers total)
- ✅ Balance calculation algorithms implemented and tested
- ✅ Zero regressions (all existing tests still pass)
- ✅ Production-ready code with comprehensive logging
- ✅ Pattern established for testing Riverpod StreamNotifier providers
- ✅ Ready for UI integration in Phase 3

---

### ⏳ 2.6 Remaining Testing & Polish (Optional - Can be done alongside Phase 3)

**Goal:** Complete testing coverage and performance optimization

**Remaining Tasks:**
- [ ] **Provider Testing** (Low Priority - Pattern established)
  - [ ] Group stats provider tests (5 providers)
  - [ ] Dashboard provider tests (3 providers)

- [ ] **Performance Testing** (Medium Priority)
  - [ ] Profile event broker performance (target: < 1ms per event)
  - [ ] Check for memory leaks in providers
  - [ ] Optimize event filtering if needed
  - [ ] Large dataset testing (100+ expenses, 10+ groups)

- [ ] **End-to-End Scenarios** (Medium Priority)
  - [ ] Multi-device realtime sync testing
  - [ ] Offline → Online transition scenarios
  - [ ] Conflict resolution validation
  - [ ] Queue processing under load

- [ ] **Documentation** (Low Priority)
  - [ ] Add dartdoc comments to remaining public APIs
  - [ ] Create provider usage guide for new features
  - [ ] Document testing patterns

**Note:** These tasks can be completed alongside Phase 3 UI work. The core architecture is solid and tested.

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
4. ✅ 6 group use cases implemented
5. ✅ All repositories fire events
6. ✅ Realtime sync fires events
7. ✅ Providers use Use Cases exclusively
8. ✅ Comprehensive test coverage (230 tests passing)

### Quality Metrics
- ✅ All unit tests passing (230/230)
- ✅ Balance calculations implemented and tested
- ⏳ < 1ms overhead per event (not profiled yet)
- ⏳ No memory leaks detected (not tested yet)
- ⏳ < 1 second realtime sync latency (not measured yet)
- ✅ Clean, documented codebase

### User Experience
- ✅ User can create an expense and see it in the list
- ✅ User can create a group
- ✅ Balance calculations work (service + providers implemented)
- ⏳ User can see balances in UI (Phase 3 - UI integration pending)
- ✅ Expenses sync to Firebase when online
- ✅ App works completely offline
- ✅ No crashes in basic flow
- ✅ Can sign out and sign back in without data loss

**Status:** Phase 2 COMPLETE! All 8 core features implemented. Balance UI integration is Phase 3.

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

**Phase 2 COMPLETE! 🎉 Ready for Phase 3** 👇

### Start Phase 3.1: Balance UI Integration

**1. Integrate BalancesTab**
- Wire up `groupBalanceProvider` to display net balances
- Show "who owes whom" with user-friendly formatting
- Use `groupSettlementsProvider` for settlement suggestions
- Display `groupIsSettledProvider` status ("All settled up!")
- Add group selector dropdown

**2. Add Group Statistics to Group Detail Screen**
- Show total spending using `groupTotalSpendingProvider`
- Display expense count with `groupExpenseCountProvider`
- Show member count with `groupMemberCountProvider`
- Consider using `groupStatsProvider` for aggregate display

**3. Enhance Dashboard (Optional)**
- Integrate `dashboardStatsProvider` for app-wide metrics
- Show `recentActivityProvider` in activity feed
- Display `totalSpendingProvider` in dashboard header

**Timeline:** Balance Tab (2-3 hours), Group Stats (1-2 hours), Dashboard (1-2 hours)

**One feature at a time. Make it work, test it visually, then move on.**

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
