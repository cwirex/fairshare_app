# FairShare Real-Time Sync Architecture

**Version:** 2.1
**Status:** Design Proposal - Team Reviewed
**Last Updated:** 2025-10-09
**Author:** Development Team
**Review Status:** ✅ Approved with Refinements

---

## Table of Contents

1. [Team Review Decisions](#team-review-decisions)
2. [Executive Summary](#executive-summary)
3. [Architecture Principles](#architecture-principles)
4. [Clean Architecture Layers](#clean-architecture-layers)
5. [Design Patterns](#design-patterns)
6. [Component Architecture](#component-architecture)
7. [Data Flow](#data-flow)
8. [Real-Time Sync Mechanism](#real-time-sync-mechanism)
9. [Conflict Resolution](#conflict-resolution)
10. [Implementation Plan](#implementation-plan)
11. [Migration from Current Architecture](#migration-from-current-architecture)
12. [Testing Strategy](#testing-strategy)
13. [Performance Considerations](#performance-considerations)
14. [Security Considerations](#security-considerations)

---

## Team Review Decisions

**Review Date:** 2025-10-09
**Overall Rating:** 9/10 ⭐️
**Status:** ✅ Approved for Implementation with Key Refinements

### Critical Improvements Made

#### 1. ✅ Hybrid Listener Strategy (Cost & Battery Optimization)

**Problem Identified:** Original design could open dozens of listeners simultaneously (one per group), causing:
- High Firestore connection costs
- Excessive battery drain
- Increased memory usage
- Unnecessary network overhead for groups user isn't actively viewing

**Solution Adopted: "Single Collection Listener + Active View Listener"**

**How It Works:**
```
┌─────────────────────────────────────────────────────────┐
│ Tier 1: Global Groups Listener (Always Active)         │
│ - ONE listener on user's groups collection              │
│ - Watches for group metadata changes                    │
│ - Tracks lastActivityAt timestamp per group             │
│ - Low cost: 1 listener, minimal data transfer           │
└─────────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────┐
│ Tier 2: Active Group Listener (On-Demand)              │
│ - ONE listener for currently viewed group               │
│ - Full real-time updates for expenses/members           │
│ - Activated when user opens group screen                │
│ - Deactivated when user navigates away                  │
│ - Premium experience exactly where it matters           │
└─────────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────┐
│ Tier 3: On-Demand Refresh (Pull When Needed)           │
│ - When lastActivityAt changes for inactive group        │
│ - One-time get() call to fetch latest data              │
│ - UI shows "New activity" badge                         │
│ - Data fetched when user opens that group               │
└─────────────────────────────────────────────────────────┘
```

**Implementation Example:**
```dart
class RealtimeSyncService {
  // Tier 1: Always active when app is foregrounded
  StreamSubscription? _groupsListener;

  // Tier 2: Only for currently active group
  StreamSubscription? _activeGroupExpensesListener;
  String? _activeGroupId;

  // Start global groups listener
  Future<void> startRealtimeSync(String userId) async {
    _groupsListener = _firestoreService
        .watchUserGroups(userId)
        .listen((groups) async {
          for (final group in groups) {
            await _database.upsertGroupFromSync(group);

            // Check if lastActivityAt changed
            if (_hasNewActivity(group)) {
              // Show badge, but don't fetch data yet
              await _markGroupAsUpdated(group.id);
            }
          }
        });
  }

  // Activate listener for specific group
  void listenToActiveGroup(String groupId) {
    // Cancel previous active listener
    _activeGroupExpensesListener?.cancel();
    _activeGroupId = groupId;

    // Start new listener for this group
    _activeGroupExpensesListener = _firestoreService
        .watchGroupExpenses(groupId)
        .listen((expenses) async {
          for (final expense in expenses) {
            await _database.upsertExpenseFromSync(expense);
          }
        });
  }

  // Stop active group listener
  void stopListeningToActiveGroup() {
    _activeGroupExpensesListener?.cancel();
    _activeGroupExpensesListener = null;
    _activeGroupId = null;
  }
}
```

**Benefits:**
- ✅ Cost: 1-2 active listeners instead of 10-50+
- ✅ Battery: Minimal WebSocket connections
- ✅ Performance: Real-time where it matters (active view)
- ✅ UX: Instant updates for current screen, smart notifications for others

**Firestore Schema Update Required:**
```dart
// Add to Group document
class GroupEntity {
  final String id;
  final String displayName;
  final DateTime lastActivityAt; // NEW FIELD
  // ... other fields
}

// Update this field on every group activity:
// - Expense created/updated/deleted
// - Member added/removed
// - Group settings changed
```

#### 2. ✅ Server-Side Timestamps for Conflict Resolution

**Problem Identified:** Client-side timestamps (`updatedAt = DateTime.now()`) are vulnerable to:
- Device clock skew (user's clock is wrong)
- Timezone issues
- Concurrent edits with same timestamp
- Unreliable "Last Write Wins" behavior

**Solution: Use Firestore `FieldValue.serverTimestamp()`**

**Implementation:**
```dart
// In UploadQueueService
Future<void> _processExpenseUpdate(SyncQueueData operation) async {
  final expense = await _database.getExpenseById(operation.entityId);

  // Upload to Firestore with server timestamp
  await _firestore
      .collection('groups')
      .doc(expense.groupId)
      .collection('expenses')
      .doc(expense.id)
      .set({
        'title': expense.title,
        'amount': expense.amount,
        // ... other fields
        'updatedAt': FieldValue.serverTimestamp(), // ✅ Server sets this
      });

  // IMPORTANT: Wait for Firestore to return the actual timestamp
  // Then update local DB with server's timestamp
  final doc = await _firestore
      .collection('groups')
      .doc(expense.groupId)
      .collection('expenses')
      .doc(expense.id)
      .get();

  final serverUpdatedAt = (doc.data()!['updatedAt'] as Timestamp).toDate();

  // Update local DB with authoritative server timestamp
  await _database.updateExpenseTimestamp(expense.id, serverUpdatedAt);
}
```

**Benefits:**
- ✅ Reliable conflict resolution (server clock is authoritative)
- ✅ Deterministic behavior across all devices
- ✅ No timezone issues
- ✅ Firestore's atomic guarantees

#### 3. ✅ Atomic Database Transactions

**Problem Identified:** Repository operations that write to both local DB and queue are NOT atomic:
```dart
// ❌ BEFORE: Two separate operations - can fail between them
await _database.insertExpense(expense);       // Operation 1
await _database.enqueueOperation(/* ... */);  // Operation 2
// If app crashes here, expense is in DB but not queued for upload!
```

**Solution: Wrap in Drift transaction**

**Implementation:**
```dart
// ✅ AFTER: Single atomic transaction
class SyncedExpenseRepository {
  Future<Result<ExpenseEntity>> createExpense(ExpenseEntity expense) async {
    try {
      await _database.transaction(() async {
        // Both operations succeed or both fail
        await _database.insertExpense(expense);
        await _database.enqueueOperation(
          entityType: 'expense',
          entityId: expense.id,
          operationType: 'create',
          metadata: expense.groupId,
        );
      });

      return Success(expense);
    } catch (e) {
      return Failure(Exception('Failed to create expense: $e'));
    }
  }
}
```

**Benefits:**
- ✅ Data integrity: All-or-nothing operations
- ✅ No orphaned data
- ✅ Crash-safe
- ✅ Consistent state always

#### 4. ✅ Foreground-Only Listeners

**Decision:** Real-time listeners are ONLY active when app is in foreground.

**Rationale:**
- Background listeners drain battery significantly
- Firestore SDK has excellent catch-up mechanism on resume
- User doesn't notice 1-second delay when opening app

**Implementation:**
```dart
class SyncService {
  void startAutoSync(String? userId) {
    // Listen to app lifecycle
    WidgetsBinding.instance.addObserver(_lifecycleObserver);

    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((results) {
      final isOnline = results.any((r) => r != ConnectivityResult.none);

      if (isOnline && _isAppInForeground && userId != null) {
        _realtimeSyncService.startRealtimeSync(userId);
      } else {
        _realtimeSyncService.stopRealtimeSync();
      }
    });
  }

  void _onAppLifecycleStateChanged(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _isAppInForeground = true;
        if (_isOnline && _currentUserId != null) {
          _realtimeSyncService.startRealtimeSync(_currentUserId!);
        }
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        _isAppInForeground = false;
        _realtimeSyncService.stopRealtimeSync();
        break;
    }
  }
}
```

#### 5. ✅ UX Enhancement: Conflict Notifications

**Problem:** LWW can silently overwrite user's local edits, feeling like a bug.

**Solution:** Non-blocking notification when conflict occurs.

**Implementation:**
```dart
// In app_database.dart
Future<void> upsertExpenseFromSync(ExpenseEntity remoteExpense) async {
  final local = await getExpenseById(remoteExpense.id);

  if (local != null && remoteExpense.updatedAt.isAfter(local.updatedAt)) {
    // Remote is newer - check if local has unsynced changes
    final hasUnsyncedChanges = await _hasUnsyncedChanges(remoteExpense.id);

    if (hasUnsyncedChanges) {
      // Conflict: User's local edit will be overwritten
      // Emit event for UI to show notification
      _conflictController.add(ConflictEvent(
        entityType: 'expense',
        entityId: remoteExpense.id,
        localVersion: local,
        remoteVersion: remoteExpense,
      ));
    }

    // Update to remote version (LWW)
    await (update(expenses)..where((e) => e.id.equals(remoteExpense.id)))
        .write(/* ... */);
  }
}
```

**UI Layer:**
```dart
// Listen to conflicts
ref.listen(conflictEventsProvider, (previous, next) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('This expense was just updated by another user'),
      backgroundColor: Colors.orange,
      action: SnackBarAction(
        label: 'View',
        onPressed: () { /* Navigate to expense */ },
      ),
    ),
  );
});
```

#### 6. ✅ Multi-Entity Transaction Handling

**Problem:** How to reliably handle operations that affect multiple entities (e.g., deleting a group + all its expenses)?

**Solution: Single queue entry with expansion logic**

**Implementation:**
```dart
// Repository: Single queue entry for complex operation
Future<Result<void>> deleteGroup(String id) async {
  try {
    await _database.transaction(() async {
      // Soft delete group
      await _database.softDeleteGroup(id);

      // Single queue entry represents entire operation
      await _database.enqueueOperation(
        entityType: 'group',
        entityId: id,
        operationType: 'delete',
        metadata: jsonEncode({
          'deleteExpenses': true,
          'deleteMembers': true,
        }),
      );
    });

    return Success.unit();
  } catch (e) {
    return Failure(Exception('Failed to delete group: $e'));
  }
}

// UploadQueueService: Expand to multiple Firestore operations
Future<void> _processGroupDelete(SyncQueueData operation) async {
  final metadata = jsonDecode(operation.metadata!);
  final group = await _database.getGroupById(operation.entityId, includeDeleted: true);

  // Use Firestore batch for atomic multi-doc operation
  final batch = _firestore.batch();

  // Delete group document
  batch.delete(_firestore.collection('groups').doc(group.id));

  // Delete all expenses
  if (metadata['deleteExpenses'] == true) {
    final expenses = await _database.getExpensesByGroup(group.id, includeDeleted: true);
    for (final expense in expenses) {
      batch.delete(
        _firestore
            .collection('groups')
            .doc(group.id)
            .collection('expenses')
            .doc(expense.id),
      );
    }
  }

  // Delete all members
  if (metadata['deleteMembers'] == true) {
    final members = await _database.getAllGroupMembers(group.id);
    for (final member in members) {
      batch.delete(
        _firestore
            .collection('groups')
            .doc(group.id)
            .collection('members')
            .doc(member.userId),
      );
    }
  }

  // Commit all deletes atomically
  await batch.commit();

  // Hard delete locally after successful upload
  await _database.hardDeleteGroup(group.id);
}
```

### Architecture Rating: 9/10 → 10/10

With these refinements, the architecture is now **production-ready** with:
- ✅ Scalability: Minimal listener overhead
- ✅ Reliability: Atomic operations, server timestamps
- ✅ Cost-efficiency: Optimized for Firestore pricing
- ✅ Battery-efficiency: Foreground-only listeners
- ✅ UX Excellence: Real-time where it matters + conflict notifications
- ✅ Data Integrity: Transactions everywhere
- ✅ Maintainability: Clean, simple, single-responsibility components

### Key Metrics to Track Post-Launch

1. **Sync Performance**
   - Average sync latency (target: < 1s for active views)
   - Queue depth over time (target: < 10 pending operations)
   - Failed upload retry rate (target: < 1%)

2. **Cost Management**
   - Firestore reads per user per day (target: < 500)
   - Firestore writes per user per day (target: < 200)
   - Active listener count (target: 1-2 per user)

3. **User Experience**
   - Conflict frequency (target: < 0.1% of operations)
   - App crash rate during sync operations (target: 0%)
   - Battery drain increase (target: < 5% over baseline)

---

## Executive Summary

### Current State (v1.0)
- **Offline-first** architecture with periodic sync (30-second polling)
- Local database (Drift/SQLite) as single source of truth for UI
- Upload queue for reliable, retryable uploads
- Download sync triggered periodically or manually

### Proposed State (v2.1)
- **Offline-first with real-time sync** using Firestore listeners
- **Hybrid listener strategy:** Single collection listener + active view listener
- Maintains Local DB as single source of truth
- Upload remains queue-based (reliable, retryable)
- Download becomes event-driven (< 1 second latency for active views)
- **Server-side timestamps** for reliable conflict resolution
- **Atomic database transactions** for data integrity
- Clean Architecture with strict layer separation
- Simple, maintainable components with single responsibilities

### Key Benefits
- ✅ True real-time collaboration (< 1 second sync for active views)
- ✅ Cost-optimized: Minimal listener overhead (1-2 active listeners max)
- ✅ Battery-efficient: Foreground-only listeners
- ✅ Clean Architecture compliance
- ✅ Simplified components (easier to test and maintain)
- ✅ Better separation of concerns
- ✅ Offline-first remains intact
- ✅ No breaking changes to UI layer
- ✅ Production-ready data integrity with atomic operations

---

## Architecture Principles

### 1. Offline-First
**Definition:** The application works fully offline, with data syncing transparently in the background when online.

**Implementation:**
- Local database is the single source of truth for UI
- All write operations happen to local DB first
- UI updates instantly without waiting for network
- Sync happens asynchronously in the background

**User Experience:**
```
User Action → Local DB (0ms) → UI Update (instant)
                     ↓
            Background Upload Queue
                     ↓
                 Firestore (eventually)
```

### 2. Clean Architecture
**Definition:** Strict separation of concerns with dependency rules flowing inward.

**Layer Rules:**
- Domain layer has NO dependencies on outer layers
- Data layer implements Domain interfaces
- Presentation layer depends ONLY on Domain layer
- Infrastructure details (Firestore, Drift) hidden in Data layer

### 3. Single Responsibility Principle (SRP)
**Definition:** Each class has one clear, well-defined responsibility.

**Applied To:**
- Repositories: Local DB + Queue coordination only
- SyncService: Orchestrate upload queue processing
- RealtimeSyncService: Manage Firestore listeners only
- UploadQueueService: Process queued operations only

### 4. Keep It Simple (KISS)
**Definition:** Prefer simple solutions over complex ones.

**Examples:**
- Use database constraints instead of manual duplicate checks
- Use soft delete pattern instead of complex metadata
- Let database handle conflict resolution where possible
- Minimal abstractions, maximal clarity

### 5. Eventual Consistency
**Definition:** Data will be consistent across devices eventually, not immediately.

**Implementation:**
- Upload queue ensures local changes reach Firestore
- Real-time listeners ensure remote changes reach local DB
- Last Write Wins (LWW) conflict resolution
- Accept temporary inconsistencies during network issues

---

## Clean Architecture Layers

### Layer 1: Domain Layer (Business Logic)
**Location:** `lib/features/*/domain/`

**Components:**
- **Entities:** Pure data models (e.g., `GroupEntity`, `ExpenseEntity`)
- **Repository Interfaces:** Abstract contracts (e.g., `GroupRepository`)
- **Use Cases:** Business logic operations (future enhancement)

**Rules:**
- ✅ NO dependencies on other layers
- ✅ NO Flutter/Dart framework dependencies
- ✅ Pure business logic only
- ✅ Can be tested without any infrastructure

**Example:**
```dart
// Pure domain entity
class GroupEntity {
  final String id;
  final String displayName;
  final DateTime createdAt;
  final DateTime updatedAt;
  // No database annotations, no JSON serialization
}

// Pure repository interface
abstract class GroupRepository {
  Future<Result<GroupEntity>> createGroup(GroupEntity group);
  Future<Result<GroupEntity>> getGroupById(String id);
  Stream<List<GroupEntity>> watchUserGroups(String userId);
}
```

### Layer 2: Data Layer (Implementation)
**Location:** `lib/features/*/data/`

**Components:**
- **Repositories:** Implement domain interfaces
- **Data Sources:** Database DAOs, Firestore services
- **Services:** Sync services, queue services
- **Mappers:** Convert between entities and DTOs

**Rules:**
- ✅ Implements Domain interfaces
- ✅ Can depend on external frameworks (Drift, Firestore, Firebase)
- ✅ Handles data transformation
- ✅ Manages technical details (caching, network, persistence)

**Example:**
```dart
// Repository implementation
class SyncedGroupRepository implements GroupRepository {
  final AppDatabase _database;  // Data source

  @override
  Future<Result<GroupEntity>> createGroup(GroupEntity group) async {
    // 1. Write to local DB
    await _database.insertGroup(group);

    // 2. Enqueue for sync
    await _database.enqueueOperation(
      entityType: 'group',
      entityId: group.id,
      operationType: 'create',
    );

    // 3. Return immediately (offline-first)
    return Success(group);
  }
}
```

### Layer 3: Presentation Layer (UI)
**Location:** `lib/features/*/presentation/`

**Components:**
- **Screens/Widgets:** Flutter UI components
- **Providers:** State management (Riverpod)
- **View Models:** Presentation logic (if needed)

**Rules:**
- ✅ Depends ONLY on Domain layer
- ✅ Uses repository interfaces, not implementations
- ✅ Watches streams from repositories
- ✅ NO direct database or Firestore calls

**Example:**
```dart
// Provider watching repository stream
@Riverpod(keepAlive: true)
Stream<List<GroupEntity>> userGroups(UserGroupsRef ref, String userId) async* {
  final repository = ref.watch(groupRepositoryProvider);  // Domain interface

  // Watch local DB stream - automatically updates on changes
  await for (final groups in repository.watchUserGroups(userId)) {
    yield groups;
  }
}
```

---

## Design Patterns

### 1. Repository Pattern
**Purpose:** Abstract data access logic from business logic.

**Implementation:**
```dart
// Domain defines the contract
abstract class ExpenseRepository {
  Future<Result<ExpenseEntity>> createExpense(ExpenseEntity expense);
  Stream<List<ExpenseEntity>> watchExpensesByGroup(String groupId);
}

// Data implements the contract
class SyncedExpenseRepository implements ExpenseRepository {
  final AppDatabase _database;

  @override
  Future<Result<ExpenseEntity>> createExpense(ExpenseEntity expense) async {
    // Coordinate: Local DB + Upload Queue
    await _database.insertExpense(expense);
    await _database.enqueueOperation(/* ... */);
    return Success(expense);
  }
}
```

**Benefits:**
- ✅ UI doesn't know about database implementation
- ✅ Easy to swap data sources (e.g., for testing)
- ✅ Clear separation of concerns

### 2. Queue Pattern (Upload)
**Purpose:** Ensure reliable, retryable data uploads.

**Implementation:**
```dart
class UploadQueueService {
  Future<void> processQueue() async {
    final operations = await _database.getPendingOperations();

    for (final operation in operations) {
      try {
        await _processOperation(operation);
        await _database.removeQueuedOperation(operation.id);
      } catch (e) {
        await _database.markOperationFailed(operation.id, e.toString());
      }
    }
  }
}
```

**Benefits:**
- ✅ Offline resilience: Operations queued when offline
- ✅ Retry logic: Failed operations can be retried
- ✅ No data loss: Operations persisted to database
- ✅ Ordered processing: FIFO queue ensures consistency

### 3. Observer Pattern (Real-Time Sync)
**Purpose:** React to remote data changes in real-time.

**Implementation:**
```dart
class RealtimeSyncService {
  StreamSubscription? _groupsListener;

  void startRealtimeSync(String userId) {
    _groupsListener = _firestoreService
        .watchUserGroups(userId)  // Firestore snapshot listener
        .listen((remoteGroups) async {
          // Update local DB when remote changes
          for (final group in remoteGroups) {
            await _database.upsertGroupFromSync(group);
          }
        });
  }
}
```

**Benefits:**
- ✅ Real-time updates: < 1 second latency
- ✅ Automatic reconnection: Firestore handles connection lifecycle
- ✅ Efficient: Only changed documents trigger events

### 4. Soft Delete Pattern
**Purpose:** Preserve data until successful upload.

**Implementation:**
```dart
// Repository
Future<Result<void>> deleteExpense(String id) async {
  // Soft delete: Mark as deleted, don't remove
  await _database.softDeleteExpense(id);

  // Queue for upload
  await _database.enqueueOperation(
    entityType: 'expense',
    entityId: id,
    operationType: 'delete',
  );

  return Success.unit();
}

// Upload Queue Service
Future<void> _processExpenseDelete(SyncQueueData operation) async {
  // Entity still exists (soft deleted), can access all fields
  final expense = await _database.getExpenseById(
    operation.entityId,
    includeDeleted: true,
  );

  // Upload deletion to Firestore
  await _firestoreService.deleteExpense(expense.groupId, expense.id);

  // Hard delete after successful upload
  await _database.hardDeleteExpense(expense.id);
}
```

**Benefits:**
- ✅ No metadata complexity
- ✅ Can retry failed deletes
- ✅ Safer: Data preserved until confirmed deleted remotely
- ✅ Simpler code

### 5. Stream Pattern (Reactive UI)
**Purpose:** UI automatically updates when data changes.

**Implementation:**
```dart
// Database provides streams
Stream<List<ExpenseEntity>> watchExpensesByGroup(String groupId) {
  return select(expenses)
    ..where((e) => e.groupId.equals(groupId))
    .watch()  // Drift automatically emits on changes
    .map((rows) => rows.map(_expenseFromDb).toList());
}

// Provider exposes stream to UI
@Riverpod(keepAlive: true)
Stream<List<ExpenseEntity>> groupExpenses(
  GroupExpensesRef ref,
  String groupId,
) async* {
  final repository = ref.watch(expenseRepositoryProvider);
  await for (final expenses in repository.watchExpensesByGroup(groupId)) {
    yield expenses;
  }
}

// UI automatically rebuilds on stream changes
Widget build(BuildContext context, WidgetRef ref) {
  final expensesAsync = ref.watch(groupExpensesProvider(groupId));

  return expensesAsync.when(
    data: (expenses) => ExpenseList(expenses),
    loading: () => CircularProgressIndicator(),
    error: (e, st) => ErrorWidget(e),
  );
}
```

**Benefits:**
- ✅ Automatic UI updates: No manual refresh needed
- ✅ Single source of truth: UI always reflects database state
- ✅ Declarative: UI describes what to show, not how to update

---

## Component Architecture

### Overview Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    Presentation Layer                        │
│                  (Widgets + Providers)                       │
└────────────────────┬────────────────────────────────────────┘
                     │ Depends on
                     ↓
┌─────────────────────────────────────────────────────────────┐
│                     Domain Layer                             │
│            (Entities + Repository Interfaces)                │
└──────────────────────────┬──────────────────────────────────┘
                           ↑ Implemented by
┌──────────────────────────┴──────────────────────────────────┐
│                      Data Layer                              │
│                                                               │
│  ┌─────────────────────────────────────────────────────┐   │
│  │           Repositories (Coordination)                │   │
│  │  • SyncedGroupRepository                            │   │
│  │  • SyncedExpenseRepository                          │   │
│  └────────┬───────────────────────────┬─────────────────┘   │
│           │                            │                     │
│           ↓                            ↓                     │
│  ┌─────────────────┐         ┌──────────────────┐          │
│  │  Local Database │         │  Upload Queue    │          │
│  │   (Drift/SQLite)│         │    Service       │          │
│  └────────┬────────┘         └────────┬─────────┘          │
│           │                            │                     │
│           │ Read/Write                 │ Uploads             │
│           │                            ↓                     │
│           │                  ┌─────────────────────┐        │
│           │                  │  Firestore Services │        │
│           │                  │  • GroupService     │        │
│           │                  │  • ExpenseService   │        │
│           │                  └──────┬──────────────┘        │
│           │                         │                        │
│           │                         ↓                        │
│           │              ┌───────────────────────┐          │
│           │              │   Cloud Firestore     │          │
│           │              └──────┬────────────────┘          │
│           │                     │                            │
│           │                     │ Real-time snapshots        │
│           │                     ↓                            │
│           │          ┌──────────────────────────┐          │
│           │          │  RealtimeSyncService     │          │
│           │          │  (Manages Listeners)     │          │
│           │          └──────────┬───────────────┘          │
│           │                     │                            │
│           └─────────────────────┘                            │
│                    Writes synced data                        │
└──────────────────────────────────────────────────────────────┘
```

### Component Responsibilities

#### 1. Repositories
**Files:**
- `lib/features/groups/data/repositories/synced_group_repository.dart`
- `lib/features/expenses/data/repositories/synced_expense_repository.dart`

**Responsibilities:**
- Implement domain repository interfaces
- Coordinate Local DB + Upload Queue
- Provide streams for UI
- NO sync logic, NO Firestore calls, NO connectivity checks

**Key Methods:**
```dart
class SyncedGroupRepository implements GroupRepository {
  final AppDatabase _database;

  Future<Result<GroupEntity>> createGroup(GroupEntity group) {
    // 1. Write to local DB
    // 2. Enqueue operation
    // 3. Return immediately
  }

  Stream<List<GroupEntity>> watchUserGroups(String userId) {
    // Return stream from local DB
    return _database.watchUserGroups(userId);
  }
}
```

#### 2. Local Database (Drift/SQLite)
**File:** `lib/core/database/app_database.dart`

**Responsibilities:**
- Persist data locally
- Provide reactive streams
- Manage sync queue table
- Handle soft deletes
- Implement upsert methods for sync

**Key Tables:**
- `app_groups` - Groups with soft delete support
- `app_group_members` - Group membership
- `expenses` - Expense records with soft delete
- `expense_shares` - Expense split shares
- `sync_queue` - Upload queue for pending operations

**Key Methods:**
```dart
// Regular operations (trigger queue in repository)
Future<void> insertGroup(GroupEntity group);
Future<void> softDeleteExpense(String id);

// Sync-safe operations (bypass queue)
Future<void> upsertGroupFromSync(GroupEntity group);
Future<void> upsertExpenseFromSync(ExpenseEntity expense);
Future<void> upsertGroupMemberFromSync(GroupMemberEntity member);

// Queue operations
Future<void> enqueueOperation({...});
Future<List<SyncQueueData>> getPendingOperations();
Future<void> removeQueuedOperation(int id);
```

#### 3. Upload Queue Service
**File:** `lib/core/sync/upload_queue_service.dart`

**Responsibilities:**
- Process pending operations from queue
- Upload to Firestore
- Handle retries and failures
- Remove successfully uploaded operations

**Flow:**
```dart
Future<void> processQueue() async {
  final operations = await _database.getPendingOperations(limit: 10);

  for (final operation in operations) {
    if (operation.retryCount >= maxRetries) continue;

    try {
      await _processOperation(operation);
      await _database.removeQueuedOperation(operation.id);
    } catch (e) {
      await _database.markOperationFailed(operation.id, e.toString());
    }
  }
}
```

#### 4. Realtime Sync Service (New)
**File:** `lib/core/sync/realtime_sync_service.dart` (to be created)

**Responsibilities:**
- Manage Firestore listener lifecycle
- Listen to user's groups in real-time
- Listen to group expenses in real-time
- Update local DB when remote changes occur
- Handle listener errors and reconnection

**Key Methods:**
```dart
class RealtimeSyncService {
  // Start listening to user's data
  Future<void> startRealtimeSync(String userId);

  // Stop all listeners
  Future<void> stopRealtimeSync();

  // Handle groups changed
  Future<void> _onGroupsChanged(List<GroupEntity> remoteGroups);

  // Handle expenses changed
  Future<void> _onExpensesChanged(String groupId, List<ExpenseEntity> expenses);

  // Sync members for a group
  Future<void> _syncGroupMembers(String groupId);

  // Sync shares for an expense
  Future<void> _syncExpenseShares(String groupId, String expenseId);
}
```

#### 5. Sync Service (Updated)
**File:** `lib/core/sync/sync_service.dart`

**Responsibilities:**
- Orchestrate overall sync
- Monitor connectivity
- Start/stop real-time sync on connectivity changes
- Process upload queue when online
- Provide manual sync method

**Key Changes:**
- Remove timer-based polling
- Remove download logic (moved to RealtimeSyncService)
- Simplified to just: connectivity monitoring + queue processing + listener management

#### 6. Firestore Services
**Files:**
- `lib/features/groups/data/services/firestore_group_service.dart`
- `lib/features/expenses/data/services/firestore_expense_service.dart`

**Responsibilities:**
- Upload/download individual documents
- Provide real-time snapshot streams
- Handle Firestore-specific logic

**New Methods:**
```dart
class FirestoreGroupService {
  // Existing upload/download methods remain

  // NEW: Real-time streams
  Stream<List<GroupEntity>> watchUserGroups(String userId) {
    return _firestore
        .collectionGroup('members')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .asyncMap((snapshot) => /* map to List<GroupEntity> */);
  }
}

class FirestoreExpenseService {
  // Existing upload/download methods remain

  // NEW: Real-time streams
  Stream<List<ExpenseEntity>> watchGroupExpenses(String groupId) {
    return _firestore
        .collection('groups')
        .doc(groupId)
        .collection('expenses')
        .snapshots()
        .map((snapshot) => /* map to List<ExpenseEntity> */);
  }
}
```

---

## Data Flow

### Write Path (User Creates Expense)

```
┌─────────────────────────────────────────────────────────────┐
│ Step 1: User taps "Create Expense" button                   │
└────────────────────┬────────────────────────────────────────┘
                     ↓
┌─────────────────────────────────────────────────────────────┐
│ Step 2: Provider calls repository.createExpense()           │
└────────────────────┬────────────────────────────────────────┘
                     ↓
┌─────────────────────────────────────────────────────────────┐
│ Step 3: Repository writes to Local DB (0ms)                 │
│         await _database.insertExpense(expense)               │
└────────────────────┬────────────────────────────────────────┘
                     ↓
┌─────────────────────────────────────────────────────────────┐
│ Step 4: Repository enqueues operation                       │
│         await _database.enqueueOperation(...)                │
└────────────────────┬────────────────────────────────────────┘
                     ↓
┌─────────────────────────────────────────────────────────────┐
│ Step 5: Drift stream emits change                           │
│         UI rebuilds with new expense (instant!)              │
└────────────────────┬────────────────────────────────────────┘
                     ↓
┌─────────────────────────────────────────────────────────────┐
│ Step 6: UploadQueueService processes queue (background)     │
│         Uploads expense to Firestore                         │
└────────────────────┬────────────────────────────────────────┘
                     ↓
┌─────────────────────────────────────────────────────────────┐
│ Step 7: Firestore snapshot event fires on other devices ⚡   │
│         Their RealtimeSyncService receives the change        │
└─────────────────────────────────────────────────────────────┘
```

**Timeline:**
- **T0:** User action
- **T1 (0ms):** Local DB write
- **T2 (10ms):** UI updates (instant!)
- **T3 (100ms):** Queue entry added
- **T4 (500ms):** Upload to Firestore starts
- **T5 (800ms):** Upload complete
- **T6 (900ms):** Other devices receive snapshot event
- **T7 (950ms):** Other devices' UIs update

**User sees instant feedback at T2!**

---

### Read Path (User Opens Expense List)

```
┌─────────────────────────────────────────────────────────────┐
│ Step 1: User opens expense list screen                      │
└────────────────────┬────────────────────────────────────────┘
                     ↓
┌─────────────────────────────────────────────────────────────┐
│ Step 2: Widget watches provider stream                      │
│         ref.watch(groupExpensesProvider(groupId))            │
└────────────────────┬────────────────────────────────────────┘
                     ↓
┌─────────────────────────────────────────────────────────────┐
│ Step 3: Provider watches repository stream                  │
│         repository.watchExpensesByGroup(groupId)             │
└────────────────────┬────────────────────────────────────────┘
                     ↓
┌─────────────────────────────────────────────────────────────┐
│ Step 4: Repository returns Drift stream                     │
│         _database.watchExpensesByGroup(groupId)              │
└────────────────────┬────────────────────────────────────────┘
                     ↓
┌─────────────────────────────────────────────────────────────┐
│ Step 5: Drift queries local DB and emits data               │
│         Stream emits: List<ExpenseEntity>                    │
└────────────────────┬────────────────────────────────────────┘
                     ↓
┌─────────────────────────────────────────────────────────────┐
│ Step 6: UI renders expense list                             │
│         Instant! No network call needed.                     │
└─────────────────────────────────────────────────────────────┘

Meanwhile, in the background:
┌─────────────────────────────────────────────────────────────┐
│ Parallel: SyncService ensures real-time listeners active    │
│           New remote expenses → Local DB → Stream emits      │
│           UI automatically updates (no explicit refresh)     │
└─────────────────────────────────────────────────────────────┘
```

**Key Point:** UI NEVER waits for network. It always reads from local DB.

---

### Real-Time Sync Path (Remote Changes)

```
Device B: User edits expense title
         ↓
Device B: Repository writes to Local DB
         ↓
Device B: Enqueues upload operation
         ↓
Device B: UploadQueueService uploads to Firestore
         ↓
     Firestore document updated
         ↓
     Firestore triggers snapshot event ⚡
         ↓
Device A: RealtimeSyncService._expenseListener receives event
         ↓
Device A: RealtimeSyncService calls _onExpensesChanged()
         ↓
Device A: _database.upsertExpenseFromSync(updatedExpense)
         ↓
Device A: Drift stream emits updated expense
         ↓
Device A: UI automatically rebuilds with new title
         ↓
Device A: User sees updated expense (< 1 second)
```

**Latency:** < 1 second from Device B action to Device A UI update

---

### Offline → Online Transition

```
User goes offline
         ↓
User creates 5 expenses (all saved to Local DB)
         ↓
5 operations added to upload queue
         ↓
UI shows all 5 expenses (instant, no network needed)
         ↓
User goes online
         ↓
ConnectivityService detects connection
         ↓
SyncService._onConnectionRestored() called
         ↓
UploadQueueService.processQueue() uploads 5 operations
         ↓
RealtimeSyncService.startRealtimeSync() starts listeners
         ↓
All 5 expenses now synced to Firestore
         ↓
Other devices receive snapshot events
         ↓
Other devices' UIs update automatically
```

**User never waits!** UI is always responsive.

---

## Real-Time Sync Mechanism

### Firestore Snapshot Listeners

**How They Work:**
```dart
// Firestore SDK maintains persistent WebSocket connection
_firestore.collection('groups')
    .doc(groupId)
    .collection('expenses')
    .snapshots()  // ← Opens real-time connection
    .listen((snapshot) {
      // Called whenever ANY document in collection changes
      for (final docChange in snapshot.docChanges) {
        switch (docChange.type) {
          case DocumentChangeType.added:
            // New expense created
          case DocumentChangeType.modified:
            // Expense updated
          case DocumentChangeType.removed:
            // Expense deleted
        }
      }
    });
```

**Connection Lifecycle:**
1. **Initial Connection:** Opens WebSocket, sends initial query, receives full dataset
2. **Listening:** Maintains connection, receives only changes (delta updates)
3. **Disconnection:** Automatically handled by Firestore SDK
4. **Reconnection:** Automatic, SDK catches up on missed changes
5. **Error Handling:** SDK retries with exponential backoff

**Benefits:**
- ✅ Efficient: Only changed documents sent over network
- ✅ Automatic reconnection: No manual retry logic needed
- ✅ Catches up: Receives all changes that occurred while offline
- ✅ Low latency: < 1 second typical

**Cost Considerations:**
- 1 read for initial query
- 1 read per document change
- Connection is persistent (small data transfer cost)

---

### Listener Lifecycle Management

**Challenge:** Must start/stop listeners based on:
- User authentication state (only listen when logged in)
- Network connectivity (no point listening when offline)
- App lifecycle (stop when app backgrounded to save battery)

**Solution: Centralized Management**

```dart
class RealtimeSyncService {
  String? _currentUserId;
  StreamSubscription? _groupsListener;
  Map<String, StreamSubscription> _expenseListeners = {};

  Future<void> startRealtimeSync(String userId) async {
    if (_currentUserId == userId) return; // Already syncing

    await stopRealtimeSync(); // Clean up old listeners
    _currentUserId = userId;

    // Start group listener
    _groupsListener = _firestoreService
        .watchUserGroups(userId)
        .listen(_onGroupsChanged);

    // Expense listeners started dynamically per group
  }

  Future<void> stopRealtimeSync() async {
    await _groupsListener?.cancel();
    for (final listener in _expenseListeners.values) {
      await listener.cancel();
    }
    _expenseListeners.clear();
    _currentUserId = null;
  }
}
```

**Lifecycle Events:**
- **App Startup:** `startRealtimeSync(userId)` called after authentication
- **User Logout:** `stopRealtimeSync()` called to clean up
- **Device Offline:** Listeners automatically pause (Firestore SDK handles)
- **Device Online:** Listeners automatically resume (Firestore SDK handles)
- **App Background:** Keep listeners active (or stop to save battery - configurable)

---

### Handling Concurrent Edits

**Scenario:** Two users edit the same expense simultaneously

```
T0: Both users offline
    Device A: User edits title to "Lunch at Pizza Place"
    Device B: User edits title to "Lunch at Burger Joint"

T1: Both write to local DB
    Device A Local DB: title = "Lunch at Pizza Place", updatedAt = T1
    Device B Local DB: title = "Lunch at Burger Joint", updatedAt = T1

T2: Both go online
    Device A uploads: title = "Lunch at Pizza Place", updatedAt = T1
    Device B uploads: title = "Lunch at Burger Joint", updatedAt = T1

T3: Firestore has both writes
    (Firestore processes them in order received)
    Assume Device A's write arrives first, then Device B

T4: Device A's update written to Firestore
    Firestore: title = "Lunch at Pizza Place", updatedAt = T1

T5: Device B's update overwrites
    Firestore: title = "Lunch at Burger Joint", updatedAt = T1
    (Same timestamp! But Device B's write was last)

T6: Snapshot event fires to all listeners
    Device A receives: title = "Lunch at Burger Joint"
    Device B already has: title = "Lunch at Burger Joint"

T7: Device A's local DB updated via upsertExpenseFromSync()
    Device A Local DB: title = "Lunch at Burger Joint", updatedAt = T1
    Device A UI updates to show "Lunch at Burger Joint"
```

**Result:** Device B's edit wins (Last Write Wins)

**User Experience:**
- Device A user sees their edit first (instant local update)
- A moment later, Device A user sees Device B's edit appear
- This is acceptable for most collaborative apps

**Future Enhancement:** Implement operational transformation or CRDTs for better merge semantics

---

## Conflict Resolution

### Last Write Wins (LWW)

**Strategy:** The document with the most recent `updatedAt` timestamp wins.

**Implementation:**

```dart
// In app_database.dart
Future<void> upsertGroupFromSync(GroupEntity group) async {
  final existing = await getGroupById(group.id);

  if (existing == null) {
    // New group from remote - just insert
    await into(appGroups).insert(/* ... */);
  } else {
    // Conflict: Compare timestamps
    if (group.updatedAt.isAfter(existing.updatedAt)) {
      // Remote is newer - update local
      await (update(appGroups)..where((g) => g.id.equals(group.id)))
          .write(/* ... */);
    } else {
      // Local is newer or same - keep local, ignore remote
      // (This shouldn't happen if upload queue works correctly)
    }
  }
}
```

**Key Points:**
- ✅ Simple to implement
- ✅ Deterministic: All devices converge to same state
- ❌ Can lose data: User's edit might be overwritten

**When It Works Well:**
- Different users editing different fields
- Edits separated by time (not simultaneous)
- UI clearly shows "last updated" timestamp

**When It Fails:**
- Simultaneous edits to same field
- Long offline periods followed by sync
- Critical data that can't afford to be lost

---

### Preventing Upload Queue Loops

**Problem:** If sync downloads trigger queue entries, infinite loop!

```
Device A uploads expense
    ↓
Firestore updated
    ↓
Device A listener receives snapshot
    ↓
❌ If this triggers queue entry:
    Device A uploads again
    ↓
Infinite loop!
```

**Solution:** Separate methods for sync writes

```dart
// Regular insert - DOES trigger queue (called by repository)
Future<void> insertExpense(ExpenseEntity expense) async {
  await into(expenses).insert(/* ... */);
  // Repository will enqueue this operation
}

// Sync insert - DOES NOT trigger queue (called by RealtimeSyncService)
Future<void> upsertExpenseFromSync(ExpenseEntity expense) async {
  await into(expenses).insertOnConflictUpdate(/* ... */);
  // No queue entry! This is already synced data.
}
```

**Naming Convention:**
- `insert*` / `update*` / `delete*` → Used by repositories, triggers queue
- `*FromSync` → Used by sync services, bypasses queue

---

### Handling Soft Deletes

**Scenario:** User deletes expense while offline

```dart
// Repository
Future<Result<void>> deleteExpense(String id) async {
  // Soft delete: Set deletedAt timestamp
  await _database.softDeleteExpense(id);

  // Queue for upload
  await _database.enqueueOperation(
    entityType: 'expense',
    entityId: id,
    operationType: 'delete',
  );
}

// UploadQueueService
Future<void> _processExpenseDelete(SyncQueueData operation) async {
  // Get soft-deleted expense (still in DB)
  final expense = await _database.getExpenseById(
    operation.entityId,
    includeDeleted: true,
  );

  // Upload deletion to Firestore
  await _expenseService.deleteExpense(expense.groupId, expense.id);

  // Hard delete after successful upload
  await _database.hardDeleteExpense(expense.id);
}
```

**Benefits:**
- ✅ Can retry if upload fails
- ✅ Have all data needed for upload (groupId, etc.)
- ✅ No complex metadata encoding

**Database Queries:**
```dart
// Default queries exclude soft-deleted
Future<ExpenseEntity?> getExpenseById(String id) async {
  return select(expenses)
    ..where((e) => e.id.equals(id) & e.deletedAt.isNull());
}

// Special query for upload queue
Future<ExpenseEntity?> getExpenseById(String id, {bool includeDeleted = false}) async {
  final query = select(expenses)..where((e) => e.id.equals(id));
  if (!includeDeleted) {
    query.where((e) => e.deletedAt.isNull());
  }
  return query.getSingleOrNull();
}
```

---

## Implementation Plan

### Phase 1: Database Updates (Week 1)

**Goal:** Add sync-safe upsert methods and soft delete support

**Tasks:**
1. Add `upsertGroupMemberFromSync()` method
2. Add `includeDeleted` parameter to get methods
3. Add `softDeleteExpense()` method
4. Add `hardDeleteExpense()` method
5. Update delete operations in repositories to use soft delete

**Files:**
- `lib/core/database/app_database.dart`
- `lib/features/expenses/data/repositories/synced_expense_repository.dart`
- `lib/features/groups/data/repositories/synced_group_repository.dart`

**Testing:**
- Unit tests for upsert methods
- Test soft delete + hard delete flow
- Test includeDeleted queries

---

### Phase 2: Firestore Real-Time Streams (Week 1-2)

**Goal:** Add snapshot listeners to Firestore services

**Tasks:**
1. Add `watchUserGroups(userId)` to FirestoreGroupService
2. Add `watchGroupExpenses(groupId)` to FirestoreExpenseService
3. Handle Firestore snapshot events properly
4. Map Firestore documents to domain entities

**Files:**
- `lib/features/groups/data/services/firestore_group_service.dart`
- `lib/features/expenses/data/services/firestore_expense_service.dart`

**Testing:**
- Manual test: Create group in Firestore console, verify stream emits
- Manual test: Update expense, verify stream emits change
- Test error handling (network loss, invalid data)

---

### Phase 3: Realtime Sync Service (Week 2)

**Goal:** Create service to manage listeners

**Tasks:**
1. Create `RealtimeSyncService` class
2. Implement `startRealtimeSync(userId)`
3. Implement `stopRealtimeSync()`
4. Implement listener callbacks (`_onGroupsChanged`, `_onExpensesChanged`)
5. Add proper error handling and logging

**Files:**
- `lib/core/sync/realtime_sync_service.dart` (new file)

**Testing:**
- Test listener lifecycle (start, stop, restart)
- Test group listener triggers expense listeners
- Test error handling (listener failures)

---

### Phase 4: Update Sync Service (Week 2-3)

**Goal:** Integrate RealtimeSyncService into existing SyncService

**Tasks:**
1. Remove timer-based polling code
2. Remove `_downloadRemoteChanges()` method
3. Add RealtimeSyncService dependency
4. Update connectivity handler to start/stop listeners
5. Keep upload queue processing logic

**Files:**
- `lib/core/sync/sync_service.dart`

**Testing:**
- Test connectivity changes (offline → online)
- Test manual sync still works
- Test upload queue processing

---

### Phase 5: Simplify Repositories (Week 3)

**Goal:** Remove sync logic from repositories

**Tasks:**
1. Remove Firestore service dependencies from SyncedGroupRepository
2. Remove Connectivity dependency
3. Remove `_syncUserGroupsFromFirestore()` method
4. Remove `_isOnline()` check
5. Update `joinGroupByCode()` to not do direct sync (move to separate service)

**Files:**
- `lib/features/groups/data/repositories/synced_group_repository.dart`

**Testing:**
- Test all repository methods still work
- Test repositories don't make Firestore calls
- Test upload queue entries still created

---

### Phase 6: Update Providers (Week 3)

**Goal:** Ensure providers work with new sync architecture

**Tasks:**
1. Update sync service provider to inject RealtimeSyncService
2. Ensure `startAutoSync()` called on app startup
3. Ensure `stopAutoSync()` called on logout
4. No changes needed to data providers (they already watch local DB)

**Files:**
- `lib/core/sync/sync_providers.dart`
- `lib/main.dart`

**Testing:**
- Test app startup sync flow
- Test logout cleanup
- Test UI updates in real-time

---

### Phase 7: Replace Print Statements (Week 4)

**Goal:** Professional logging

**Tasks:**
1. Add `LoggerMixin` to all services
2. Replace all `print()` with `log.d/i/w/e()`
3. Remove debug print statements

**Files:**
- All service files

**Testing:**
- Verify logs appear with correct severity
- Verify no print statements remain

---

### Phase 8: End-to-End Testing (Week 4)

**Goal:** Validate entire flow works

**Test Scenarios:**

1. **Offline Creation**
   - Disable network
   - Create expense
   - Verify immediate UI update
   - Enable network
   - Verify syncs to Firestore
   - Verify appears on other device

2. **Real-Time Sync**
   - Device A: Create expense
   - Device B: Verify expense appears < 1 second

3. **Conflict Resolution**
   - Both devices offline
   - Both edit same expense
   - Both go online
   - Verify LWW works correctly

4. **Offline Queue Processing**
   - Offline: Create 10 expenses
   - Go online
   - Verify all 10 upload
   - Verify all 10 appear on other device

5. **Listener Reconnection**
   - Start app online
   - Go offline for 5 minutes
   - Another device creates expense
   - Original device goes online
   - Verify expense appears

---

### Phase 9: Documentation (Week 4)

**Goal:** Complete documentation

**Tasks:**
1. Update SYNC_ARCHITECTURE.md with real-time implementation
2. Add API documentation to all public methods
3. Create troubleshooting guide
4. Update README with architecture overview

---

## Migration from Current Architecture

### Breaking Changes

**None!** This is a drop-in replacement.

### Deployment Strategy

1. **Deploy database changes first** (soft delete, upsert methods)
2. **Deploy new services** (RealtimeSyncService)
3. **Update SyncService** to use new services
4. **Deploy repository simplifications**
5. **Monitor logs for errors**

### Rollback Plan

If issues occur:
1. Keep old SyncService as `SyncServiceV1`
2. Keep old repositories as `*RepositoryV1`
3. Switch back to old implementations via provider
4. No data loss (upload queue preserves operations)

### Data Migration

**No migration needed!**
- Database schema unchanged
- Existing queue entries still processed
- Existing data works with new code

---

## Testing Strategy

### Unit Tests

**Repositories:**
```dart
test('createGroup writes to DB and enqueues', () async {
  final repository = SyncedGroupRepository(mockDatabase);

  await repository.createGroup(testGroup);

  verify(mockDatabase.insertGroup(testGroup)).called(1);
  verify(mockDatabase.enqueueOperation(/* ... */)).called(1);
});
```

**Sync Services:**
```dart
test('RealtimeSyncService starts group listener', () async {
  final service = RealtimeSyncService(/* ... */);

  await service.startRealtimeSync(userId);

  verify(mockFirestoreService.watchUserGroups(userId)).called(1);
});
```

### Integration Tests

**Database + Queue:**
```dart
testWidgets('Expense creation triggers upload queue', (tester) async {
  await tester.pumpWidget(app);

  // Create expense
  await tester.tap(find.byKey(createExpenseButton));
  await tester.pumpAndSettle();

  // Verify in queue
  final queue = await database.getPendingOperations();
  expect(queue, hasLength(1));
  expect(queue.first.entityType, 'expense');
});
```

### End-to-End Tests

**Multi-Device Sync:**
```dart
testWidgets('Real-time sync across devices', (tester) async {
  // Device A: Create expense
  final deviceA = await setupDevice('userA');
  await deviceA.createExpense(testExpense);

  // Device B: Wait for sync
  final deviceB = await setupDevice('userA');
  await tester.pump(Duration(seconds: 2));

  // Verify Device B has expense
  expect(find.text(testExpense.title), findsOneWidget);
});
```

### Manual Testing Checklist

- [ ] Create expense offline → verify instant UI update
- [ ] Go online → verify expense syncs to Firestore
- [ ] Other device → verify expense appears < 1 second
- [ ] Edit on Device A → verify Device B updates in real-time
- [ ] Delete on Device B → verify Device A updates in real-time
- [ ] Concurrent edits → verify LWW works
- [ ] Network loss → verify listeners reconnect automatically
- [ ] App restart → verify sync resumes
- [ ] Logout → verify listeners stop

---

## Performance Considerations

### Firestore Costs

**Pricing (as of 2025):**
- Document reads: $0.06 per 100,000
- Document writes: $0.18 per 100,000
- Network egress: $0.12 per GB
- Free tier: 50,000 reads/day, 20,000 writes/day

**Estimated Costs for 1000 Active Users:**
- Initial load: 1000 users × 10 groups × 1 read = 10,000 reads/day
- Real-time updates: 1000 users × 5 expenses/day × 1 read = 5,000 reads/day
- Total reads: ~15,000/day (within free tier)
- Total writes: ~5,000/day (within free tier)

**Optimization Strategies:**
- Cache initial loads
- Use pagination for large lists
- Debounce rapid updates
- Implement incremental sync (only fetch changes)

### Battery Impact

**Listener Overhead:**
- WebSocket connection: ~5-10% battery drain per hour
- Minimal data transfer (only deltas)

**Mitigation:**
- Stop listeners when app backgrounded
- Use WorkManager for periodic sync instead
- Let user control real-time vs. manual sync

### Memory Usage

**Listener Subscriptions:**
- Each listener: ~1-5 KB memory
- 10 groups × 1 expense listener each = ~50 KB
- Negligible impact

**Stream Controllers:**
- Drift manages streams efficiently
- No memory leaks if disposed properly

### Network Usage

**Initial Load:**
- 10 groups × 10 KB each = 100 KB
- 100 expenses × 2 KB each = 200 KB
- Total: ~300 KB per initial sync

**Real-Time Updates:**
- Only changed documents transferred
- Average expense: ~2 KB
- 10 updates/hour = 20 KB/hour
- Very minimal

---

## Security Considerations

### Firestore Security Rules

**Required Rules:**

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users can only read/write groups they are members of
    match /groups/{groupId} {
      allow read: if isGroupMember(groupId);
      allow write: if isGroupMember(groupId);

      match /members/{memberId} {
        allow read: if isGroupMember(groupId);
        allow write: if isGroupMember(groupId);
      }

      match /expenses/{expenseId} {
        allow read: if isGroupMember(groupId);
        allow write: if isGroupMember(groupId);

        match /shares/{shareId} {
          allow read: if isGroupMember(groupId);
          allow write: if isGroupMember(groupId);
        }
      }
    }

    function isGroupMember(groupId) {
      return exists(/databases/$(database)/documents/groups/$(groupId)/members/$(request.auth.uid));
    }
  }
}
```

**Key Points:**
- ✅ Users can only access groups they're members of
- ✅ Membership verified on every operation
- ✅ No direct collection group queries without membership check
- ✅ Prevents unauthorized data access

### Client-Side Validation

**Always validate before upload:**
```dart
Future<void> _processExpenseOperation(SyncQueueData operation) async {
  final expense = await _database.getExpenseById(operation.entityId);

  // Validate
  if (expense.amount <= 0) {
    throw ValidationException('Amount must be positive');
  }
  if (expense.title.isEmpty) {
    throw ValidationException('Title is required');
  }

  // Upload
  await _expenseService.uploadExpense(expense);
}
```

### Authentication

**Ensure authenticated before sync:**
```dart
void startAutoSync(String? userId) {
  if (userId == null) {
    log.w('Cannot start sync: user not authenticated');
    return;
  }
  // Start sync...
}
```

### Data Encryption

**Local DB:**
- Use SQLCipher for encrypted local database (future enhancement)
- Encrypt sensitive fields before storing

**Network:**
- Firestore uses TLS by default
- No additional encryption needed

---

## Appendix A: File Structure

```
lib/
├── core/
│   ├── database/
│   │   ├── app_database.dart          # Local database (Drift)
│   │   └── tables/                    # Table definitions
│   ├── sync/
│   │   ├── sync_service.dart          # Main sync orchestrator
│   │   ├── upload_queue_service.dart  # Upload queue processor
│   │   ├── realtime_sync_service.dart # NEW: Listener manager
│   │   └── sync_providers.dart        # Riverpod providers
│   └── logging/
│       └── app_logger.dart            # Logging utilities
├── features/
│   ├── groups/
│   │   ├── domain/
│   │   │   ├── entities/
│   │   │   │   ├── group_entity.dart
│   │   │   │   └── group_member_entity.dart
│   │   │   └── repositories/
│   │   │       └── group_repository.dart     # Interface
│   │   ├── data/
│   │   │   ├── repositories/
│   │   │   │   └── synced_group_repository.dart  # Implementation
│   │   │   └── services/
│   │   │       └── firestore_group_service.dart  # Firestore API
│   │   └── presentation/
│   │       ├── screens/
│   │       └── providers/
│   │           └── group_providers.dart
│   └── expenses/
│       ├── domain/
│       │   ├── entities/
│       │   │   ├── expense_entity.dart
│       │   │   └── expense_share_entity.dart
│       │   └── repositories/
│       │       └── expense_repository.dart
│       ├── data/
│       │   ├── repositories/
│       │   │   └── synced_expense_repository.dart
│       │   └── services/
│       │       └── firestore_expense_service.dart
│       └── presentation/
└── main.dart
```

---

## Appendix B: Key Interfaces

### GroupRepository Interface

```dart
abstract class GroupRepository {
  Future<Result<GroupEntity>> createGroup(GroupEntity group);
  Future<Result<GroupEntity>> getGroupById(String id);
  Future<Result<List<GroupEntity>>> getUserGroups(String userId);
  Future<Result<GroupEntity>> updateGroup(GroupEntity group);
  Future<Result<void>> deleteGroup(String id);
  Future<Result<void>> addMember(GroupMemberEntity member);
  Future<Result<void>> removeMember(String groupId, String userId);
  Stream<List<GroupEntity>> watchUserGroups(String userId);
}
```

### ExpenseRepository Interface

```dart
abstract class ExpenseRepository {
  Future<Result<ExpenseEntity>> createExpense(ExpenseEntity expense);
  Future<Result<ExpenseEntity>> getExpenseById(String id);
  Future<Result<List<ExpenseEntity>>> getExpensesByGroup(String groupId);
  Future<Result<ExpenseEntity>> updateExpense(ExpenseEntity expense);
  Future<Result<void>> deleteExpense(String id);
  Stream<List<ExpenseEntity>> watchExpensesByGroup(String groupId);
}
```

---

## Appendix C: Glossary

- **Clean Architecture:** Architectural pattern with clear layer separation and dependency rules
- **Drift:** Type-safe SQLite wrapper for Flutter
- **Entity:** Pure domain model representing business concepts
- **Firestore:** Google Cloud's NoSQL document database
- **Last Write Wins (LWW):** Conflict resolution strategy using timestamps
- **Offline-First:** Architecture prioritizing local data and instant UI updates
- **Repository Pattern:** Abstraction layer between domain and data sources
- **Riverpod:** State management library for Flutter
- **Snapshot Listener:** Real-time database listener that fires on data changes
- **Soft Delete:** Marking data as deleted without physically removing it
- **Stream:** Reactive data flow that emits values over time
- **Upsert:** Update if exists, insert if not (atomic operation)

---

## Team Discussion Questions - RESOLVED ✅

### 1. ✅ Battery Trade-off: Should we keep listeners active when app is backgrounded?
**Decision:** NO - Foreground-only listeners
**Rationale:**
- Background listeners drain battery significantly
- Firestore SDK has excellent catch-up mechanism
- 1-second delay on app resume is acceptable UX
- Significant battery savings for users

### 2. ✅ Real-time Granularity: Should shares also be real-time, or one-time fetch is enough?
**Decision:** One-time fetch is sufficient
**Rationale:**
- Shares rarely change independently of their parent expense
- When expense listener fires, we fetch shares at that time
- Cost optimization: Shares are small, fetching on-demand is cheap
- Can upgrade to real-time later if needed

### 3. ✅ Conflict Resolution: Is LWW acceptable, or do we need more sophisticated merging?
**Decision:** LWW with server timestamps + conflict notifications
**Rationale:**
- LWW is simple and deterministic
- Server timestamps eliminate clock skew issues
- Conflict notifications make data loss feel intentional, not like a bug
- Can add field-level merging in v3 if user feedback demands it

### 4. ✅ Cost Management: Should we implement pagination/caching to reduce Firestore reads?
**Decision:** Hybrid listener strategy + smart caching
**Rationale:**
- Single global listener (1 read) + active view listener (1 read) = 2 total
- On-demand fetch for inactive groups when `lastActivityAt` changes
- Local DB acts as cache - only fetch when needed
- Cost is already optimized, pagination not needed initially

### 5. ✅ Testing: What's our target test coverage?
**Decision:** 80% unit tests, 60% integration tests, 5 critical E2E scenarios
**Critical E2E Scenarios:**
1. Offline expense creation → online sync
2. Real-time update propagation across devices
3. Conflict resolution (concurrent edits)
4. Queue retry on network failure
5. Listener reconnection after app resume

### 6. ✅ Migration: Gradual rollout or big-bang deployment?
**Decision:** Feature-flag controlled gradual rollout
**Strategy:**
1. Week 1: Internal testing (10% of users behind flag)
2. Week 2: Beta users (25% of users)
3. Week 3: General rollout (100% of users)
4. Keep old sync code for 1 month as fallback

### 7. ✅ Monitoring: What metrics should we track?
**Decision:** Track all critical metrics - see "Key Metrics" section above
**Specific Implementations:**
- Firebase Performance Monitoring for sync latency
- Custom Firestore metrics for cost tracking
- Crashlytics for sync-related crashes
- In-app debug menu for real-time queue status

---

## Next Steps - READY FOR IMPLEMENTATION

### Phase 0: Pre-Implementation (Complete by: Week 0)
1. ✅ Architecture document reviewed and approved
2. ✅ All team questions resolved
3. ⏳ Set up feature flag system
4. ⏳ Create monitoring dashboards
5. ⏳ Set up Firestore indexes

### Phase 1-9: Implementation (See Implementation Plan section)
- Timeline: 4 weeks
- Start Date: [To be assigned]
- Team Assignment: [To be assigned]

### Post-Launch (Week 5+)
1. Monitor key metrics daily for first week
2. Weekly sync architecture reviews
3. Gather user feedback on conflict notifications
4. Plan v3 enhancements based on data

---

**Document Status:** ✅ Approved - Ready for Implementation
**Approved By:** Tech Lead, Product Owner, Development Team
**Target Start Date:** [To be assigned by PM]
**Estimated Completion:** 4 weeks from start
