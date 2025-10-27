# FairShare Data Schema - Complete Reference

**Date**: 2025-10-21
**Schema Version**: 1 (clean slate for multi-user architecture)
**Status**: Production Ready

---

## Table of Contents

1. [Overview](#overview)
2. [Complete Schema Diagram](#complete-schema-diagram)
3. [Local Database (SQLite/Drift)](#local-database-sqlitedrift)
4. [Remote Database (Firestore)](#remote-database-firestore)
5. [Design Decisions & Rationale](#design-decisions--rationale)
6. [Data Flow & Sync Strategy](#data-flow--sync-strategy)
7. [Key Concepts](#key-concepts)

---

## Overview

### Architecture Pattern

- **Offline-First**: Local SQLite is the source of truth
- **Sync Strategy**: Upload queue with bidirectional sync
- **Conflict Resolution**: Last Write Wins (LWW) using timestamps
- **Data Integrity**: Foreign key constraints with CASCADE deletes

### Core Principles

1. **Single Source of Truth**: `group_members` table for memberships (no denormalized `groupIds`)
2. **Unified Expense Model**: One `ExpenseEntity` for both personal and shared expenses
3. **Consistent Sync**: All expenses sync (including personal group expenses)
4. **Privacy by Design**: Personal group metadata stays local

---

## Complete Schema Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                        LOCAL DATABASE (SQLite)                   │
└─────────────────────────────────────────────────────────────────┘

users                              groups
┌──────────────────┐              ┌──────────────────┐
│ id (PK)          │              │ id (PK)          │
│ displayName      │              │ displayName      │
│ email            │              │ avatarUrl        │
│ avatarUrl        │              │ isPersonal       │ ← KEY FLAG
│ phone            │              │ defaultCurrency  │
│ lastSyncTimestamp│              │ createdAt        │
│ createdAt        │              │ updatedAt        │
│ updatedAt        │              │ deletedAt        │ ← SOFT DELETE
└──────────────────┘              └──────────────────┘
                                           │
                                           │
                    ┌──────────────────────┴──────────────────────┐
                    │                                              │
                    ▼                                              ▼
         group_members (FK)                            expenses (FK)
         ┌──────────────────┐                         ┌──────────────────┐
         │ groupId (PK, FK) │────┐                    │ id (PK)          │
         │ userId (PK, FK)  │────┼────────────────┐   │ groupId (FK)     │───┐
         │ joinedAt         │    │                │   │ title            │   │
         └──────────────────┘    │                │   │ amount           │   │
                                 │                │   │ currency         │   │
                                 │                │   │ paidBy           │   │
                                 │                │   │ shareWithEveryone│   │
                                 │                │   │ expenseDate      │   │
                                 │                │   │ createdAt        │   │
                                 │                │   │ updatedAt        │   │
                                 │                │   │ deletedAt        │   │
                                 │                │   └──────────────────┘   │
                                 │                │                          │
                                 ▼                ▼                          ▼
                      group_balances (FK)    expense_shares (FK)
                      ┌──────────────────┐   ┌──────────────────┐
                      │ groupId (PK, FK) │   │ expenseId (PK,FK)│
                      │ userId (PK, FK)  │   │ userId (PK, FK)  │
                      │ balance          │   │ shareAmount      │
                      │ updatedAt        │   └──────────────────┘
                      └──────────────────┘

                      sync_queue
                      ┌──────────────────┐
                      │ id (PK)          │
                      │ entityType       │
                      │ entityId         │
                      │ operationType    │
                      │ metadata         │
                      │ createdAt        │
                      │ retryCount       │
                      │ lastError        │
                      └──────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                    REMOTE DATABASE (Firestore)                   │
└─────────────────────────────────────────────────────────────────┘

/users/{userId}                      /groups/{groupId}  ← ONLY if isPersonal=false
┌──────────────────┐                ┌──────────────────┐
│ id               │                │ id               │
│ displayName      │                │ displayName      │
│ email            │                │ avatarUrl        │
│ avatarUrl        │                │ isPersonal       │
│ phone            │                │ defaultCurrency  │
│ lastSyncTimestamp│                │ createdAt        │
│ createdAt        │                │ updatedAt        │
│ updatedAt        │                │ deletedAt        │
└──────────────────┘                └──────────────────┘
                                            │
                                            ├─── /members/{userId}
                                            │    ┌──────────────────┐
                                            │    │ groupId          │
                                            │    │ userId           │
                                            │    │ joinedAt         │
                                            │    └──────────────────┘
                                            │
                                            ├─── /expenses/{expenseId}  ← ALL expenses
                                            │    ┌──────────────────┐     (including personal!)
                                            │    │ id               │
                                            │    │ groupId          │
                                            │    │ title            │
                                            │    │ amount           │
                                            │    │ currency         │
                                            │    │ paidBy           │
                                            │    │ shareWithEveryone│
                                            │    │ expenseDate      │
                                            │    │ createdAt        │
                                            │    │ updatedAt        │
                                            │    │ deletedAt        │
                                            │    └──────────────────┘
                                            │         │
                                            │         └─── /shares/{userId}
                                            │              ┌──────────────────┐
                                            │              │ expenseId        │
                                            │              │ userId           │
                                            │              │ shareAmount      │
                                            │              └──────────────────┘
                                            │
                                            └─── /balances/{userId}  ← Future
                                                 ┌──────────────────┐
                                                 │ balance          │
                                                 │ updatedAt        │
                                                 └──────────────────┘
```

---

## Local Database (SQLite/Drift)

### 1. `users` Table

**Purpose**: Store authenticated user profile data

| Column              | Type     | Constraints | Description                     |
| ------------------- | -------- | ----------- | ------------------------------- |
| `id`                | TEXT     | PRIMARY KEY | Firebase Auth UID               |
| `displayName`       | TEXT     | NOT NULL    | User's display name from Google |
| `email`             | TEXT     | NOT NULL    | User's email from Google        |
| `avatarUrl`         | TEXT     | DEFAULT ''  | Avatar URL from Google          |
| `phone`             | TEXT     | NULLABLE    | Optional phone number           |
| `lastSyncTimestamp` | DATETIME | NULLABLE    | Last successful sync time       |
| `createdAt`         | DATETIME | NOT NULL    | Account creation timestamp      |
| `updatedAt`         | DATETIME | NOT NULL    | Last profile update timestamp   |

**Key Changes**:

- ❌ Removed `groupIds` (was comma-separated string) → Single source of truth is now `group_members` table
- ✅ Made `phone` nullable (was default empty string)

---

### 2. `groups` Table

**Purpose**: Store all groups (both shared and personal)

| Column            | Type     | Constraints             | Description                                       |
| ----------------- | -------- | ----------------------- | ------------------------------------------------- |
| `id`              | TEXT     | PRIMARY KEY             | Group ID (6-digit code or `{userId}`)             |
| `displayName`     | TEXT     | NOT NULL                | Group name                                        |
| `avatarUrl`       | TEXT     | DEFAULT ''              | Group avatar URL                                  |
| `isPersonal`      | BOOLEAN  | NOT NULL, DEFAULT FALSE | **Whether this is a personal (local-only) group** |
| `defaultCurrency` | TEXT     | NOT NULL, DEFAULT 'USD' | Default currency for the group                    |
| `createdAt`       | DATETIME | NOT NULL                | Group creation timestamp                          |
| `updatedAt`       | DATETIME | NOT NULL                | Last update timestamp                             |
| `lastActivityAt`  | DATETIME | NOT NULL                | **Last activity timestamp (for hybrid listeners)** |
| `deletedAt`       | DATETIME | NULLABLE                | **Soft delete timestamp**                         |

**Key Changes**:

- ✅ Added `isPersonal` flag (distinguishes personal from shared groups)
- ✅ Added `deletedAt` for soft deletes
- ❌ Removed `optimizeSharing`, `isOpen`, `autoExchangeCurrency` (unused complexity)

**Personal Group Identifier**: `id = "$userId"` AND `isPersonal = true`

---

### 3. `group_members` Table

**Purpose**: Many-to-many relationship between users and groups (THE single source of truth for memberships)

| Column     | Type     | Constraints                             | Description                |
| ---------- | -------- | --------------------------------------- | -------------------------- |
| `groupId`  | TEXT     | PRIMARY KEY, FK → `groups.id` (CASCADE) | Group reference            |
| `userId`   | TEXT     | PRIMARY KEY, FK → `users.id` (CASCADE)  | User reference             |
| `joinedAt` | DATETIME | NOT NULL                                | When user joined the group |

**Key Changes**:

- ✅ Added foreign key constraints with CASCADE delete
- ✅ This is now the ONLY source of truth for "which user is in which group"

---

### 4. `group_balances` Table ✨ NEW

**Purpose**: Calculated balances for performance (eliminates need to recalculate from all expenses)

| Column      | Type     | Constraints                             | Description                                    |
| ----------- | -------- | --------------------------------------- | ---------------------------------------------- |
| `groupId`   | TEXT     | PRIMARY KEY, FK → `groups.id` (CASCADE) | Group reference                                |
| `userId`    | TEXT     | PRIMARY KEY, FK → `users.id` (CASCADE)  | User reference                                 |
| `balance`   | REAL     | NOT NULL, DEFAULT 0.0                   | Net balance (positive = owed, negative = owes) |
| `updatedAt` | DATETIME | NOT NULL                                | Last balance calculation time                  |

**Purpose**:

- Fast balance lookups without scanning all expenses
- Positive balance = group owes this user
- Negative balance = user owes the group

---

### 5. `expenses` Table

**Purpose**: Store ALL expenses (from both shared and personal groups)

| Column              | Type     | Constraints                          | Description                    |
| ------------------- | -------- | ------------------------------------ | ------------------------------ |
| `id`                | TEXT     | PRIMARY KEY                          | Expense ID                     |
| `groupId`           | TEXT     | NOT NULL, FK → `groups.id` (CASCADE) | Group reference                |
| `title`             | TEXT     | NOT NULL                             | Expense description            |
| `amount`            | REAL     | NOT NULL                             | Total amount                   |
| `currency`          | TEXT     | NOT NULL                             | Currency code (USD, EUR, etc.) |
| `paidBy`            | TEXT     | NOT NULL                             | User ID who paid               |
| `shareWithEveryone` | BOOLEAN  | NOT NULL, DEFAULT TRUE               | Whether to split equally       |
| `expenseDate`       | DATETIME | NOT NULL                             | When expense occurred          |
| `createdAt`         | DATETIME | NOT NULL                             | Creation timestamp             |
| `updatedAt`         | DATETIME | NOT NULL                             | Last update timestamp          |
| `deletedAt`         | DATETIME | NULLABLE                             | **Soft delete timestamp**      |

**Key Changes**:

- ✅ Added `deletedAt` for soft deletes
- ✅ All queries filter `WHERE deletedAt IS NULL`
- ✅ Foreign key to groups with CASCADE

**Unified Model**: No separate `PersonalExpenseEntity` - personal expenses are just `ExpenseEntity` records with `groupId = "userId"`

---

### 6. `expense_shares` Table

**Purpose**: Custom expense splits (when `shareWithEveryone = false`)

| Column        | Type | Constraints                               | Description                  |
| ------------- | ---- | ----------------------------------------- | ---------------------------- |
| `expenseId`   | TEXT | PRIMARY KEY, FK → `expenses.id` (CASCADE) | Expense reference            |
| `userId`      | TEXT | PRIMARY KEY, FK → `users.id` (CASCADE)    | User who shares this expense |
| `shareAmount` | REAL | NOT NULL                                  | Amount this user owes        |

**Usage**: Only exists when `expenses.shareWithEveryone = false`

---

### 7. `sync_queue` Table

**Purpose**: Track pending sync operations (Option D: Upload Queue strategy)

| Column          | Type     | Constraints                            | Description                              |
| --------------- | -------- | -------------------------------------- | ---------------------------------------- |
| `id`            | INTEGER  | PRIMARY KEY AUTOINCREMENT              | Queue entry ID                           |
| `ownerId`       | TEXT     | NOT NULL, FK → `users.id` (CASCADE)    | **User who initiated this operation**    |
| `entityType`    | TEXT     | NOT NULL                               | 'expense', 'group', 'user'               |
| `entityId`      | TEXT     | NOT NULL                               | ID of entity to sync                     |
| `operationType` | TEXT     | NOT NULL                               | 'create', 'update', 'delete'             |
| `metadata`      | TEXT     | NULLABLE                               | JSON context (e.g., groupId for deletes) |
| `createdAt`     | DATETIME | NOT NULL                               | When queued                              |
| `retryCount`    | INTEGER  | NOT NULL, DEFAULT 0                    | Number of retry attempts                 |
| `lastError`     | TEXT     | NULLABLE                               | Last error message                       |

**Unique Constraint**: `(ownerId, entityType, entityId)` - ensures one operation per entity per user

**Key Design:** `ownerId` enables multi-user architecture by scoping sync queue entries to prevent cross-user data leakage on sign-out.

---

## Remote Database (Firestore)

### Collection: `/users/{userId}`

**Purpose**: User profile data

```json
{
  "id": "user123",
  "displayName": "John Doe",
  "email": "john@example.com",
  "avatarUrl": "https://...",
  "phone": "+1234567890",
  "lastSyncTimestamp": "2025-01-15T10:30:00Z",
  "createdAt": "2025-01-01T00:00:00Z",
  "updatedAt": "2025-01-15T10:30:00Z"
}
```

**Key Changes**:

- ❌ No `groupIds` array (removed - use membership queries instead)

---

### Collection: `/groups/{groupId}`

**ONLY synced if `isPersonal = false`**

```json
{
  "id": "ABC123",
  "displayName": "Weekend Trip",
  "avatarUrl": "https://...",
  "isPersonal": false,
  "defaultCurrency": "USD",
  "createdAt": "2025-01-01T00:00:00Z",
  "updatedAt": "2025-01-10T15:00:00Z",
  "deletedAt": null
}
```

**⚠️ Important**: Personal groups (`isPersonal: true`) are NEVER synced to this collection.

---

### Subcollection: `/groups/{groupId}/members/{userId}`

**Purpose**: Group membership (denormalized for query performance)

```json
{
  "groupId": "ABC123",
  "userId": "user123",
  "joinedAt": "2025-01-02T12:00:00Z"
}
```

**Synced for**: Shared groups only (personal group members are NOT synced)

---

### Subcollection: `/groups/{groupId}/expenses/{expenseId}`

**Purpose**: ALL expenses (including from personal groups!)

```json
{
  "id": "exp123",
  "groupId": "ABC123", // or "user123"
  "title": "Hotel",
  "amount": 150.0,
  "currency": "USD",
  "paidBy": "user123",
  "shareWithEveryone": true,
  "expenseDate": "2025-01-05T00:00:00Z",
  "createdAt": "2025-01-05T20:00:00Z",
  "updatedAt": "2025-01-05T20:00:00Z",
  "deletedAt": null
}
```

**✨ Key Design**: Personal expenses ARE synced here (for cloud backup), even though their parent group is not!

- Path: `/groups/{userId}/expenses/{expenseId}`

---

### Subcollection: `/groups/{groupId}/expenses/{expenseId}/shares/{userId}`

**Purpose**: Custom expense splits

```json
{
  "expenseId": "exp123",
  "userId": "user456",
  "shareAmount": 50.0
}
```

---

### Subcollection: `/groups/{groupId}/balances/{userId}` ✨ FUTURE

**Purpose**: Pre-calculated balances (Cloud Function will maintain)

```json
{
  "balance": 150.5,
  "updatedAt": "2025-01-15T10:30:00Z"
}
```

---

## Design Decisions & Rationale

### 1. **Why Remove `User.groupIds`?**

**Problem**:

- Denormalized data (duplicates `group_members` table)
- Array stored as comma-separated string in SQLite (brittle)
- Gets out of sync with actual memberships

**Solution**:

- Single source of truth: `group_members` join table
- Query user's groups via JOIN: `SELECT groups WHERE id IN (SELECT groupId FROM group_members WHERE userId = ?)`

**Benefits**:

- ✅ No sync issues
- ✅ Relational integrity
- ✅ Simpler logic

---

### 3. **Why Delete `PersonalExpenseEntity`?**

**Problem**:

- Duplicate expense model
- More code to maintain
- Inconsistent handling

**Solution**:

- One unified `ExpenseEntity`
- Personal expenses = `ExpenseEntity` with `groupId = "userId"`
- All expenses use same sync path: `/groups/{groupId}/expenses/`

**Benefits**:

- ✅ Single expense model
- ✅ Same sync logic
- ✅ Less code
- ✅ Personal expenses backed up to cloud

---

### 4. **Why Soft Deletes?**

**Problem**:

- Hard deletes are permanent
- No undo capability
- No audit trail

**Solution**:

- Add `deletedAt` timestamp to groups and expenses
- Filter queries: `WHERE deletedAt IS NULL`
- Implement `softDelete()` and `restore()` methods

**Benefits**:

- ✅ Undo functionality
- ✅ Accidental delete recovery
- ✅ Audit capability

---

### 5. **Why Foreign Key Constraints?**

**Problem**:

- Orphaned data possible (expense references deleted group)
- No referential integrity

**Solution**:

- Add FK constraints with CASCADE delete
- `expenses.groupId` → `groups.id` (CASCADE)
- `group_members.groupId` → `groups.id` (CASCADE)
- etc.

**Benefits**:

- ✅ Data integrity at DB level
- ✅ Automatic cleanup
- ✅ Prevents orphaned records

---

### 6. **Why Sync Personal Expenses but Not Personal Groups?**

**Problem**:

- Personal groups shouldn't be visible to other users
- But personal expenses need cloud backup

**Solution**:

- Personal groups: NOT synced (privacy)
- Personal expenses: SYNCED to `/groups/{userId}/expenses/` (backup)

**Benefits**:

- ✅ Privacy: Group metadata stays local
- ✅ Backup: Expenses saved to cloud
- ✅ Consistency: All expenses use same sync path
- ✅ Cross-device: Personal expenses available everywhere

**Example**:

```
User creates personal expense:
1. Personal group exists: id="user123", isPersonal=true
2. Expense created: groupId="user123"
3. Group NOT synced (isPersonal=true)
4. Expense IS synced to: /groups/user123/expenses/exp123 ✅
```

---

## Data Flow & Sync Strategy

### Write Flow (User Creates Expense)

```
1. User creates expense in UI
   ↓
2. Repository.createExpense()
   ├─ Insert into `expenses` table
   ├─ Add to `sync_queue` (for ALL expenses, including personal)
   ↓
3. If Online:
   └─ UploadQueueService processes queue (every 30s)
      ├─ Read expense from local DB
      ├─ Upload to Firestore: /groups/{groupId}/expenses/{expenseId}
      └─ On success: Remove from sync_queue
```

### Read Flow (Bidirectional Sync)

```
1. SyncService.syncAll()
   ↓
2. Phase 1: Upload
   └─ Process sync_queue → Upload to Firestore
   ↓
3. Phase 2: Download
   ├─ Fetch /groups/{groupId}/expenses
   ├─ For each remote expense:
   │  ├─ Compare updatedAt timestamps (Last Write Wins)
   │  └─ If remote > local: database.upsertExpenseFromSync()
   └─ upsertFromSync() bypasses queue (no loop)
```

### Personal Group Flow

```
1. User signs in
   ↓
2. GroupInitializationService.ensurePersonalGroupExists()
   ├─ Check if personal group exists
   └─ If not:
      ├─ Create group: id="userId", isPersonal=true
      ├─ Save to local DB only (NOT added to sync_queue)
      └─ Add user as member
```

### Sync Queue Logic

```
LocalGroupRepository.createGroup(group):
  - Insert to local DB
  - IF !group.isPersonal:  ← Check here
      ├─ Add to sync_queue
      └─ Will upload to /groups/{groupId}

LocalExpenseRepository.createExpense(expense):
  - Insert to local DB
  - ALWAYS add to sync_queue  ← No check needed
      └─ Will upload to /groups/{groupId}/expenses/{expenseId}
```

---

## Key Concepts

### Concept 1: Personal Groups

- **Definition**: Groups with `isPersonal = true`
- **ID Format**: `"userId"`
- **Sync Behavior**: Group metadata NOT synced, but expenses ARE synced
- **Purpose**: Private expense tracking with cloud backup

### Concept 2: Shared Groups

- **Definition**: Groups with `isPersonal = false`
- **ID Format**: 6-digit alphanumeric code
- **Sync Behavior**: Everything synced (group + members + expenses)
- **Purpose**: Collaborative expense sharing

### Concept 3: Soft Deletes

- **Implementation**: `deletedAt` timestamp
- **Active Items**: `WHERE deletedAt IS NULL`
- **Deleted Items**: `WHERE deletedAt IS NOT NULL`
- **Restore**: Set `deletedAt = NULL`

### Concept 4: Last Write Wins (LWW)

- **Conflict Resolution**: Compare `updatedAt` timestamps
- **Rule**: `if (remote.updatedAt > local.updatedAt) { use remote }`
- **Bypass**: Sync operations use `upsertFromSync()` to avoid queue loops

### Concept 5: Upload Queue (Option D)

- **Local Changes**: Tracked in `sync_queue` table
- **Processing**: Background service checks every 30s
- **Retry Logic**: Max 3 retries, then manual intervention
- **Deduplication**: UNIQUE constraint on `(entityType, entityId)`

---

## Summary: What Gets Synced?

| Entity                    | Condition            | Local Storage          | Firestore Path                                           | Cloud Backup?           |
| ------------------------- | -------------------- | ---------------------- | -------------------------------------------------------- | ----------------------- |
| **User**                  | Always               | `users` table          | `/users/{userId}`                                        | ✅ Yes                  |
| **Shared Group**          | `isPersonal = false` | `groups` table         | `/groups/{groupId}`                                      | ✅ Yes                  |
| **Personal Group**        | `isPersonal = true`  | `groups` table         | ❌ NOT synced                                            | ❌ No (local only)      |
| **Shared Group Member**   | Group is shared      | `group_members` table  | `/groups/{groupId}/members/{userId}`                     | ✅ Yes                  |
| **Personal Group Member** | Group is personal    | `group_members` table  | ❌ NOT synced                                            | ❌ No                   |
| **Any Expense**           | Always               | `expenses` table       | `/groups/{groupId}/expenses/{expenseId}`                 | ✅ Yes (even personal!) |
| **Expense Share**         | Always               | `expense_shares` table | `/groups/{groupId}/expenses/{expenseId}/shares/{userId}` | ✅ Yes                  |

---

## Final Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                           USER DEVICE                            │
│                                                                   │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────────────┐ │
│  │     UI      │───→│ Repository  │───→│  SQLite Database    │ │
│  └─────────────┘    └─────────────┘    │  (Source of Truth)  │ │
│                            │            └─────────────────────┘ │
│                            │                                     │
│                            ↓                                     │
│                     ┌─────────────┐                             │
│                     │ Sync Queue  │                             │
│                     └─────────────┘                             │
│                            │                                     │
└────────────────────────────┼─────────────────────────────────────┘
                             │
                             ↓  (Upload Queue Service)

                    ┌────────────────┐
                    │   FIRESTORE    │
                    └────────────────┘
                             │
        ┌────────────────────┼────────────────────┐
        │                    │                    │
        ▼                    ▼                    ▼
   /users/{id}         /groups/{id}    /groups/{id}/expenses/
   (ALL users)      (ONLY isPersonal   (ALL expenses including
                     = false)           personal group expenses!)
```

---

**End of Schema Documentation**

This schema provides:

- ✅ **Data Integrity**: Foreign keys, constraints, validation
- ✅ **Privacy**: Personal groups stay local
- ✅ **Backup**: All expenses (including personal) backed up
- ✅ **Performance**: Balance table for fast calculations
- ✅ **Flexibility**: Soft deletes, conflict resolution
- ✅ **Simplicity**: One expense model, consistent sync

**Status**: Production ready, fully implemented, tested ✅
