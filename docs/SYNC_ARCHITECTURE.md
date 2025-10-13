# FairShare Sync Architecture

**Last Updated:** 2025-10-03
**Status:** Active Implementation

---

## Table of Contents

- [Overview](#overview)
- [Architecture Principles](#architecture-principles)
- [Data Flow](#data-flow)
- [Components](#components)
- [Sync Process](#sync-process)
- [Current Issues & Solutions](#current-issues--solutions)
- [Known Limitations](#known-limitations)

---

## Overview

FairShare uses a **hybrid offline-first architecture** that combines:

- **Local Database** (Drift/SQLite) - Primary data source
- **Remote Database** (Cloud Firestore) - Backup and multi-device sync
- **Upload Queue** - Ensures reliable sync with retry logic

### Design Goals

1. **Offline-first**: App works fully offline, syncs when online
2. **Eventual consistency**: Data eventually syncs across devices
3. **Conflict resolution**: Last Write Wins (LWW) strategy
4. **Data integrity**: ACID transactions in local DB, atomic uploads

---

## Architecture Principles

### 1. Offline-First Pattern

```
User Action → Local DB (immediate) → Upload Queue → Firestore (when online)
                  ↓
            UI Updates (instant feedback)
```

**Why:** Users expect instant responses, not loading spinners waiting for network.

### 2. Single Source of Truth

- **Local DB** is the source of truth for UI
- **Firestore** is the source of truth for sync
- **Stream-based UI** - Drift streams automatically update UI when local DB changes

### 3. Bidirectional Sync

```
App Startup / Manual Sync:
1. Upload: Queue → Firestore (push local changes)
2. Download: Firestore → Local DB (pull remote changes)
3. Verify: Compare Local ↔ Firestore (debug only)
```

---

## Data Flow

### Create Operation (e.g., Create Group)

```
┌─────────────────────────────────────────────────────────┐
│ 1. User creates group in UI                             │
└────────────────┬────────────────────────────────────────┘
                 ↓
┌─────────────────────────────────────────────────────────┐
│ 2. Repository.createGroup(group)                        │
│    ├─ Insert into Local DB (immediate)                  │
│    ├─ Enqueue operation to upload queue                 │
│    └─ Return Success                                    │
└────────────────┬────────────────────────────────────────┘
                 ↓
┌─────────────────────────────────────────────────────────┐
│ 3. Drift Stream emits updated data                      │
│    └─ UI rebuilds with new group (instant)              │
└────────────────┬────────────────────────────────────────┘
                 ↓
┌─────────────────────────────────────────────────────────┐
│ 4. SyncService (background)                             │
│    ├─ Detects queued operation                          │
│    ├─ Uploads to Firestore                              │
│    └─ Removes from queue on success                     │
└─────────────────────────────────────────────────────────┘
```

### Read Operation (e.g., View Groups)

```
┌─────────────────────────────────────────────────────────┐
│ 1. Provider calls watchUserGroups(userId)               │
└────────────────┬────────────────────────────────────────┘
                 ↓
┌─────────────────────────────────────────────────────────┐
│ 2. SyncService.syncAll(userId) - AWAITED                │
│    ├─ Phase 0: Enqueue unsynced local data              │
│    ├─ Phase 1: Process upload queue → Firestore         │
│    ├─ Phase 2: Download Firestore → Local DB            │
│    └─ Phase 3: Verify consistency (debug)               │
└────────────────┬────────────────────────────────────────┘
                 ↓
┌─────────────────────────────────────────────────────────┐
│ 3. Repository.watchUserGroups(userId)                   │
│    └─ Returns Drift Stream from Local DB                │
└────────────────┬────────────────────────────────────────┘
                 ↓
┌─────────────────────────────────────────────────────────┐
│ 4. Stream emits data → UI renders                       │
└─────────────────────────────────────────────────────────┘
```

### Update Operation

- Same flow as Create
- Uses `upsert` in Local DB (insert or update)
- Enqueues as `'update'` operation type

### Delete Operation

- Soft delete in Local DB (`deletedAt` timestamp)
- Enqueues `'delete'` operation
- Hard delete in Firestore when queue processes

---

## Components

### 1. Local Database (Drift)

**File:** `lib/core/database/app_database.dart`

**Tables:**

- `app_groups` - Groups with soft delete support
- `app_group_members` - Group membership (many-to-many)
- `expenses` - Expense records
- `expense_shares` - Expense split shares
- `sync_queue` - Upload queue for pending operations

**Key Methods:**

```dart
// Regular inserts (trigger enqueue in repository)
insertGroup(group)
addGroupMember(member)
insertExpense(expense)

// Sync-safe inserts (bypass enqueue, used by download sync)
upsertGroupFromSync(group)
upsertExpenseFromSync(expense)

// Queue operations
enqueueOperation(entityType, entityId, operationType, metadata)
getPendingOperations(limit)
removeQueuedOperation(id)
```

**Streams:**

- Automatically emit when data changes
- UI rebuilds reactively via Riverpod providers

---

### 2. Firestore (Remote)

**File:** `lib/features/groups/data/services/firestore_group_service.dart`

**Collections:**

```
/groups/{groupId}
  - displayName, avatarUrl, isPersonal, defaultCurrency, etc.

  /members/{userId}
    - userId, joinedAt

  /expenses/{expenseId}
    - title, amount, currency, etc.

    /shares/{shareId}
      - userId, shareAmount
```

**Key Methods:**

```dart
// Upload (Create/Update)
uploadGroup(group)
uploadGroupMember(member)
uploadExpense(expense)

// Download
downloadUserGroups(userId) // Query by member userId
downloadGroup(groupId)
downloadGroupMembers(groupId)
downloadGroupExpenses(groupId)

// Delete
deleteGroup(groupId)
removeGroupMember(groupId, userId)
deleteExpense(groupId, expenseId)
```

**Query Strategy:**

- Groups: Collection group query on `members` subcollection filtered by `userId`
- Expenses: Query by `groupId`

---

### 3. Repositories (Data Layer)

**Files:**

- `lib/features/groups/data/repositories/synced_group_repository.dart`
- `lib/features/expenses/data/repositories/synced_expense_repository.dart`

**Responsibilities:**

1. Implement domain repository interfaces
2. Coordinate Local DB + Upload Queue
3. Handle offline/online states

**Pattern:**

```dart
Future<Result<GroupEntity>> createGroup(GroupEntity group) async {
  // 1. Save to local DB (offline-first)
  await _database.insertGroup(group);

  // 2. Enqueue for background sync
  await _database.enqueueOperation(
    entityType: EntityType.group,
    entityId: group.id,
    operationType: 'create',
  );

  // 3. Return immediately (don't wait for network)
  return Success(group);
}
```

---

### 4. Upload Queue Service

**File:** `lib/core/sync/upload_queue_service.dart`

**Purpose:** Process queued operations and upload to Firestore

**Flow:**

```
getPendingOperations()
  → _processOperation(operation)
    → uploadGroup() / uploadExpense() / uploadGroupMember()
  → removeQueuedOperation() on success
  → markOperationFailed() on error (retry up to 3 times)
```

**Entity Types:**

- `'group'` - Upload group document
- `'group_member'` - Upload member to group/members subcollection
- `'expense'` - Upload expense document
- (Future: `'expense_share'`)

**Retry Logic:**

- Max 3 retries per operation
- Failed operations stay in queue with error message
- Exponential backoff (future enhancement)

---

### 5. Sync Service

**File:** `lib/core/sync/sync_service.dart`

**Purpose:** Orchestrate bidirectional sync

**Sync Phases:**

```dart
Future<Result<void>> syncAll(String userId) async {
  // Phase 0: Migration - Enqueue existing unsynced data
  await _enqueueUnsyncedData(userId);

  // Phase 1: Upload - Process queue → Firestore
  await _uploadQueueService.processQueue();

  // Phase 2: Download - Firestore → Local DB
  await _downloadRemoteChanges(userId);

  // Phase 3: Verify - Compare consistency (debug only)
  await _verifyDataConsistency(userId);
}
```

**Auto-Sync:**

- Monitors connectivity changes
- Triggers sync when device comes online
- Queue watcher: checks every 30s for pending operations

**Conflict Resolution:**

- **Last Write Wins (LWW)**: Firestore timestamp wins
- Uses `upsertFromSync()` methods to avoid re-triggering queue

---

### 6. Providers (Presentation Layer)

**Files:**

- `lib/features/groups/presentation/providers/group_providers.dart`
- `lib/features/expenses/presentation/providers/expense_providers.dart`

**Pattern:**

```dart
@Riverpod(keepAlive: true)
Stream<List<GroupEntity>> userGroups(UserGroupsRef ref) async* {
  final userId = ref.watch(currentUserProvider)?.id;
  final syncService = ref.watch(syncServiceProvider);

  // CRITICAL: Await sync before watching
  await syncService.syncAll(userId);

  // Stream from local DB (now synced)
  await for (final groups in repository.watchUserGroups(userId)) {
    yield groups;
  }
}
```

**Why `keepAlive: true`?**

- Prevents provider disposal on rebuild
- Maintains stream subscription
- Ensures continuous reactivity

---

## Sync Process

### Initial Sync (App Startup)

```
User Signs In
  ↓
main.dart initializes syncServiceProvider
  ↓
SyncService.startAutoSync(userId)
  ├─ Checks connectivity
  ├─ Triggers syncAll() if online
  └─ Starts queue watcher (30s interval)
  ↓
userGroupsProvider called
  ├─ Awaits syncAll(userId)
  │   ├─ Enqueues unsynced local data (migration)
  │   ├─ Processes upload queue
  │   └─ Downloads from Firestore
  └─ Watches local DB stream
  ↓
UI renders with synced data
```

### Create Operation Sync

```
User creates group/expense
  ↓
Repository inserts to local DB
  ↓
Repository enqueues operation
  ↓
UI updates immediately (stream emits)
  ↓
SyncService queue watcher (or manual sync)
  ├─ Detects pending operation
  ├─ Uploads to Firestore
  └─ Removes from queue on success
```

### Multi-Device Sync

```
Device A creates group
  ↓
Uploads to Firestore
  ↓
Device B opens app
  ↓
Downloads from Firestore
  ↓
Inserts to local DB via upsertFromSync()
  ↓
Stream emits → UI shows new group
```

---

## Current Issues & Solutions

### Issue 1: Members Not Uploading ✅ FIXED

**Problem:** Upload queue processor was missing `'group_member'` case
**Impact:** Groups uploaded but members didn't → Firestore queries returned 0 groups
**Solution:** Added `_processGroupMemberOperation()` handler
**Status:** Fixed in latest code

### Issue 2: UNIQUE Constraint Error ✅ FIXED

**Problem:** `insertOnConflictUpdate` used wrong conflict target
**Impact:** Migration enqueue failed when re-enqueueing existing items
**Solution:** Changed to check-then-update pattern
**Status:** Fixed in latest code

### Issue 3: Groups Disappear After Refresh 🚧 IN PROGRESS

**Problem:** Download sync returns 0 groups because members not uploaded
**Root Cause:** Issue #1
**Status:** Should be fixed with Issue #1 fix

### Issue 4: Fire-and-Forget Uploads ✅ FIXED

**Problem:** Old code called Firestore upload without awaiting/handling errors
**Impact:** Silent failures, data never synced
**Solution:** Replaced with queue-based system
**Status:** Completely refactored

---

## Known Limitations

### 1. No Real-Time Sync

- **Current:** Sync on app start, manual sync, or 30s queue watcher
- **Future:** Firestore listeners for real-time updates

### 2. No Conflict Resolution UI

- **Current:** Last Write Wins, no user choice
- **Future:** Show conflict UI for important data

### 3. No Offline Indicator

- **Current:** Users don't know if data is synced
- **Future:** UI badges showing sync status

### 4. No Partial Sync

- **Current:** Full sync downloads ALL user data
- **Future:** Incremental sync with timestamps

### 5. No Data Migration on Schema Changes

- **Current:** Manual migration in Drift
- **Future:** Versioned migrations with rollback

### 6. Single User Session

- **Current:** No multi-user or guest mode
- **Future:** Guest accounts, account switching

---

## Architecture Diagrams

### Component Interaction

```
┌─────────────────────────────────────────────────────────────┐
│                        UI Layer                              │
│  (Flutter Widgets + Riverpod Providers)                      │
└────────────────────┬────────────────────────────────────────┘
                     │ Watch Streams
                     ↓
┌─────────────────────────────────────────────────────────────┐
│                   Repository Layer                           │
│  (SyncedGroupRepository, SyncedExpenseRepository)            │
│  ├─ Create/Update/Delete operations                          │
│  ├─ Enqueue to upload queue                                  │
│  └─ Return streams from Local DB                             │
└───┬──────────────────────────────────────────────────────┬──┘
    │                                                        │
    ↓                                                        ↓
┌─────────────────────────┐              ┌──────────────────────────┐
│   Local Database        │              │   Upload Queue           │
│   (Drift/SQLite)        │              │   (sync_queue table)     │
│  ├─ app_groups          │              │  ├─ Pending operations   │
│  ├─ app_group_members   │              │  ├─ Retry logic          │
│  ├─ expenses            │              │  └─ Error tracking       │
│  ├─ expense_shares      │              └──────────┬───────────────┘
│  └─ Streams             │                         │
└───┬─────────────────────┘                         │
    │                                                ↓
    │                              ┌──────────────────────────────┐
    │                              │  Upload Queue Service        │
    │                              │  ├─ Process pending ops      │
    │                              │  ├─ Call Firestore services  │
    │                              │  └─ Remove on success        │
    │                              └──────────┬───────────────────┘
    │                                         │
    ↓                                         ↓
┌─────────────────────────────────────────────────────────────┐
│                   Sync Service                               │
│  ├─ Bidirectional sync (upload + download)                   │
│  ├─ Auto-sync on connectivity change                         │
│  ├─ Queue watcher (30s interval)                             │
│  └─ Migration support (enqueue existing data)                │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ↓
┌─────────────────────────────────────────────────────────────┐
│              Firestore Services                              │
│  (FirestoreGroupService, FirestoreExpenseService)            │
│  ├─ Upload/Download groups, members, expenses                │
│  ├─ Collection group queries                                 │
│  └─ Atomic operations                                        │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ↓
┌─────────────────────────────────────────────────────────────┐
│                  Cloud Firestore                             │
│  /groups/{groupId}/members/{userId}/...                      │
└─────────────────────────────────────────────────────────────┘
```

### Data Flow Timeline

```
Time    Local DB        Upload Queue      Firestore         UI
─────────────────────────────────────────────────────────────────
T0      [empty]         [empty]           [empty]          Loading

T1      Insert group    Enqueue           -                Show group
        ↓               group/123                          (instant!)

T2      -               Processing...     -                -
                        ↓

T3      -               Upload →          Receive          -
                        ↓                 group/123

T4      -               Remove from       Stored           -
                        queue ✓

T5      Download ←      -                 Query returns    -
        from Firestore                    group/123
        ↓

T6      Upsert          -                 -                Still shows
        (no changes)                                       (no flicker)
```

---

## Best Practices

### For Developers

1. **Always use repositories, never call Firestore directly from UI**
2. **Await sync in providers before watching streams**
3. **Use `upsertFromSync()` for downloaded data to avoid re-enqueue**
4. **Test offline scenarios - disable network and verify app works**
5. **Check upload queue for failures - add UI indicator (future)**

### For Testing

1. **Test offline-first**: Airplane mode → create data → go online → verify sync
2. **Test conflicts**: Same data on two devices → sync → verify LWW works
3. **Test migration**: Existing data → update code → verify auto-enqueue
4. **Test retry**: Force failures → verify queue retries → eventual success
5. **Test performance**: Large datasets → verify pagination/lazy loading

---

## Future Enhancements

### Priority 1: Stability

- [ ] Add comprehensive error logging with Sentry/Crashlytics
- [ ] Add sync status UI (synced/syncing/error badges)
- [ ] Add manual retry button for failed queue items
- [ ] Add conflict resolution UI for important edits

### Priority 2: Performance

- [ ] Implement incremental sync (only changes since last sync)
- [ ] Add pagination for large datasets
- [ ] Optimize Firestore queries (composite indexes)
- [ ] Cache Firestore results to reduce reads

### Priority 3: Features

- [ ] Real-time sync with Firestore listeners
- [ ] Multi-device presence indicators
- [ ] Offline change indicators in UI
- [ ] Undo/redo for critical operations

---

## Troubleshooting

### Groups Not Appearing After Creation

1. Check local DB: Should insert immediately
2. Check upload queue: Should enqueue operation
3. Check queue processing: Look for error logs
4. Check Firestore: Verify group + member uploaded

### Groups Disappear After Refresh

1. Check Firestore query: Should find member documents
2. Check member upload: Verify members in Firestore
3. Check download sync: Should insert to local DB
4. Check stream: Should emit after download

### Duplicate Groups

1. Check `upsertFromSync()` usage: Should use this for downloads
2. Check conflict resolution: Verify LWW timestamp logic
3. Check migration: Should not re-enqueue synced data

---

## References

- [Data Schema](./DATA_SCHEMA_COMPLETE.md)
- [Drift Documentation](https://drift.simonbinder.eu/)
- [Firestore Documentation](https://firebase.google.com/docs/firestore)
- [Riverpod Documentation](https://riverpod.dev/)

---

**Document Maintainers:** Development Team
**Review Schedule:** After each major architecture change
**Last Reviewed:** 2025-10-03
