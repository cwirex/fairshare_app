# Alignment Issues Found - Final Audit

## Date: 2025-10-01

After thorough audit, several critical alignment issues were discovered that prevent the system from working correctly with the new schema.

---

## 🔴 CRITICAL ISSUES

### 1. **UI Group Creation Missing `isPersonal` Flag**
**File**: `lib/features/groups/presentation/providers/group_providers.dart:56`

**Problem**: When creating a group from UI, the `isPersonal` flag is never set, defaulting to `false`.

**Current Code**:
```dart
final group = GroupEntity(
  id: groupId,
  displayName: displayName,
  avatarUrl: avatarUrl ?? '',
  defaultCurrency: defaultCurrency,
  createdAt: now,
  updatedAt: now,
  // ❌ isPersonal is missing! Defaults to false
);
```

**Impact**: All groups created from UI will be marked as shared groups and will be synced to Firestore, even if they should be personal.

**Fix Needed**: Add `isPersonal: false` explicitly (or make it a parameter if needed).

---

### 2. **LocalGroupRepository Enqueues Personal Groups**
**File**: `lib/features/groups/data/repositories/local_group_repository.dart:17`

**Problem**: The repository enqueues ALL groups for sync, including personal groups.

**Current Code**:
```dart
Future<Result<GroupEntity>> createGroup(GroupEntity group) async {
  try {
    await _database.transaction(() async {
      await _database.insertGroup(group);
      // ❌ Always enqueues, even for personal groups!
      await _database.enqueueOperation(
        entityType: 'group',
        entityId: group.id,
        operationType: 'create',
      );
    });
    return Success(group);
  } catch (e) {
    return Failure(Exception('Failed to create group: $e'));
  }
}
```

**Impact**: Personal groups will be added to sync queue, wasting resources (though `uploadGroup` will skip them).

**Fix Needed**: Check `group.isPersonal` before enqueueing:
```dart
await _database.insertGroup(group);
// Only enqueue non-personal groups
if (!group.isPersonal) {
  await _database.enqueueOperation(
    entityType: 'group',
    entityId: group.id,
    operationType: 'create',
  );
}
```

---

### 3. **LocalGroupRepository Update/Delete Also Need Checks**
**Files**:
- `lib/features/groups/data/repositories/local_group_repository.dart:57`
- `lib/features/groups/data/repositories/local_group_repository.dart:73`

**Problem**: `updateGroup()` and `deleteGroup()` also enqueue all groups.

**Current Code**:
```dart
// UPDATE
Future<Result<GroupEntity>> updateGroup(GroupEntity group) async {
  try {
    await _database.transaction(() async {
      await _database.updateGroup(group);
      await _database.enqueueOperation(  // ❌ No check
        entityType: 'group',
        entityId: group.id,
        operationType: 'update',
      );
    });
    return Success(group);
  } catch (e) {
    return Failure(Exception('Failed to update group: $e'));
  }
}

// DELETE
Future<Result<void>> deleteGroup(String id) async {
  try {
    await _database.transaction(() async {
      await _database.enqueueOperation(  // ❌ No check
        entityType: 'group',
        entityId: id,
        operationType: 'delete',
      );
      await _database.deleteGroup(id);
    });
    return Success.unit();
  } catch (e) {
    return Failure(Exception('Failed to delete group: $e'));
  }
}
```

**Impact**: Unnecessary queue entries for personal groups.

**Fix Needed**: Check `isPersonal` before enqueueing in both methods.

---

## 🟡 MEDIUM PRIORITY ISSUES

### 4. **Expense Repository Might Have Same Issue**
**Files**:
- `lib/features/expenses/data/repositories/local_expense_repository.dart`

**Need to Check**: Does expense repository check if the expense's group is personal before enqueueing?

**Expected Behavior**: Expenses in personal groups should NOT be enqueued for sync.

---

### 5. **Soft Delete vs Hard Delete Confusion**
**File**: `lib/features/groups/data/repositories/local_group_repository.dart:78`

**Problem**: `deleteGroup()` does a hard delete, not a soft delete.

**Current Code**:
```dart
await _database.deleteGroup(id);  // Hard delete!
```

**We Have**: `softDeleteGroup()` and `restoreGroup()` methods in AppDatabase.

**Decision Needed**:
- Should repositories use soft delete by default?
- Should hard delete be a separate method?
- How should this work with sync?

---

## 🟢 INFORMATIONAL (Working as Designed)

### 6. **SyncedGroupRepository Doesn't Use Queue** ✅
**File**: `lib/features/groups/data/repositories/synced_group_repository.dart:37`

**Observation**: SyncedGroupRepository calls `uploadGroup()` directly without queue.

**Current Code**:
```dart
// Save to local database first (offline-first)
await _database.insertGroup(group);

// Try to sync to Firestore in the background
_firestoreService.uploadGroup(group);  // Direct upload, no queue
```

**Analysis**: This is actually correct! The upload service checks `isPersonal` and skips if needed.

**Status**: ✅ Working as intended

---

### 7. **User Serialization Correct** ✅
**File**: `lib/features/auth/domain/entities/user.g.dart`

**Verified**: User.toJson() and User.fromJson() do NOT include `groupIds`.

**Old Firestore Data**: Freezed will ignore unknown fields, so old user documents with `groupIds` won't break.

**Status**: ✅ No issues

---

## 📋 Required Fixes Summary

### Must Fix Immediately:
1. ✅ ~~Fix personal group initialization~~ (Already fixed in previous session)
2. ❌ **Fix UI group creation to explicitly set `isPersonal: false`**
3. ❌ **Fix LocalGroupRepository.createGroup() to check `isPersonal`**
4. ❌ **Fix LocalGroupRepository.updateGroup() to check `isPersonal`**
5. ❌ **Fix LocalGroupRepository.deleteGroup() to check `isPersonal`**
6. ❌ **Audit expense repository for same issue**

### Should Decide:
- Soft delete vs hard delete strategy
- Whether to use queue for synced repository

---

## 🔧 Recommended Fixes

### Fix 1: UI Group Creation
```dart
// lib/features/groups/presentation/providers/group_providers.dart
final group = GroupEntity(
  id: groupId,
  displayName: displayName,
  avatarUrl: avatarUrl ?? '',
  isPersonal: false,  // ✅ ADD THIS - explicitly mark as shared
  defaultCurrency: defaultCurrency,
  createdAt: now,
  updatedAt: now,
);
```

### Fix 2: LocalGroupRepository createGroup
```dart
Future<Result<GroupEntity>> createGroup(GroupEntity group) async {
  try {
    await _database.transaction(() async {
      await _database.insertGroup(group);

      // ✅ Only enqueue non-personal groups
      if (!group.isPersonal) {
        await _database.enqueueOperation(
          entityType: 'group',
          entityId: group.id,
          operationType: 'create',
        );
      }
    });
    return Success(group);
  } catch (e) {
    return Failure(Exception('Failed to create group: $e'));
  }
}
```

### Fix 3: LocalGroupRepository updateGroup
```dart
Future<Result<GroupEntity>> updateGroup(GroupEntity group) async {
  try {
    await _database.transaction(() async {
      await _database.updateGroup(group);

      // ✅ Only enqueue non-personal groups
      if (!group.isPersonal) {
        await _database.enqueueOperation(
          entityType: 'group',
          entityId: group.id,
          operationType: 'update',
        );
      }
    });
    return Success(group);
  } catch (e) {
    return Failure(Exception('Failed to update group: $e'));
  }
}
```

### Fix 4: LocalGroupRepository deleteGroup
```dart
Future<Result<void>> deleteGroup(String id) async {
  try {
    // ✅ Need to get group first to check if personal
    final group = await _database.getGroupById(id);

    await _database.transaction(() async {
      // Only enqueue non-personal groups
      if (group != null && !group.isPersonal) {
        await _database.enqueueOperation(
          entityType: 'group',
          entityId: id,
          operationType: 'delete',
        );
      }
      await _database.deleteGroup(id);
    });
    return Success.unit();
  } catch (e) {
    return Failure(Exception('Failed to delete group: $e'));
  }
}
```

---

## 🧪 Testing Plan

After fixes, test:
1. ✅ Create shared group from UI → verify `isPersonal = false`
2. ✅ Create shared group → verify it's in sync queue
3. ✅ Create personal group (initialization) → verify NOT in sync queue
4. ✅ Update shared group → verify in sync queue
5. ✅ Update personal group → verify NOT in sync queue
6. ✅ Delete shared group → verify delete in sync queue
7. ✅ Delete personal group → verify NOT in sync queue
8. ✅ Add expense to personal group → verify NOT synced

---

## 📊 Status Summary

| Component | Status | Issues |
|-----------|--------|--------|
| Database Schema | ✅ Complete | None |
| Database Queries | ✅ Complete | Soft delete filters added |
| User Serialization | ✅ Working | No issues |
| Firestore Services | ✅ Working | Uses `isPersonal` correctly |
| SyncedGroupRepository | ✅ Working | Direct upload checks `isPersonal` |
| LocalGroupRepository | ❌ BROKEN | Enqueues personal groups |
| UI Group Creation | ❌ BROKEN | Missing `isPersonal` flag |
| Personal Group Init | ✅ Fixed | Sets `isPersonal: true` |

---

## ⚠️ CONCLUSION

**The refactoring is NOT complete**. While the schema and database layer are correct, the repository and UI layers have critical bugs that will cause personal groups to be synced to Firestore.

**Action Required**: Apply the 4 fixes above before the system can work correctly.

**Estimated Time**: 30 minutes to fix + 30 minutes to test = 1 hour total.
