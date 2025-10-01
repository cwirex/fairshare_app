# FairShare Data Model & Schema Review

**Date**: 2025-10-01
**Purpose**: Comprehensive review of all entities, database schemas (local & remote), and data modeling for team discussion

---

## Table of Contents
1. [Overview](#overview)
2. [Domain Entities](#domain-entities)
3. [Local Database Schema (Drift/SQLite)](#local-database-schema-driftsqlite)
4. [Remote Database Schema (Firestore)](#remote-database-schema-firestore)
5. [Data Flow & Sync](#data-flow--sync)
6. [Issues & Inconsistencies](#issues--inconsistencies)
7. [Recommendations](#recommendations)

---

## Overview

### Current Architecture
- **Offline-First**: Local SQLite is source of truth
- **Sync Strategy**: Option D - Upload Queue with bidirectional sync
- **Conflict Resolution**: Last Write Wins (LWW) using `updatedAt` timestamps
- **State Management**: Riverpod with code generation
- **Data Models**: Freezed for immutability and JSON serialization

### Key Principles
- Domain entities are pure, immutable data models
- Drift tables map to SQLite schema
- Firestore documents mirror domain entities (JSON serialization)
- Sync queue tracks pending operations

---

## Domain Entities

### 1. User (`lib/features/auth/domain/entities/user.dart`)

```dart
class User {
  String id;                    // Firebase Auth UID
  String displayName;           // From Google
  String email;                 // From Google
  String avatarUrl;             // From Google (empty if none)
  String phone;                 // Optional
  List<String> groupIds;        // Groups user belongs to
  DateTime? lastSyncTimestamp;  // Last sync time
  DateTime createdAt;           // Account creation
  DateTime updatedAt;           // Last profile update
}
```

**Purpose**: Represents authenticated user with Google Sign-In
**Extensions**: `hasAvatar`, `hasPhone`, `initials`, `hasNeverSynced`, `isMemberOf()`

---

### 2. GroupEntity (`lib/features/groups/domain/entities/group_entity.dart`)

```dart
class GroupEntity {
  String id;                    // 6-digit code OR "personal_{userId}"
  String displayName;           // Group name
  String avatarUrl;             // Group avatar (empty if none)
  bool optimizeSharing;         // Minimize transactions
  bool isOpen;                  // Accept new members
  bool autoExchangeCurrency;    // Auto-convert currencies
  String defaultCurrency;       // Default: 'USD'
  DateTime createdAt;           // Group creation
  DateTime updatedAt;           // Last group update
}
```

**Purpose**: Represents a group for sharing expenses
**Extensions**: `isPersonal` (checks if id starts with "personal_"), `shouldSync` (opposite of isPersonal)
**Special**: Personal groups (prefixed `personal_`) are NEVER synced to Firestore

---

### 3. GroupMemberEntity (`lib/features/groups/domain/entities/group_member_entity.dart`)

```dart
class GroupMemberEntity {
  String groupId;               // Group reference
  String userId;                // User reference
  DateTime joinedAt;            // When user joined
}
```

**Purpose**: Many-to-many relationship between users and groups
**Note**: Simple join table, no additional metadata

---

### 4. ExpenseEntity (`lib/features/expenses/domain/entities/expense_entity.dart`)

```dart
class ExpenseEntity {
  String id;                    // Unique expense ID
  String groupId;               // Group reference
  String title;                 // Expense description
  double amount;                // Total amount
  String currency;              // Currency code (USD, EUR, etc.)
  String paidBy;                // User ID who paid
  bool shareWithEveryone;       // All members split? (default: true)
  DateTime expenseDate;         // When expense occurred
  DateTime createdAt;           // Expense creation
  DateTime updatedAt;           // Last expense update
}
```

**Purpose**: Shared expense in a group
**Note**: If `shareWithEveryone` is false, check `ExpenseShares` for specific splits

---

### 5. ExpenseShareEntity (`lib/features/expenses/domain/entities/expense_share_entity.dart`)

```dart
class ExpenseShareEntity {
  String expenseId;             // Expense reference
  String userId;                // User who owes
  double shareAmount;           // Amount this user owes
}
```

**Purpose**: Individual user's share of an expense
**Note**: Only exists when `shareWithEveryone = false` (custom splits)

---

### 6. PersonalExpenseEntity (`lib/features/expenses/domain/entities/personal_expense_entity.dart`)

```dart
class PersonalExpenseEntity {
  String id;                    // Unique expense ID
  String userId;                // Owner reference
  String title;                 // Expense title
  String description;           // Optional details (empty string if none)
  double amount;                // Amount
  String currency;              // Currency code
  String category;              // Optional category (empty string if none)
  DateTime expenseDate;         // When expense occurred
  DateTime createdAt;           // Creation time
  DateTime updatedAt;           // Last update
}
```

**Purpose**: Personal expense tracking (no group, no sharing)
**Storage**: Firestore: `users/{userId}/personal_expenses/{expenseId}`
**Status**: ⚠️ **NOT YET IMPLEMENTED** - Entity exists but no repository/UI

---

## Local Database Schema (Drift/SQLite)

### Schema Version: 3

### Table: `users`

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | TEXT | PRIMARY KEY | Firebase Auth UID |
| `displayName` | TEXT | NOT NULL | User's display name |
| `email` | TEXT | NOT NULL | User's email |
| `avatarUrl` | TEXT | DEFAULT '' | Avatar URL from Google |
| `phone` | TEXT | DEFAULT '' | Phone number |
| `groupIds` | TEXT | DEFAULT '' | Comma-separated group IDs |
| `lastSyncTimestamp` | DATETIME | NULLABLE | Last sync time |
| `createdAt` | DATETIME | DEFAULT NOW | Account creation |
| `updatedAt` | DATETIME | DEFAULT NOW | Last update |

**Notes**:
- ⚠️ `groupIds` stored as comma-separated string (not normalized)
- Used for user profile, authentication state
- Single row per user (local device only)

---

### Table: `groups`

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | TEXT | PRIMARY KEY | Group code or "personal_{userId}" |
| `displayName` | TEXT | NOT NULL | Group name |
| `avatarUrl` | TEXT | DEFAULT '' | Group avatar URL |
| `optimizeSharing` | BOOLEAN | DEFAULT TRUE | Minimize transactions |
| `isOpen` | BOOLEAN | DEFAULT TRUE | Accept new members |
| `autoExchangeCurrency` | BOOLEAN | DEFAULT FALSE | Auto-convert currencies |
| `defaultCurrency` | TEXT | DEFAULT 'USD' | Default currency |
| `createdAt` | DATETIME | DEFAULT NOW | Creation time |
| `updatedAt` | DATETIME | DEFAULT NOW | Last update |

**Notes**:
- Personal groups (id prefix `personal_`) never sync to Firestore
- Regular groups sync bidirectionally

---

### Table: `group_members`

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `groupId` | TEXT | PRIMARY KEY (composite) | Group reference |
| `userId` | TEXT | PRIMARY KEY (composite) | User reference |
| `joinedAt` | DATETIME | DEFAULT NOW | Join timestamp |

**Notes**:
- Many-to-many join table
- Composite primary key: (groupId, userId)
- No foreign key constraints (offline-first design)

---

### Table: `expenses`

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | TEXT | PRIMARY KEY | Expense ID |
| `groupId` | TEXT | NOT NULL | Group reference |
| `title` | TEXT | NOT NULL | Expense description |
| `amount` | REAL | NOT NULL | Total amount |
| `currency` | TEXT | NOT NULL | Currency code |
| `paidBy` | TEXT | NOT NULL | User ID who paid |
| `shareWithEveryone` | BOOLEAN | DEFAULT TRUE | Split equally? |
| `expenseDate` | DATETIME | NOT NULL | Expense date |
| `createdAt` | DATETIME | DEFAULT NOW | Creation time |
| `updatedAt` | DATETIME | DEFAULT NOW | Last update |

**Notes**:
- Expenses for personal groups (groupId = "personal_{userId}") never sync
- `shareWithEveryone = true`: split equally among all group members
- `shareWithEveryone = false`: check `expense_shares` for custom splits

---

### Table: `expense_shares`

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `expenseId` | TEXT | PRIMARY KEY (composite) | Expense reference |
| `userId` | TEXT | PRIMARY KEY (composite) | User who owes |
| `shareAmount` | REAL | NOT NULL | Amount owed |

**Notes**:
- Only used when `expenses.shareWithEveryone = false`
- Composite primary key: (expenseId, userId)
- No foreign key constraints

---

### Table: `sync_queue`

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | INTEGER | PRIMARY KEY AUTOINCREMENT | Queue entry ID |
| `entityType` | TEXT | NOT NULL | 'expense', 'group', 'user' |
| `entityId` | TEXT | NOT NULL | ID of entity |
| `operationType` | TEXT | NOT NULL | 'create', 'update', 'delete' |
| `metadata` | TEXT | NULLABLE | JSON context (e.g., groupId for deletes) |
| `createdAt` | DATETIME | DEFAULT NOW | When queued |
| `retryCount` | INTEGER | DEFAULT 0 | Retry attempts |
| `lastError` | TEXT | NULLABLE | Last error message |

**Constraints**:
- UNIQUE (entityType, entityId) - ensures one operation per entity

**Notes**:
- Core of Option D sync strategy
- Tracks local changes pending upload
- Max 3 retries before manual intervention needed

---

## Remote Database Schema (Firestore)

### Collection: `users`

**Path**: `/users/{userId}`

```json
{
  "id": "abc123",
  "displayName": "John Doe",
  "email": "john@example.com",
  "avatarUrl": "https://...",
  "phone": "+1234567890",
  "groupIds": ["grp001", "grp002"],
  "lastSyncTimestamp": "2025-01-15T10:30:00Z",
  "createdAt": "2025-01-01T00:00:00Z",
  "updatedAt": "2025-01-15T10:30:00Z"
}
```

**Notes**:
- ⚠️ `groupIds` as array (differs from local comma-separated string)
- Synced on auth and profile updates

---

### Collection: `groups`

**Path**: `/groups/{groupId}`

```json
{
  "id": "grp001",
  "displayName": "Weekend Trip",
  "avatarUrl": "https://...",
  "optimizeSharing": true,
  "isOpen": true,
  "autoExchangeCurrency": false,
  "defaultCurrency": "USD",
  "createdAt": "2025-01-01T00:00:00Z",
  "updatedAt": "2025-01-10T15:00:00Z"
}
```

**Notes**:
- Personal groups (id prefix `personal_`) are **NEVER** stored here
- Used for multi-user shared groups only

---

### Subcollection: `groups/{groupId}/members`

**Path**: `/groups/{groupId}/members/{userId}`

```json
{
  "groupId": "grp001",
  "userId": "abc123",
  "joinedAt": "2025-01-02T12:00:00Z"
}
```

**Notes**:
- Subcollection under each group
- Easy to query "who's in this group"
- Duplicates data from User.groupIds (denormalized)

---

### Subcollection: `groups/{groupId}/expenses`

**Path**: `/groups/{groupId}/expenses/{expenseId}`

```json
{
  "id": "exp001",
  "groupId": "grp001",
  "title": "Hotel",
  "amount": 150.00,
  "currency": "USD",
  "paidBy": "abc123",
  "shareWithEveryone": true,
  "expenseDate": "2025-01-05T00:00:00Z",
  "createdAt": "2025-01-05T20:00:00Z",
  "updatedAt": "2025-01-05T20:00:00Z"
}
```

**Notes**:
- Nested under group (follows Firestore best practices)
- Personal group expenses (groupId = "personal_*") are **NEVER** stored here

---

### Subcollection: `groups/{groupId}/expenses/{expenseId}/shares`

**Path**: `/groups/{groupId}/expenses/{expenseId}/shares/{userId}`

```json
{
  "expenseId": "exp001",
  "userId": "def456",
  "shareAmount": 50.00
}
```

**Notes**:
- Only exists when `shareWithEveryone = false`
- Document ID = userId for easy lookup

---

### Collection: `users/{userId}/personal_expenses` (NOT IMPLEMENTED YET)

**Path**: `/users/{userId}/personal_expenses/{expenseId}`

```json
{
  "id": "pexp001",
  "userId": "abc123",
  "title": "Coffee",
  "description": "Morning coffee",
  "amount": 5.00,
  "currency": "USD",
  "category": "food",
  "expenseDate": "2025-01-15T00:00:00Z",
  "createdAt": "2025-01-15T08:30:00Z",
  "updatedAt": "2025-01-15T08:30:00Z"
}
```

**Status**: ⚠️ **Entity exists, storage path defined, but no implementation**

---

## Data Flow & Sync

### Write Flow (User Creates Expense)

```
1. User taps "Add Expense"
   ↓
2. Repository.createExpense()
   ├─ Database Transaction:
   │  ├─ Insert into `expenses` table
   │  └─ Insert into `sync_queue` (entityType='expense', operationType='create')
   ↓
3. If Online:
   └─ Queue Watcher (30s timer) detects pending operation
      ↓
4. UploadQueueService.processQueue()
   ├─ Read expense from local DB
   ├─ Upload to Firestore: /groups/{groupId}/expenses/{expenseId}
   └─ On success: Remove from sync_queue
```

### Read Flow (Bidirectional Sync)

```
1. SyncService.syncAll() triggered
   ↓
2. Phase 1: Upload
   └─ Process sync_queue → Upload to Firestore
   ↓
3. Phase 2: Download
   ├─ Fetch /groups/{groupId}/expenses
   ├─ For each remote expense:
   │  ├─ Compare updatedAt timestamps
   │  └─ If remote > local: database.upsertExpenseFromSync()
   └─ upsertFromSync() writes directly to DB (bypasses queue)
```

### Conflict Resolution

**Strategy**: Last Write Wins (LWW)

```dart
if (remoteExpense.updatedAt.isAfter(localExpense.updatedAt)) {
  // Remote is newer, update local
  await database.upsertExpenseFromSync(remoteExpense);
} else {
  // Local is newer, keep local (will upload in next sync)
}
```

---

## Issues & Inconsistencies

### 🔴 Critical Issues

#### 1. **PersonalExpenseEntity is Orphaned**
- **Problem**: Entity exists, Firestore path defined, but NO repository, NO UI, NO sync
- **Impact**: Dead code, confusing architecture
- **Decision Needed**:
  - Option A: Delete it (YAGNI)
  - Option B: Implement it (adds complexity)
  - Option C: Merge with ExpenseEntity using `groupId = "personal_{userId}"`

#### 2. **User.groupIds Normalization Mismatch**
- **Local**: Comma-separated string (`"grp001,grp002"`)
- **Remote**: JSON array (`["grp001", "grp002"]`)
- **Problem**: Manual parsing required, error-prone
- **Impact**: Bugs when syncing, hard to query
- **Solution**: Store as JSON string locally? Or use Drift's custom converters?

#### 3. **Denormalized Data Without Consistency Checks**
- `User.groupIds` duplicates `GroupMembers.groupId`
- **Problem**: What if they get out of sync?
- **Impact**: User thinks they're in a group, but no membership record exists
- **Solution**:
  - Remove `User.groupIds` entirely (query from GroupMembers)
  - OR: Add consistency validation

#### 4. **No Foreign Key Constraints**
- **By Design**: Offline-first means no FK constraints
- **Problem**: Orphaned data possible (expense references deleted group)
- **Impact**: UI crashes, data integrity issues
- **Solution**: Application-level validation before deletes

---

### 🟡 Medium Issues

#### 5. **Expense Sharing Logic Incomplete**
- `shareWithEveryone` flag exists
- `ExpenseShares` table exists
- **Problem**: No UI to set custom splits, no calculation logic
- **Impact**: Feature is half-implemented
- **Decision**: Finish it or remove complexity?

#### 6. **Currency Handling is Primitive**
- `currency` stored as string (e.g., "USD")
- `autoExchangeCurrency` flag exists but not implemented
- **Problem**: No exchange rate API, no conversion logic
- **Impact**: Multi-currency groups show incorrect balances
- **Decision**:
  - Phase 1: Single currency per group (enforce)
  - Phase 2: Multi-currency with exchange rates

#### 7. **No Soft Deletes**
- Deletes are hard (data gone forever)
- **Problem**: No undo, no audit trail
- **Impact**: Accidental deletes are permanent
- **Solution**: Add `deletedAt` field, filter in queries

#### 8. **Personal Groups Sync to Local GroupMembers**
- Personal groups (id = "personal_*") add membership records
- **Problem**: Unnecessary since personal groups have 1 member
- **Impact**: Extra DB rows, confusing queries
- **Solution**: Skip GroupMembers for personal groups

---

### 🟢 Minor Issues

#### 9. **Inconsistent Naming**
- Tables: `users`, `groups`, `expenses` (lowercase, plural)
- Entities: `User`, `GroupEntity`, `ExpenseEntity` (PascalCase, mixed singular/plural)
- Drift tables: `AppUsers`, `AppGroups`, `Expenses` (mixed naming)
- **Impact**: Confusing for new devs
- **Solution**: Standardize (e.g., always plural, always "Entity" suffix)

#### 10. **Empty String vs Null**
- `avatarUrl`, `phone`, `description`, `category` use empty string (`''`) as default
- `lastSyncTimestamp`, `metadata` use `null`
- **Problem**: Inconsistent nullability strategy
- **Impact**: Bugs when checking `if (field.isEmpty)` vs `if (field == null)`
- **Solution**: Pick one strategy (prefer nullable for optional fields)

#### 11. **No Validation Rules**
- No min/max on `amount` (negative expenses?)
- No length limits on `title`, `displayName`
- No format validation on `currency` (any string accepted)
- **Impact**: Garbage data possible
- **Solution**: Add validators at entity level

---

## Recommendations

### Immediate Actions (Before Building More Features)

1. **Decide on PersonalExpenseEntity**
   - **Recommend**: Delete it. Use `ExpenseEntity` with personal groups instead.
   - Rationale: Simpler, less code, already have personal groups

2. **Fix User.groupIds Storage**
   - **Recommend**: Remove from User entity entirely, query from GroupMembers
   - Rationale: Single source of truth, no sync issues
   - Alternative: Use Drift JSON converter if you must keep it

3. **Add Application-Level Constraints**
   ```dart
   // Before deleting group:
   if (await hasExpenses(groupId)) {
     throw Exception('Cannot delete group with expenses');
   }
   ```

4. **Standardize Null Handling**
   - **Recommend**: Use nullable types for optional fields
   - Rationale: Type-safe, clear intent, no magic empty strings

---

### Short-Term Improvements

5. **Implement Custom Expense Splits (or Remove)**
   - If keeping: Add UI for custom splits, calculation logic
   - If removing: Delete `ExpenseShares` table, remove `shareWithEveryone` flag

6. **Add Soft Deletes**
   ```dart
   DateTime? deletedAt;  // Add to all entities
   ```
   Filter queries: `where(deletedAt: null)`

7. **Enforce Single Currency Per Group (Phase 1)**
   - Remove `autoExchangeCurrency` flag
   - Validate all expenses match group's `defaultCurrency`

8. **Add Field Validation**
   ```dart
   // In entity
   @Assert('amount > 0', 'Amount must be positive')
   @Assert('title.length <= 100', 'Title too long')
   ```

---

### Long-Term Considerations

9. **Balance Calculation Service**
   - Currently: No balance calculation logic
   - Need: Service to compute who owes whom
   - Consider: Settlement optimization algorithm

10. **Audit Trail / History**
    - Track who edited what, when
    - Use case: "Who changed the expense amount?"
    - Implementation: Add `lastEditedBy` field

11. **Firestore Security Rules**
    - Currently: Not shown in this review
    - Critical: Ensure users can only read/write their own data
    - Check: Do rules match entity structure?

---

## Summary Table

| Entity | Local Table | Firestore Path | Status | Issues |
|--------|-------------|----------------|--------|--------|
| User | `users` | `/users/{id}` | ✅ Implemented | groupIds format mismatch |
| GroupEntity | `groups` | `/groups/{id}` | ✅ Implemented | Personal groups in local only |
| GroupMemberEntity | `group_members` | `/groups/{id}/members/{userId}` | ✅ Implemented | Denormalized with User.groupIds |
| ExpenseEntity | `expenses` | `/groups/{id}/expenses/{id}` | ✅ Implemented | Sharing logic incomplete |
| ExpenseShareEntity | `expense_shares` | `/groups/{id}/expenses/{id}/shares/{userId}` | ⚠️ Partial | No UI, no calculation |
| PersonalExpenseEntity | ❌ None | `/users/{id}/personal_expenses/{id}` | ❌ Not implemented | Orphaned entity |
| SyncQueue | `sync_queue` | ❌ Local only | ✅ Implemented | - |

---

## Questions for Team Discussion

1. **What do we do with PersonalExpenseEntity?**
   - Delete it? Implement it? Merge with ExpenseEntity?

2. **How should we handle User.groupIds?**
   - Remove from User entity? Use JSON converter? Keep as-is?

3. **Do we need custom expense splits?**
   - Full implementation? Remove for MVP? Phase 2 feature?

4. **Currency strategy?**
   - Single currency per group? Multi-currency with conversion? Phase it?

5. **Soft deletes?**
   - Add now? Add later? Never?

6. **Field validation?**
   - Where: Entity level? Repository level? UI level?

7. **Foreign key simulation?**
   - Add application-level checks? Or trust offline-first design?

---

**End of Document**

Please review and come prepared with your thoughts on the questions above. This will guide our next steps in refactoring the data model.
