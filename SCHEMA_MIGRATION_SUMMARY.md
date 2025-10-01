# Schema Migration Summary

## Date: 2025-10-01

This document summarizes the major data model refactoring implemented based on the reviewed recommendations in `DATA_MODEL_REVIEWED.md`.

---

## Key Changes Implemented

### 1. **Removed User.groupIds Field** ✅
- **Rationale**: Eliminated denormalized data that caused inconsistency
- **Changes**:
  - Removed `groupIds` from `User` entity
  - Removed `groupIds` column from `AppUsers` table
  - Updated all database operations and conversion methods
  - **Single source of truth**: `group_members` table via joins

### 2. **Added isPersonal Flag to Groups** ✅
- **Rationale**: Unified personal and shared groups under one model
- **Changes**:
  - Added `isPersonal` boolean field to `GroupEntity`
  - Added `isPersonal` column to `AppGroups` table
  - Updated `GroupEntityX` extension methods
  - Updated `FirestoreGroupService` to use `isPersonal` flag instead of ID prefix checking

### 3. **Added Soft Delete Support** ✅
- **Rationale**: Prevent accidental data loss, enable undo functionality
- **Changes**:
  - Added `deletedAt` nullable DateTime to `GroupEntity`
  - Added `deletedAt` nullable DateTime to `ExpenseEntity`
  - Added `deletedAt` column to `AppGroups` table
  - Added `deletedAt` column to `Expenses` table
  - Added extension methods: `isDeleted`, `isActive`, `isSettled`

### 4. **Created Group Balances System** ✅
- **Rationale**: Efficient balance tracking without recalculating all expenses
- **Changes**:
  - Created `GroupBalanceEntity` with balance tracking
  - Created `AppGroupBalances` table for local storage
  - Added helpful extension methods: `isOwed`, `owes`, `isSettled`, `absoluteBalance`
  - **Note**: Balance calculation service to be implemented in future

### 5. **Removed PersonalExpenseEntity** ✅
- **Rationale**: Unified expense model; personal expenses = expenses in personal groups
- **Changes**:
  - Deleted `personal_expense_entity.dart` and generated files
  - Personal expenses now use regular `ExpenseEntity` with `isPersonal` group

### 6. **Added Foreign Key Constraints** ✅
- **Rationale**: Ensure data integrity at database level
- **Changes**:
  - `AppGroupMembers.groupId` → references `AppGroups.id` (CASCADE)
  - `AppGroupMembers.userId` → references `AppUsers.id` (CASCADE)
  - `AppGroupBalances.groupId` → references `AppGroups.id` (CASCADE)
  - `AppGroupBalances.userId` → references `AppUsers.id` (CASCADE)
  - `Expenses.groupId` → references `AppGroups.id` (CASCADE)
  - `ExpenseShares.expenseId` → references `Expenses.id` (CASCADE)
  - `ExpenseShares.userId` → references `AppUsers.id` (CASCADE)

### 7. **Improved Nullable Handling** ✅
- **Changes**:
  - Changed `User.phone` from `@Default('')` to nullable `String?`
  - Changed `User.avatarUrl` remains as `@Default('')` for backward compatibility
  - Consistent nullable strategy for optional fields

### 8. **Database Schema Version Update** ✅
- Updated from schema version 4 to **version 5**
- Migration strategy: Drop and recreate all tables (acceptable as data wipe was agreed)

---

## New Database Schema (Version 5)

### Tables Structure

#### `users`
| Column | Type | Constraints |
|--------|------|-------------|
| id | TEXT | PRIMARY KEY |
| displayName | TEXT | NOT NULL |
| email | TEXT | NOT NULL |
| avatarUrl | TEXT | DEFAULT '' |
| phone | TEXT | NULLABLE |
| lastSyncTimestamp | DATETIME | NULLABLE |
| createdAt | DATETIME | NOT NULL |
| updatedAt | DATETIME | NOT NULL |

#### `groups`
| Column | Type | Constraints |
|--------|------|-------------|
| id | TEXT | PRIMARY KEY |
| displayName | TEXT | NOT NULL |
| avatarUrl | TEXT | DEFAULT '' |
| isPersonal | BOOLEAN | NOT NULL DEFAULT FALSE |
| defaultCurrency | TEXT | NOT NULL DEFAULT 'USD' |
| createdAt | DATETIME | NOT NULL |
| updatedAt | DATETIME | NOT NULL |
| deletedAt | DATETIME | NULLABLE |

#### `group_members`
| Column | Type | Constraints |
|--------|------|-------------|
| groupId | TEXT | PRIMARY KEY, FK → groups.id (CASCADE) |
| userId | TEXT | PRIMARY KEY, FK → users.id (CASCADE) |
| joinedAt | DATETIME | NOT NULL |

#### `group_balances` (NEW)
| Column | Type | Constraints |
|--------|------|-------------|
| groupId | TEXT | PRIMARY KEY, FK → groups.id (CASCADE) |
| userId | TEXT | PRIMARY KEY, FK → users.id (CASCADE) |
| balance | REAL | NOT NULL DEFAULT 0.0 |
| updatedAt | DATETIME | NOT NULL |

#### `expenses`
| Column | Type | Constraints |
|--------|------|-------------|
| id | TEXT | PRIMARY KEY |
| groupId | TEXT | NOT NULL, FK → groups.id (CASCADE) |
| title | TEXT | NOT NULL |
| amount | REAL | NOT NULL |
| currency | TEXT | NOT NULL |
| paidBy | TEXT | NOT NULL |
| shareWithEveryone | BOOLEAN | NOT NULL DEFAULT TRUE |
| expenseDate | DATETIME | NOT NULL |
| createdAt | DATETIME | NOT NULL |
| updatedAt | DATETIME | NOT NULL |
| deletedAt | DATETIME | NULLABLE |

#### `expense_shares`
| Column | Type | Constraints |
|--------|------|-------------|
| expenseId | TEXT | PRIMARY KEY, FK → expenses.id (CASCADE) |
| userId | TEXT | PRIMARY KEY, FK → users.id (CASCADE) |
| shareAmount | REAL | NOT NULL |

---

## Removed Fields & Properties

### From `User` entity:
- ❌ `groupIds: List<String>`

### From `GroupEntity`:
- ❌ `optimizeSharing: bool`
- ❌ `isOpen: bool`
- ❌ `autoExchangeCurrency: bool`

---

## Migration Impact

### Breaking Changes
1. **All local database data will be wiped** during migration from v4 to v5
2. User entity no longer has `groupIds` - must query via `group_members` table
3. Group entity simplified - removed unused optimization flags
4. `PersonalExpenseEntity` deleted - use `ExpenseEntity` with personal groups instead

### Updated Services
- ✅ `FirestoreGroupService` - Updated to use `isPersonal` flag
- ✅ `AppDatabase` - Updated all CRUD methods for new schema
- ✅ All conversion methods updated (`_userFromDb`, `_groupFromDb`, `_expenseFromDb`)

### Code Generation
- ✅ Ran `dart run build_runner build --delete-conflicting-outputs`
- ✅ All Freezed and Drift code regenerated successfully

---

## Advantages of New Schema

### ✅ Data Integrity
- Foreign key constraints prevent orphaned records
- Single source of truth for group membership
- Consistent nullable handling

### ✅ Simplified Architecture
- No more `PersonalExpenseEntity` duplication
- Unified group/expense model
- Personal groups integrated seamlessly

### ✅ Better Performance
- `group_balances` table enables fast balance lookups
- No need to recalculate from all expenses

### ✅ Soft Deletes
- Undo capability for deleted groups/expenses
- Audit trail support
- Query filtering: `WHERE deletedAt IS NULL`

### ✅ Maintainability
- Cleaner, more consistent codebase
- No denormalized data sync issues
- Clear separation of concerns

---

## Future Work (Not Yet Implemented)

1. **Balance Calculation Service**
   - Automatically update `group_balances` when expenses change
   - Can use Firestore Cloud Functions for remote calculation

2. **Firestore Integration**
   - Update Firestore security rules for new schema
   - Add `/groups/{groupId}/balances/{userId}` subcollection
   - Sync balances bidirectionally

3. **Query Updates**
   - Update all UI queries to filter `WHERE deletedAt IS NULL`
   - Implement "soft delete" vs "hard delete" logic in repositories

4. **Custom Expense Splits**
   - Decide whether to fully implement or remove `ExpenseShares`
   - Update balance calculation to account for custom splits

5. **Multi-Currency Support** (Deferred to v2)
   - Implement exchange rate API integration
   - Historical rate tracking

---

## Files Changed

### Entity Files
- ✅ `lib/features/auth/domain/entities/user.dart`
- ✅ `lib/features/groups/domain/entities/group_entity.dart`
- ✅ `lib/features/expenses/domain/entities/expense_entity.dart`
- ✅ `lib/features/groups/domain/entities/group_balance_entity.dart` (NEW)
- ❌ `lib/features/expenses/domain/entities/personal_expense_entity.dart` (DELETED)

### Table Files
- ✅ `lib/core/database/tables/users_table.dart`
- ✅ `lib/core/database/tables/groups_table.dart`
- ✅ `lib/core/database/tables/expenses_table.dart`

### Database Files
- ✅ `lib/core/database/app_database.dart`

### Service Files
- ✅ `lib/features/groups/data/services/firestore_group_service.dart`

---

## Testing Recommendations

1. **Unit Tests**
   - Test all database CRUD operations with new schema
   - Test foreign key cascade deletes
   - Test soft delete filtering

2. **Integration Tests**
   - Test group membership queries (no more `groupIds`)
   - Test personal group creation and isolation
   - Test balance calculations (when implemented)

3. **Manual Testing**
   - Create personal and shared groups
   - Add expenses to both types
   - Test sync with Firestore
   - Test data integrity after deletes

---

## Conclusion

This migration successfully implements the core recommendations from the data model review:
- ✅ Unified expense model (no more `PersonalExpenseEntity`)
- ✅ Single source of truth for memberships (removed `User.groupIds`)
- ✅ Soft delete support
- ✅ Foreign key constraints for data integrity
- ✅ Efficient balance tracking system
- ✅ Cleaner, more maintainable schema

**Status**: Schema migration complete and code generated successfully. Ready for testing.
