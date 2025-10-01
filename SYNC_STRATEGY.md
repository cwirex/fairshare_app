# Sync Strategy Discussion

## Context

We're building an offline-first expense sharing app with:
- **Local database**: SQLite (via Drift) - source of truth
- **Remote database**: Cloud Firestore - for multi-device sync
- **Architecture**: Repository pattern with offline-first approach

The app must work completely offline, and sync changes when connectivity is available.

## Previous Approach (Removed)

We initially used a boolean `isSynced` flag on all entities:
- `isSynced: false` → item has local changes, needs to be uploaded
- `isSynced: true` → item is in sync with Firestore

**Problems with this approach:**
1. **Redundant with existing fields**: We already have `updatedAt` timestamp on all entities
2. **Bidirectional confusion**: The flag was used for both upload and download sync, making logic complex
3. **No temporal information**: Can't tell WHEN something was synced
4. **Doesn't handle conflicts well**: No way to determine which version is newer

## Current Challenge

We removed `isSynced` to use timestamp-based sync, but now face a key question:

**How do we track offline changes that need to be uploaded when connection returns?**

## Proposed Solutions

### Option A: Pure Timestamp Approach

Use `updatedAt` timestamps for everything:

**For Downloads (Firestore → Local):**
```dart
// User entity tracks when they last synced each group
class User {
  Map<String, DateTime> lastSyncTimestamp; // groupId → timestamp
}

// When syncing, download items updated after last sync
if (group.updatedAt > user.lastSyncTimestamp[groupId]) {
  // Download this group
}
```

**For Uploads (Local → Firestore):**
```dart
class User {
  DateTime? lastSuccessfulUploadTime;
}

// On connection restore, upload items modified since last upload
if (expense.updatedAt > user.lastSuccessfulUploadTime) {
  // Upload this expense
}
```

**Pros:**
- No additional fields needed
- Single source of truth (timestamps)
- Natural conflict resolution (newest wins)
- Works across devices

**Cons:**
- Need to track `lastSuccessfulUploadTime` globally or per-group
- More complex logic to determine what needs upload
- Risk of uploading everything if timestamp tracking fails
- Edge case: What if local device clock is wrong?

### Option B: Unidirectional Upload Flag

Add a simple `needsUpload` boolean flag:

```dart
class ExpenseEntity {
  bool needsUpload; // true if local changes haven't been uploaded yet
  DateTime updatedAt; // for download sync and conflict resolution
}
```

**For Downloads (Firestore → Local):**
- Use timestamp comparison: `if (remote.updatedAt > local.updatedAt)`

**For Uploads (Local → Firestore):**
- Use flag: `if (expense.needsUpload)`
- Set `needsUpload = true` on create/update
- Set `needsUpload = false` after successful upload

**Pros:**
- Simple and explicit
- Easy to query: "give me all items with needsUpload=true"
- No risk of uploading everything accidentally
- Independent of device clock issues
- Clear separation: flag for upload, timestamp for download

**Cons:**
- Additional field on all entities (though just one boolean)
- Still somewhat like the old `isSynced` approach

### Option C: Hybrid with Dirty Tracking

Combine timestamps with a lightweight dirty flag:

```dart
class ExpenseEntity {
  DateTime updatedAt;        // For conflict resolution & download sync
  DateTime? lastUploadedAt;  // Nullable - null means never uploaded
}

// Upload needed if:
bool needsUpload = lastUploadedAt == null || updatedAt > lastUploadedAt;
```

**Pros:**
- Know exactly when item was last uploaded
- Can identify items that have never been synced (null)
- Still use timestamps (consistent approach)
- Better debugging (can see upload history)

**Cons:**
- Two timestamps per entity (more storage)
- Need to maintain `lastUploadedAt` correctly

### Option D: Separate Upload Queue Table

Don't modify entities at all - use a separate sync queue:

```sql
CREATE TABLE upload_queue (
  entity_type TEXT,     -- 'expense', 'group', etc.
  entity_id TEXT,
  created_at TIMESTAMP,
  PRIMARY KEY (entity_type, entity_id)
);
```

When creating/updating locally:
```dart
await database.insertExpense(expense);
await database.addToUploadQueue('expense', expense.id);
```

After successful upload:
```dart
await database.removeFromUploadQueue('expense', expense.id);
```

**Pros:**
- Entities stay clean (no sync-related fields)
- Clear separation of concerns
- Easy to see what's pending upload
- Can add retry logic, priority, etc.
- Can batch uploads efficiently

**Cons:**
- Additional table to maintain
- Need to keep queue in sync with actual operations
- More complex if delete operations need tracking

## Personal Expenses Consideration

Personal groups (ID: `personal_{userId}`) are **local-only** and never synced to Firestore:
- Skip all upload logic for items in personal groups
- No timestamp tracking needed
- Simpler implementation

## Recommendations Needed

**Questions for the team:**

1. **Offline-first priority**: How important is it that users can work completely offline for extended periods? Days? Weeks?

2. **Conflict resolution**: If two devices modify the same expense offline, should:
   - Newest timestamp win (automatic)?
   - User be prompted to resolve?
   - Last sync win?

3. **Sync granularity**: Should we track sync status per:
   - Entity (each expense individually)?
   - Group (all expenses in a group)?
   - User (everything for a user)?

4. **Failure recovery**: If upload fails halfway through, how do we handle:
   - Retry logic?
   - Partial sync states?
   - Network interruptions?

5. **Complexity vs. Simplicity**: What's more important:
   - Simpler code (Option B - upload flag)?
   - No extra fields (Option A - pure timestamps)?
   - Best debugging (Option C - dual timestamps)?
   - Cleanest architecture (Option D - separate queue)?

## Current State

As of now:
- **Removed**: `isSynced` boolean from all entities
- **Kept**: `updatedAt`, `createdAt` timestamps on all entities
- **Added**: `lastSyncTimestamp` on User entity (for download sync)
- **TODO**: Decide on upload tracking strategy

The download sync (Firestore → Local) works with timestamps. We need to decide on upload sync (Local → Firestore).

## Implementation Impact

Each option affects:
- **Database schema**: Fields to add/modify
- **Repository logic**: How create/update methods work
- **Sync service**: How to query items needing upload
- **Testing**: How to verify sync correctness
- **User experience**: Sync indicator, offline capability

## Next Steps

1. Team discussion on this document
2. Choose an approach based on priorities
3. Update entity models accordingly
4. Implement sync service with chosen strategy
5. Test offline scenarios thoroughly
6. Document sync behavior for users
