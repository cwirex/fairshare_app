# FairShare Implementation Plan v2.2
## Use Cases & Event-Driven Architecture - Complete Implementation

**Created:** 2025-10-10
**Status:** Ready for Implementation
**Approach:** Clean slate implementation (no backward compatibility needed)

---

## Executive Summary

This document outlines the implementation plan for building the complete v2.2 architecture with **Use Case Layer** and **Command/Event Pattern** fully integrated with realtime sync. Since the system is not yet in production, we implement the entire architecture cleanly without backward compatibility concerns.

**Strategy:** Build the complete architecture correctly from the start

**Benefits:**
- ✅ **Separation of Concerns**: Business logic isolated in Use Cases
- ✅ **Testability**: Each component can be tested in isolation
- ✅ **Maintainability**: Clear responsibility boundaries
- ✅ **Scalability**: Easy to add new event listeners and features
- ✅ **Reactive State**: Event-driven updates across the application
- ✅ **Clean Codebase**: No legacy patterns or migration code

---

## What's New in v2.2

### 1. Use Case Layer (Interactors)

**Location:** `lib/features/*/domain/use_cases/`

**Purpose:** Encapsulate business logic for specific user actions

**Key Characteristics:**
- One class per business operation (e.g., `CreateExpenseUseCase`)
- Contains validation and business rules
- Depends only on repository interfaces (domain layer)
- Returns `Result<T>` for error handling
- Called by Presentation Layer (Providers)

**Example:**
```dart
class CreateExpenseUseCase {
  final ExpenseRepository _repository;

  CreateExpenseUseCase(this._repository);

  Future<Result<ExpenseEntity>> call(ExpenseEntity expense) async {
    // Validation
    if (expense.amount <= 0) {
      return Failure(ValidationException('Amount must be positive'));
    }

    // Delegate to repository
    return await _repository.createExpense(expense);
  }
}
```

### 2. Event Broker (Event Bus)

**Location:** `lib/core/events/`

**Purpose:** Broadcast domain events to multiple listeners

**Key Characteristics:**
- Singleton service with broadcast stream
- Events fired after successful operations
- Supports filtered streams by event type
- Integrates with both local and sync operations

**Example:**
```dart
// Define events
class ExpenseCreated extends AppEvent {
  final ExpenseEntity expense;
  ExpenseCreated(this.expense);
}

// Fire event
_eventBroker.fire(ExpenseCreated(expense));

// Listen to events
eventBroker.on<ExpenseCreated>().listen((event) {
  // React to expense creation
});
```

### 3. Complete Flow

```
User Action
  ↓
Provider calls Use Case (Command)
  ↓
Use Case validates & calls Repository
  ↓
Repository: Atomic DB write + Queue entry
  ↓
Repository fires Event
  ↓
Event Broker broadcasts to all listeners
  ↓
Multiple Providers react immediately
  • UI updates
  • Dashboard recalculates totals
  • Activity feed shows new entry
```

---

## Implementation Phases

**Revised Timeline:** 3-4 weeks (aggressive, clean implementation)

**Approach:** Build everything from scratch with the correct architecture

---

### Phase 1: Core Infrastructure (Week 1, Days 1-3)
**Goal:** Event system and Use Case foundation

**Tasks:**
1. ✅ **Event Infrastructure** (Day 1)
   - Create `app_events.dart` with all event types
   - Implement `EventBroker` singleton
   - Create Riverpod providers
   - Unit tests for EventBroker

2. ✅ **Use Case Scaffolding** (Days 2-3)
   - Create all 10 use case files (expenses + groups)
   - Add validation logic to each
   - Create Riverpod providers for use cases
   - Unit tests for each use case

**Deliverables:**
- Complete event system ready to use
- All use cases with validation implemented
- >90% test coverage on use cases
- EventBroker tested and working

**Files Created:**
```
lib/core/events/
  ├── app_events.dart
  ├── event_broker.dart
  └── event_providers.dart

lib/features/expenses/domain/use_cases/
  ├── create_expense_use_case.dart
  ├── update_expense_use_case.dart
  ├── delete_expense_use_case.dart
  ├── get_expense_use_case.dart
  ├── get_expenses_by_group_use_case.dart
  └── expense_use_case_providers.dart

lib/features/groups/domain/use_cases/
  ├── create_group_use_case.dart
  ├── update_group_use_case.dart
  ├── add_member_use_case.dart
  ├── remove_member_use_case.dart
  ├── join_group_by_code_use_case.dart
  └── group_use_case_providers.dart
```

---

### Phase 2: Data Layer with Events (Week 1, Days 4-5 + Week 2, Days 1-2)
**Goal:** Repositories and DAOs fire events, implement complete sync

**Tasks:**
1. ✅ **Update Repository Implementations** (Days 4-5)
   - Refactor `SyncedExpenseRepository` to inject EventBroker
   - Fire events after successful operations
   - Refactor `SyncedGroupRepository` with events
   - Atomic transactions (DB + Queue + Events)
   - Unit tests for repositories

2. ✅ **Update DAOs with Events** (Week 2, Days 1-2)
   - Add EventBroker to `ExpensesDao`
   - Add EventBroker to `GroupsDao`
   - Implement `upsertFromSync()` methods that fire events
   - Implement soft delete methods
   - Integration tests for DAOs

**Deliverables:**
- Repositories fire events on all operations
- DAOs fire events on sync operations
- Soft delete fully implemented
- All tests passing

**Key Pattern:**
```dart
// Repository fires events
Future<Result<ExpenseEntity>> createExpense(ExpenseEntity expense) async {
  await _database.transaction(() async {
    await _database.expensesDao.insertExpense(expense);
    await _database.syncDao.enqueueOperation(...);
  });

  _eventBroker.fire(ExpenseCreated(expense)); // ← Event!
  return Success(expense);
}

// DAO fires events on sync
Future<void> upsertExpenseFromSync(ExpenseEntity expense) async {
  final existing = await getExpenseById(expense.id);

  if (existing == null || expense.updatedAt.isAfter(existing.updatedAt)) {
    await into(expenses).insertOnConflictUpdate(...);

    if (existing == null) {
      _eventBroker.fire(ExpenseCreated(expense)); // ← Event!
    } else {
      _eventBroker.fire(ExpenseUpdated(expense, existing)); // ← Event!
    }
  }
}
```

---

### Phase 3: Realtime Sync Integration (Week 2, Days 3-5)
**Goal:** Complete realtime sync with event firing

**Tasks:**
1. ✅ **Firestore Services** (Day 3)
   - Verify/update snapshot listener implementations
   - Ensure proper error handling
   - Test reconnection logic

2. ✅ **RealtimeSyncService** (Day 4)
   - Verify hybrid listener strategy
   - Ensure calls to DAO `upsertFromSync()` methods
   - Test foreground/background lifecycle
   - Verify events fire correctly on sync

3. ✅ **Upload Queue Service** (Day 5)
   - Verify queue processing with events
   - Test retry logic
   - Ensure proper error handling

**Deliverables:**
- Complete realtime sync working
- Events fire for both local and remote changes
- Hybrid listener strategy implemented
- All sync tests passing

---

### Phase 4: Presentation Layer (Week 3, Days 1-3)
**Goal:** Providers use Use Cases and react to events

**Tasks:**
1. ✅ **Update Notifiers** (Days 1-2)
   - Refactor `ExpenseNotifier` to call Use Cases
   - Refactor `GroupNotifier` to call Use Cases
   - Add proper error handling for validation errors
   - Remove direct repository calls from notifiers

2. ✅ **Create Event-Driven Providers** (Day 3)
   - Create `groupTotalProvider` (event-driven)
   - Create event-driven dashboard providers
   - Optional: Create activity feed provider
   - Test reactive updates

**Deliverables:**
- All notifiers use Use Cases exclusively
- Event-driven providers working
- Validation errors surfaced to UI correctly
- Reactive UI updates via events

**Example:**
```dart
// Notifier calls Use Case
class ExpenseNotifier extends _$ExpenseNotifier {
  Future<void> createExpense(ExpenseEntity expense) async {
    state = const AsyncLoading();

    final useCase = ref.read(createExpenseUseCaseProvider);
    final result = await useCase.call(expense);

    result.fold(
      (_) => state = const AsyncData(null),
      (error) => state = AsyncError(error, StackTrace.current),
    );
  }
}

// Event-driven provider
@riverpod
Stream<double> groupTotal(GroupTotalRef ref, String groupId) {
  final eventBroker = ref.watch(eventBrokerProvider);
  final repository = ref.watch(expenseRepositoryProvider);

  return eventBroker.stream
    .where((event) => event.affectsGroup(groupId))
    .asyncMap((_) async {
      final result = await repository.getExpensesByGroup(groupId);
      return result.fold(
        (expenses) => expenses.fold(0.0, (sum, e) => sum + e.amount),
        (_) => 0.0,
      );
    });
}
```

---

### Phase 5: End-to-End Testing & Polish (Week 3, Days 4-5 + Week 4)
**Goal:** Comprehensive testing and documentation

**Tasks:**
1. ✅ **Integration Testing** (Days 4-5)
   - Test Use Case → Repository → Event flow
   - Test event-driven providers
   - Test realtime sync with events
   - Test offline scenarios
   - Multi-device testing

2. ✅ **End-to-End Scenarios** (Week 4, Days 1-2)
   - Offline expense creation
   - Realtime sync across devices
   - Event-driven dashboard updates
   - Conflict resolution with events
   - Queue processing validation

3. ✅ **Performance & Polish** (Week 4, Days 3-4)
   - Profile event broker performance
   - Check for memory leaks
   - Optimize event filtering
   - Add comprehensive logging
   - Code review and cleanup

4. ✅ **Documentation** (Week 4, Day 5)
   - Update inline documentation
   - Add dartdoc comments to public APIs
   - Document event types and usage
   - Create quick reference guide

**Deliverables:**
- All tests passing (unit, integration, E2E)
- < 1 second realtime sync latency
- No event duplication
- Clean, documented codebase
- Performance validated

---

## Simplified Timeline Summary

**Week 1:**
- Days 1-3: Core infrastructure (Events + Use Cases)
- Days 4-5: Repository refactoring with events

**Week 2:**
- Days 1-2: DAO updates with events
- Days 3-5: Realtime sync integration

**Week 3:**
- Days 1-3: Presentation layer (Providers + Use Cases)
- Days 4-5: Integration testing

**Week 4:**
- Days 1-2: End-to-end testing
- Days 3-4: Performance & polish
- Day 5: Documentation

**Total:** 3-4 weeks for complete implementation

---

## File Structure

```
lib/
├── core/
│   ├── events/                    # NEW
│   │   ├── app_events.dart
│   │   ├── event_broker.dart
│   │   └── event_providers.dart
│   ├── database/
│   └── sync/
├── features/
│   ├── expenses/
│   │   ├── domain/
│   │   │   ├── entities/
│   │   │   ├── repositories/
│   │   │   └── use_cases/        # NEW
│   │   │       ├── create_expense_use_case.dart
│   │   │       ├── update_expense_use_case.dart
│   │   │       ├── delete_expense_use_case.dart
│   │   │       ├── get_expense_use_case.dart
│   │   │       ├── get_expenses_by_group_use_case.dart
│   │   │       └── expense_use_case_providers.dart
│   │   ├── data/
│   │   └── presentation/
│   └── groups/
│       ├── domain/
│       │   ├── entities/
│       │   ├── repositories/
│       │   └── use_cases/        # NEW
│       │       ├── create_group_use_case.dart
│       │       ├── update_group_use_case.dart
│       │       ├── add_member_use_case.dart
│       │       ├── remove_member_use_case.dart
│       │       ├── join_group_by_code_use_case.dart
│       │       └── group_use_case_providers.dart
│       ├── data/
│       └── presentation/
```

---

## Key Design Decisions

### 1. Use Cases are Pure Business Logic

**Decision:** Use Cases only validate and delegate to repositories

**Rationale:**
- Keeps Use Cases simple and testable
- Repositories handle infrastructure concerns (DB, queue, events)
- Clear separation of concerns

### 2. Events Fired at Repository Level

**Decision:** Repositories fire events, not Use Cases

**Rationale:**
- Events represent data changes (both local and sync)
- Sync operations bypass Use Cases but still need events
- Consistent event source regardless of how data changed

### 3. EventBroker is Singleton

**Decision:** One EventBroker instance for entire app

**Rationale:**
- Simplifies event subscription
- No need to pass broker through layers
- Managed by Riverpod for proper lifecycle

### 4. Incremental Migration Strategy

**Decision:** Providers can migrate to Use Cases gradually

**Rationale:**
- Reduces risk of breaking changes
- Can test in production incrementally
- Easy rollback if issues occur

### 5. Events Fire After Success

**Decision:** Events only fire after successful operations

**Rationale:**
- Failed operations shouldn't trigger side effects
- Consistent event semantics
- Easy to reason about event flow

---

## Testing Strategy

### Unit Tests

**Use Cases:**
- Test validation logic in isolation
- Mock repositories
- Test error handling

**Event Broker:**
- Test event firing to multiple listeners
- Test filtered streams
- Test disposal

**Repositories:**
- Test events fire after operations
- Test event payloads are correct
- Test events fire on sync operations

### Integration Tests

**Use Case → Repository → Event:**
- Test complete flow
- Verify events fire correctly
- Test with real database

**Event-Driven Providers:**
- Test providers react to events
- Test multiple providers reacting to same event
- Test event filtering

### End-to-End Tests

**Multi-Device Scenarios:**
- Test events fire on all devices
- Test realtime sync triggers events
- Test event-driven UI updates

---

## Development Guide

### Standard Pattern for All Features

**Always use this pattern when implementing new features:**
```dart
// 1. Create Use Case
class CreatePaymentUseCase {
  final PaymentRepository _repository;

  CreatePaymentUseCase(this._repository);

  Future<Result<PaymentEntity>> call(PaymentEntity payment) async {
    // Validation
    if (payment.amount <= 0) {
      return Failure(ValidationException('Invalid amount'));
    }

    return await _repository.createPayment(payment);
  }
}

// 2. Repository fires event
class SyncedPaymentRepository implements PaymentRepository {
  final AppDatabase _database;
  final EventBroker _eventBroker;

  @override
  Future<Result<PaymentEntity>> createPayment(PaymentEntity payment) async {
    try {
      await _database.transaction(() async {
        await _database.paymentsDao.insertPayment(payment);
        await _database.syncDao.enqueueOperation(/*...*/);
      });

      _eventBroker.fire(PaymentCreated(payment));

      return Success(payment);
    } catch (e) {
      return Failure(Exception('Failed: $e'));
    }
  }
}

// 3. Provider calls Use Case
class PaymentNotifier extends _$PaymentNotifier {
  Future<void> createPayment(PaymentEntity payment) async {
    state = const AsyncLoading();

    final useCase = ref.read(createPaymentUseCaseProvider);
    final result = await useCase.call(payment);

    result.fold(
      (_) => state = const AsyncData(null),
      (error) => state = AsyncError(error, StackTrace.current),
    );
  }
}

// 4. Event-driven provider reacts
@riverpod
Stream<List<PaymentEntity>> recentPayments(RecentPaymentsRef ref) {
  final eventBroker = ref.watch(eventBrokerProvider);
  final repository = ref.watch(paymentRepositoryProvider);

  return eventBroker.on<PaymentCreated>().asyncMap((_) async {
    final result = await repository.getRecentPayments();
    return result.getOrElse([]);
  });
}
```

---

## Performance Considerations

### Event Broker Overhead

**Concern:** Broadcasting events to many listeners

**Mitigation:**
- Use Dart's efficient `StreamController.broadcast()`
- Filter events at subscription time
- No overhead if no listeners

**Expected Impact:** < 1ms per event

### Memory Usage

**Concern:** Event streams kept in memory

**Mitigation:**
- Riverpod manages provider lifecycle
- Streams disposed when providers disposed
- No memory leaks

**Expected Impact:** Negligible (< 1KB per stream)

### Event Duplication

**Concern:** Same event fired multiple times

**Prevention:**
- Events fired only after successful operations
- Repository-level firing (single point)
- DAOs fire only for sync operations

**Monitoring:** Add metrics to track event counts

---

## Risk Mitigation

### Development Approach

Since we're building from scratch:
- ✅ Can test each component thoroughly before integration
- ✅ Can catch issues early in development
- ✅ No migration complexity or legacy code concerns
- ✅ Clean slate for optimal architecture

### Data Safety

- ✅ Upload queue preserves all operations (atomic with DB writes)
- ✅ Local DB remains source of truth
- ✅ Events are side effects only (no data dependency)
- ✅ Transactions ensure data integrity

### Testing Strategy

- Unit test each layer in isolation first
- Integration test combinations before full assembly
- E2E test complete flows before user-facing release
- No production users to impact during development

---

## Success Metrics

### Code Quality
- ✅ 90%+ test coverage on Use Cases
- ✅ 80%+ test coverage on event-driven providers
- ✅ No cyclic dependencies
- ✅ All public APIs documented

### Performance
- ✅ < 1ms overhead per event
- ✅ No memory leaks detected
- ✅ < 1 second realtime sync latency maintained

### Developer Experience
- ✅ Validation errors caught by Use Cases
- ✅ Business logic easy to find and modify
- ✅ New features follow clear patterns
- ✅ Tests run fast (< 1 second for unit tests)

### User Experience
- ✅ UI updates feel instant (event-driven)
- ✅ Multiple screens stay in sync automatically
- ✅ Validation errors are clear and helpful
- ✅ No regressions in existing features

---

## Next Steps

1. ✅ Review this implementation plan with team
2. ⏳ Set up project tracking (create tickets for each phase)
3. ⏳ Start Phase 1: Core Infrastructure (Events + Use Cases)
4. ⏳ Schedule daily standups during implementation
5. ⏳ Weekly demos of completed phases

---

## Questions for Team Discussion

1. **Timeline:** Is 3-4 weeks realistic for our team size?
2. **Parallel Work:** Can we split tasks (one dev on Use Cases, one on Events)?
3. **Testing:** Should we write tests as we go or at the end of each phase?
4. **Monitoring:** What metrics should we track during development?
5. **Documentation:** When should we update inline docs (as we go or at the end)?

---

## Conclusion

Version 2.2 is a complete architectural implementation that combines **Use Cases**, **Event-Driven patterns**, and **Realtime Sync** into a cohesive, production-ready system. Since we're building from scratch, we can implement the architecture correctly from day one without technical debt or migration concerns.

**Recommended Approach:** Build phase by phase, testing thoroughly at each step. Start with Phase 1 (Core Infrastructure) and ensure it's solid before moving forward.

**Risk Assessment:** Low risk because:
- No production users yet
- Clean slate implementation
- Thorough testing at each phase
- Modern architecture patterns proven in industry

**Expected Outcome:**
- ✅ Production-ready architecture in 3-4 weeks
- ✅ Scalable foundation for future features
- ✅ Excellent developer experience
- ✅ Maintainable, testable codebase
- ✅ Reactive, event-driven UI
- ✅ < 1 second realtime sync

---

**Document Status:** ✅ Ready for Implementation
**Timeline:** 3-4 weeks
**Approach:** Clean slate, full v2.2 architecture
**Next Review:** After Phase 1 completion (Week 1)
