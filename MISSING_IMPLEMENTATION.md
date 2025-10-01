# Missing Implementation Items

## Date: 2025-10-01

After screening the codebase, here are the items that need to be updated to fully match the new schema:

---

## 🔴 Critical Issues

### 1. **Group Initialization Missing `isPersonal` Flag**
**File**: `lib/features/groups/data/services/group_initialization_service.dart`

**Problem**: When creating a personal group, `isPersonal: true` is not set.

```dart
// CURRENT (line 24-30):
final group = GroupEntity(
  id: personalGroupId,
  displayName: 'Personal Expenses',
  defaultCurrency: 'USD',
  createdAt: now,
  updatedAt: now,
);

// SHOULD BE:
final group = GroupEntity(
  id: personalGroupId,
  displayName: 'Personal Expenses',
  isPersonal: true,  // ← MISSING
  defaultCurrency: 'USD',
  createdAt: now,
  updatedAt: now,
);
```

---

### 2. **Soft Delete Filtering Missing in Queries**
**File**: `lib/core/database/app_database.dart`

**Problem**: All queries need to filter `WHERE deletedAt IS NULL` to exclude soft-deleted items.

#### Groups Queries Need Filtering:
- `getGroupById()` - line 215
- `getAllGroups()` - line 220
- `getUserGroups()` - line 262
- `watchAllGroups()` - line 279
- `watchUserGroups()` - line 285

```dart
// CURRENT:
Future<GroupEntity?> getGroupById(String id) async {
  final query = select(appGroups)..where((g) => g.id.equals(id));
  final result = await query.getSingleOrNull();
  return result != null ? _groupFromDb(result) : null;
}

// SHOULD BE:
Future<GroupEntity?> getGroupById(String id) async {
  final query = select(appGroups)
    ..where((g) => g.id.equals(id) & g.deletedAt.isNull());
  final result = await query.getSingleOrNull();
  return result != null ? _groupFromDb(result) : null;
}
```

#### Expenses Queries Need Filtering:
- `getExpenseById()` - line 133
- `getExpensesByGroup()` - line 139
- `getAllExpenses()` - line 149
- `watchExpensesByGroup()` - line 179
- `watchAllExpenses()` - line 189

```dart
// Example:
Future<ExpenseEntity?> getExpenseById(String id) async {
  final query = select(expenses)
    ..where((e) => e.id.equals(id) & e.deletedAt.isNull());
  final result = await query.getSingleOrNull();
  return result != null ? _expenseFromDb(result) : null;
}
```

---

### 3. **`uploadGroupMember` Missing `isPersonalGroup` Parameter**
**File**: `lib/features/groups/data/repositories/synced_group_repository.dart`

**Problem**: Calls to `uploadGroupMember()` don't pass the `isPersonalGroup` parameter.

#### Location 1: `addMember()` - line 134
```dart
// CURRENT:
_firestoreService.uploadGroupMember(member);

// SHOULD CHECK:
final group = await _database.getGroupById(member.groupId);
_firestoreService.uploadGroupMember(
  member,
  isPersonalGroup: group?.isPersonal ?? false
);
```

#### Location 2: `joinGroupByCode()` - line 226
```dart
// CURRENT:
await _firestoreService.uploadGroupMember(newMember);

// SHOULD BE:
await _firestoreService.uploadGroupMember(
  newMember,
  isPersonalGroup: false  // Joined groups are never personal
);
```

---

## 🟡 Medium Priority Issues

### 4. **Soft Delete Implementation Missing**
**Status**: Schema supports it, but no implementation exists.

**Need to Add**:
1. Soft delete methods in `AppDatabase`:
   ```dart
   Future<void> softDeleteGroup(String id) async {
     await (update(appGroups)..where((g) => g.id.equals(id))).write(
       AppGroupsCompanion(
         deletedAt: Value(DateTime.now()),
         updatedAt: Value(DateTime.now()),
       ),
     );
   }

   Future<void> softDeleteExpense(String id) async {
     await (update(expenses)..where((e) => e.id.equals(id))).write(
       ExpensesCompanion(
         deletedAt: Value(DateTime.now()),
         updatedAt: Value(DateTime.now()),
       ),
     );
   }
   ```

2. Restore methods:
   ```dart
   Future<void> restoreGroup(String id) async {
     await (update(appGroups)..where((g) => g.id.equals(id))).write(
       AppGroupsCompanion(
         deletedAt: Value(null),
         updatedAt: Value(DateTime.now()),
       ),
     );
   }

   Future<void> restoreExpense(String id) async {
     await (update(expenses)..where((e) => e.id.equals(id))).write(
       ExpensesCompanion(
         deletedAt: Value(null),
         updatedAt: Value(DateTime.now()),
       ),
     );
   }
   ```

3. Update repository interfaces to use soft delete instead of hard delete

---

### 5. **Balance Calculation Service Not Implemented**
**Status**: Table exists, but no calculation logic.

**Need to Create**:
1. `lib/features/groups/data/services/balance_calculation_service.dart`
2. Methods to:
   - Calculate balances when expenses are added/updated/deleted
   - Update `group_balances` table
   - Sync balances to Firestore

**Logic**:
```dart
Future<void> recalculateGroupBalances(String groupId) async {
  // 1. Get all active expenses for the group
  // 2. Calculate net balance for each member
  // 3. Update group_balances table
  // 4. Sync to Firestore if not personal group
}
```

---

### 6. **Firestore Schema Mismatch**
**Problem**: Remote Firestore still expects old schema with `optimizeSharing`, `isOpen`, `autoExchangeCurrency`.

**Need to Update**:
1. Firestore security rules
2. Any Cloud Functions
3. Remove old fields from existing documents (migration)

---

## 🟢 Low Priority Issues

### 7. **Group Queries Could Use Optimization**
**File**: `lib/core/database/app_database.dart`

**Observation**: `getUserGroups()` uses a join, but could benefit from index hints.

```dart
// Consider adding:
@override
List<String> get customConstraints => [
  'CREATE INDEX IF NOT EXISTS idx_group_members_user ON group_members(userId)',
  'CREATE INDEX IF NOT EXISTS idx_groups_deleted ON groups(deletedAt)',
  'CREATE INDEX IF NOT EXISTS idx_expenses_deleted ON expenses(deletedAt)',
];
```

---

### 8. **Missing Validation**
**Need to Add**:
1. Validate `amount > 0` in expense creation (currently only DB constraint)
2. Validate currency codes against allowed list
3. Validate group display name length

---

## 📋 Action Items Summary

### Must Fix (Critical):
- [ ] Fix `group_initialization_service.dart` - add `isPersonal: true`
- [ ] Add `deletedAt.isNull()` filter to all group queries
- [ ] Add `deletedAt.isNull()` filter to all expense queries
- [ ] Fix `uploadGroupMember` calls with `isPersonalGroup` parameter

### Should Fix (Medium):
- [ ] Implement soft delete methods (`softDeleteGroup`, `softDeleteExpense`)
- [ ] Implement restore methods (`restoreGroup`, `restoreExpense`)
- [ ] Create balance calculation service
- [ ] Update Firestore schema/rules

### Nice to Have (Low):
- [ ] Add database indexes for performance
- [ ] Add validation logic to repositories
- [ ] Create unit tests for new schema

---

## Testing Checklist

After implementing fixes:
- [ ] Create a personal group - verify `isPersonal = true`
- [ ] Create a shared group - verify `isPersonal = false`
- [ ] Soft delete a group - verify it doesn't appear in queries
- [ ] Restore a group - verify it reappears
- [ ] Join a group - verify no sync errors
- [ ] Add expense to personal group - verify no sync attempt
- [ ] Check Firestore - verify personal groups not synced
- [ ] Check foreign key cascades work correctly

---

## Estimated Effort

- **Critical fixes**: ~2-3 hours
- **Medium priority**: ~4-6 hours
- **Low priority**: ~2-3 hours
- **Total**: ~8-12 hours

---

**Next Steps**:
1. Fix critical issues first
2. Test thoroughly
3. Implement medium priority items
4. Consider low priority as technical debt for later
