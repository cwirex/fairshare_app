import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';

import 'package:fairshare_app/features/auth/domain/entities/user.dart';
import 'package:fairshare_app/features/expenses/domain/entities/expense_entity.dart';
import 'package:fairshare_app/features/expenses/domain/entities/expense_share_entity.dart';
import 'package:fairshare_app/features/groups/domain/entities/group_entity.dart';
import 'package:fairshare_app/features/groups/domain/entities/group_member_entity.dart';
import 'tables/expenses_table.dart';
import 'tables/groups_table.dart';
import 'tables/sync_table.dart';
import 'tables/users_table.dart';

part 'app_database.g.dart';

/// FairShare app database using Drift for offline-first data storage.
///
/// Coordinates all table operations and provides high-level database methods.
/// Focuses on database setup, migrations, and cross-table operations.
@DriftDatabase(
  tables: [
    AppUsers,
    AppGroups,
    AppGroupMembers,
    Expenses,
    ExpenseShares,
    SyncQueue,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 3; // Updated: Implemented Option D upload queue

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 3) {
          // Migrate from old sync queue to new upload queue structure
          await m.deleteTable('sync_queue');
          await m.createTable(syncQueue);
        }
      },
    );
  }

  // === USER OPERATIONS ===

  /// Insert a new user into the database
  Future<void> insertUser(User user) async {
    await into(appUsers).insert(
      AppUsersCompanion(
        id: Value(user.id),
        displayName: Value(user.displayName),
        email: Value(user.email),
        avatarUrl: Value(user.avatarUrl),
        phone: Value(user.phone),
        groupIds: Value(user.groupIds.join(',')),
        lastSyncTimestamp: Value(user.lastSyncTimestamp),
        createdAt: Value(user.createdAt),
        updatedAt: Value(user.updatedAt),
      ),
    );
  }

  /// Get user by ID
  Future<User?> getUserById(String id) async {
    final query = select(appUsers)..where((u) => u.id.equals(id));
    final result = await query.getSingleOrNull();
    return result != null ? _userFromDb(result) : null;
  }

  /// Update existing user
  Future<void> updateUser(User user) async {
    await update(appUsers).replace(
      AppUsersCompanion(
        id: Value(user.id),
        displayName: Value(user.displayName),
        email: Value(user.email),
        avatarUrl: Value(user.avatarUrl),
        phone: Value(user.phone),
        groupIds: Value(user.groupIds.join(',')),
        lastSyncTimestamp: Value(user.lastSyncTimestamp),
        createdAt: Value(user.createdAt),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Delete user by ID
  Future<void> deleteUser(String id) async {
    await (delete(appUsers)..where((u) => u.id.equals(id))).go();
  }

  // === EXPENSE OPERATIONS ===

  /// Insert a new expense into the database
  Future<void> insertExpense(ExpenseEntity expense) async {
    await into(expenses).insert(
      ExpensesCompanion(
        id: Value(expense.id),
        groupId: Value(expense.groupId),
        title: Value(expense.title),
        amount: Value(expense.amount),
        currency: Value(expense.currency),
        paidBy: Value(expense.paidBy),
        shareWithEveryone: Value(expense.shareWithEveryone),
        expenseDate: Value(expense.expenseDate),
        createdAt: Value(expense.createdAt),
        updatedAt: Value(expense.updatedAt),
        
      ),
    );
  }

  /// Get expense by ID
  Future<ExpenseEntity?> getExpenseById(String id) async {
    final query = select(expenses)..where((e) => e.id.equals(id));
    final result = await query.getSingleOrNull();
    return result != null ? _expenseFromDb(result) : null;
  }

  /// Get all expenses for a specific group
  Future<List<ExpenseEntity>> getExpensesByGroup(String groupId) async {
    final query = select(expenses)
      ..where((e) => e.groupId.equals(groupId))
      ..orderBy([(e) => OrderingTerm.desc(e.expenseDate)]);
    final results = await query.get();
    return results.map(_expenseFromDb).toList();
  }

  /// Get all expenses across all groups
  Future<List<ExpenseEntity>> getAllExpenses() async {
    final query = select(expenses)
      ..orderBy([(e) => OrderingTerm.desc(e.expenseDate)]);
    final results = await query.get();
    return results.map(_expenseFromDb).toList();
  }

  /// Update existing expense
  Future<void> updateExpense(ExpenseEntity expense) async {
    await update(expenses).replace(
      ExpensesCompanion(
        id: Value(expense.id),
        groupId: Value(expense.groupId),
        title: Value(expense.title),
        amount: Value(expense.amount),
        currency: Value(expense.currency),
        paidBy: Value(expense.paidBy),
        shareWithEveryone: Value(expense.shareWithEveryone),
        expenseDate: Value(expense.expenseDate),
        createdAt: Value(expense.createdAt),
        updatedAt: Value(DateTime.now()),
        
      ),
    );
  }

  /// Delete expense by ID
  Future<void> deleteExpense(String id) async {
    await (delete(expenses)..where((e) => e.id.equals(id))).go();
  }

  /// Watch expenses for a specific group (stream)
  Stream<List<ExpenseEntity>> watchExpensesByGroup(String groupId) {
    final query = select(expenses)
      ..where((e) => e.groupId.equals(groupId))
      ..orderBy([(e) => OrderingTerm.desc(e.expenseDate)]);
    return query.watch().map((rows) => rows.map(_expenseFromDb).toList());
  }

  /// Watch all expenses (stream)
  Stream<List<ExpenseEntity>> watchAllExpenses() {
    final query = select(expenses)
      ..orderBy([(e) => OrderingTerm.desc(e.expenseDate)]);
    return query.watch().map((rows) => rows.map(_expenseFromDb).toList());
  }

  // === GROUP OPERATIONS ===

  Future<void> insertGroup(GroupEntity group) async {
    await into(appGroups).insert(
      AppGroupsCompanion(
        id: Value(group.id),
        displayName: Value(group.displayName),
        avatarUrl: Value(group.avatarUrl),
        optimizeSharing: Value(group.optimizeSharing),
        isOpen: Value(group.isOpen),
        autoExchangeCurrency: Value(group.autoExchangeCurrency),
        defaultCurrency: Value(group.defaultCurrency),
        createdAt: Value(group.createdAt),
        updatedAt: Value(group.updatedAt),
      ),
    );
  }

  Future<GroupEntity?> getGroupById(String id) async {
    final query = select(appGroups)..where((g) => g.id.equals(id));
    final result = await query.getSingleOrNull();
    return result != null ? _groupFromDb(result) : null;
  }

  Future<List<GroupEntity>> getAllGroups() async {
    final query = select(appGroups)
      ..orderBy([(g) => OrderingTerm.desc(g.createdAt)]);
    final results = await query.get();
    return results.map(_groupFromDb).toList();
  }

  Future<void> updateGroup(GroupEntity group) async {
    await update(appGroups).replace(
      AppGroupsCompanion(
        id: Value(group.id),
        displayName: Value(group.displayName),
        avatarUrl: Value(group.avatarUrl),
        optimizeSharing: Value(group.optimizeSharing),
        isOpen: Value(group.isOpen),
        autoExchangeCurrency: Value(group.autoExchangeCurrency),
        defaultCurrency: Value(group.defaultCurrency),
        createdAt: Value(group.createdAt),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> deleteGroup(String id) async {
    await (delete(appGroups)..where((g) => g.id.equals(id))).go();
  }

  Future<void> addGroupMember(GroupMemberEntity member) async {
    await into(appGroupMembers).insert(
      AppGroupMembersCompanion(
        groupId: Value(member.groupId),
        userId: Value(member.userId),
        joinedAt: Value(member.joinedAt),
      ),
    );
  }

  Future<void> removeGroupMember(String groupId, String userId) async {
    await (delete(appGroupMembers)
          ..where((m) => m.groupId.equals(groupId) & m.userId.equals(userId)))
        .go();
  }

  Future<List<String>> getGroupMembers(String groupId) async {
    final query = select(appGroupMembers)
      ..where((m) => m.groupId.equals(groupId));
    final results = await query.get();
    return results.map((m) => m.userId).toList();
  }

  Future<List<GroupEntity>> getUserGroups(String userId) async {
    final query = select(appGroups).join([
      innerJoin(
        appGroupMembers,
        appGroupMembers.groupId.equalsExp(appGroups.id),
      ),
    ])
      ..where(appGroupMembers.userId.equals(userId))
      ..orderBy([OrderingTerm.desc(appGroups.createdAt)]);

    final results = await query.get();
    return results.map((row) => _groupFromDb(row.readTable(appGroups))).toList();
  }

  Stream<List<GroupEntity>> watchAllGroups() {
    final query = select(appGroups)
      ..orderBy([(g) => OrderingTerm.desc(g.createdAt)]);
    return query.watch().map((rows) => rows.map(_groupFromDb).toList());
  }

  Stream<List<GroupEntity>> watchUserGroups(String userId) {
    final query = select(appGroups).join([
      innerJoin(
        appGroupMembers,
        appGroupMembers.groupId.equalsExp(appGroups.id),
      ),
    ])
      ..where(appGroupMembers.userId.equals(userId))
      ..orderBy([OrderingTerm.desc(appGroups.createdAt)]);

    return query.watch().map((rows) =>
        rows.map((row) => _groupFromDb(row.readTable(appGroups))).toList());
  }

  /// Get all group members as entities
  Future<List<GroupMemberEntity>> getAllGroupMembers(String groupId) async {
    final query = select(appGroupMembers)
      ..where((m) => m.groupId.equals(groupId));
    final results = await query.get();
    return results.map(_groupMemberFromDb).toList();
  }

  // === EXPENSE SHARE OPERATIONS ===

  /// Insert a new expense share
  Future<void> insertExpenseShare(ExpenseShareEntity share) async {
    await into(expenseShares).insert(
      ExpenseSharesCompanion(
        expenseId: Value(share.expenseId),
        userId: Value(share.userId),
        shareAmount: Value(share.shareAmount),
      ),
    );
  }

  /// Get all shares for an expense
  Future<List<ExpenseShareEntity>> getExpenseShares(String expenseId) async {
    final query = select(expenseShares)
      ..where((s) => s.expenseId.equals(expenseId));
    final results = await query.get();
    return results.map(_expenseShareFromDb).toList();
  }

  /// Delete all shares for an expense
  Future<void> deleteExpenseShares(String expenseId) async {
    await (delete(expenseShares)..where((s) => s.expenseId.equals(expenseId)))
        .go();
  }

  // === SYNC QUEUE OPERATIONS ===

  /// Enqueue an operation to the upload queue
  /// Uses INSERT OR REPLACE to ensure only one operation per entity
  Future<void> enqueueOperation({
    required String entityType,
    required String entityId,
    required String operationType,
    String? metadata,
  }) async {
    await into(syncQueue).insertOnConflictUpdate(
      SyncQueueCompanion(
        entityType: Value(entityType),
        entityId: Value(entityId),
        operationType: Value(operationType),
        metadata: Value(metadata),
        createdAt: Value(DateTime.now()),
        retryCount: Value(0),
        lastError: const Value(null),
      ),
    );
  }

  // === SYNC-SAFE INSERT/UPDATE OPERATIONS ===
  // These methods are used by the sync service to apply remote changes
  // without triggering new upload queue operations.
  // They bypass repositories and write directly to the database.

  /// Insert or update a group from remote sync (bypasses queue)
  Future<void> upsertGroupFromSync(GroupEntity group) async {
    final existing = await getGroupById(group.id);

    if (existing == null) {
      // New group from server - insert directly
      await into(appGroups).insert(
        AppGroupsCompanion(
          id: Value(group.id),
          displayName: Value(group.displayName),
          avatarUrl: Value(group.avatarUrl),
          optimizeSharing: Value(group.optimizeSharing),
          isOpen: Value(group.isOpen),
          autoExchangeCurrency: Value(group.autoExchangeCurrency),
          defaultCurrency: Value(group.defaultCurrency),
          createdAt: Value(group.createdAt),
          updatedAt: Value(group.updatedAt),
        ),
      );
    } else {
      // Only update if remote version is newer (Last Write Wins)
      if (group.updatedAt.isAfter(existing.updatedAt)) {
        await (update(appGroups)..where((g) => g.id.equals(group.id))).write(
          AppGroupsCompanion(
            displayName: Value(group.displayName),
            avatarUrl: Value(group.avatarUrl),
            optimizeSharing: Value(group.optimizeSharing),
            isOpen: Value(group.isOpen),
            autoExchangeCurrency: Value(group.autoExchangeCurrency),
            defaultCurrency: Value(group.defaultCurrency),
            updatedAt: Value(group.updatedAt),
          ),
        );
      }
    }
  }

  /// Insert or update an expense from remote sync (bypasses queue)
  Future<void> upsertExpenseFromSync(ExpenseEntity expense) async {
    final existing = await getExpenseById(expense.id);

    if (existing == null) {
      // New expense from server - insert directly
      await into(expenses).insert(
        ExpensesCompanion(
          id: Value(expense.id),
          groupId: Value(expense.groupId),
          title: Value(expense.title),
          amount: Value(expense.amount),
          currency: Value(expense.currency),
          paidBy: Value(expense.paidBy),
          shareWithEveryone: Value(expense.shareWithEveryone),
          expenseDate: Value(expense.expenseDate),
          createdAt: Value(expense.createdAt),
          updatedAt: Value(expense.updatedAt),
        ),
      );
    } else {
      // Only update if remote version is newer (Last Write Wins)
      if (expense.updatedAt.isAfter(existing.updatedAt)) {
        await (update(expenses)..where((e) => e.id.equals(expense.id))).write(
          ExpensesCompanion(
            title: Value(expense.title),
            amount: Value(expense.amount),
            currency: Value(expense.currency),
            paidBy: Value(expense.paidBy),
            shareWithEveryone: Value(expense.shareWithEveryone),
            expenseDate: Value(expense.expenseDate),
            updatedAt: Value(expense.updatedAt),
          ),
        );
      }
    }
  }

  /// Get all pending operations from the upload queue
  Future<List<SyncQueueData>> getPendingOperations({int? limit}) async {
    final query = select(syncQueue)..orderBy([(s) => OrderingTerm.asc(s.createdAt)]);
    if (limit != null) {
      query.limit(limit);
    }
    return query.get();
  }

  /// Remove an operation from the queue after successful upload
  Future<void> removeQueuedOperation(int id) async {
    await (delete(syncQueue)..where((s) => s.id.equals(id))).go();
  }

  /// Increment retry count and update error message for failed operation
  Future<void> markOperationFailed(int id, String errorMessage) async {
    final current = await (select(syncQueue)..where((s) => s.id.equals(id))).getSingle();
    await (update(syncQueue)..where((s) => s.id.equals(id))).write(
      SyncQueueCompanion(
        retryCount: Value(current.retryCount + 1),
        lastError: Value(errorMessage),
      ),
    );
  }

  /// Get count of pending operations
  Future<int> getPendingOperationCount() async {
    final query = selectOnly(syncQueue)..addColumns([syncQueue.id.count()]);
    final result = await query.getSingle();
    return result.read(syncQueue.id.count()) ?? 0;
  }

  /// Clear all data from all tables (used during sign-out)
  Future<void> clearAllData() async {
    await transaction(() async {
      await delete(syncQueue).go();
      await delete(expenseShares).go();
      await delete(expenses).go();
      await delete(appGroupMembers).go();
      await delete(appGroups).go();
      await delete(appUsers).go();
    });
  }

  // === PRIVATE HELPERS ===

  /// Convert database user row to domain user entity
  User _userFromDb(AppUser dbUser) {
    return User(
      id: dbUser.id,
      displayName: dbUser.displayName,
      email: dbUser.email,
      avatarUrl: dbUser.avatarUrl,
      phone: dbUser.phone,
      groupIds: dbUser.groupIds.isEmpty ? [] : dbUser.groupIds.split(','),
      lastSyncTimestamp: dbUser.lastSyncTimestamp,
      createdAt: dbUser.createdAt,
      updatedAt: dbUser.updatedAt,
    );
  }

  /// Convert database expense row to domain expense entity
  ExpenseEntity _expenseFromDb(Expense dbExpense) {
    return ExpenseEntity(
      id: dbExpense.id,
      groupId: dbExpense.groupId,
      title: dbExpense.title,
      amount: dbExpense.amount,
      currency: dbExpense.currency,
      paidBy: dbExpense.paidBy,
      shareWithEveryone: dbExpense.shareWithEveryone,
      expenseDate: dbExpense.expenseDate,
      createdAt: dbExpense.createdAt,
      updatedAt: dbExpense.updatedAt,
    );
  }

  GroupEntity _groupFromDb(AppGroup dbGroup) {
    return GroupEntity(
      id: dbGroup.id,
      displayName: dbGroup.displayName,
      avatarUrl: dbGroup.avatarUrl,
      optimizeSharing: dbGroup.optimizeSharing,
      isOpen: dbGroup.isOpen,
      autoExchangeCurrency: dbGroup.autoExchangeCurrency,
      defaultCurrency: dbGroup.defaultCurrency,
      createdAt: dbGroup.createdAt,
      updatedAt: dbGroup.updatedAt,
    );
  }

  GroupMemberEntity _groupMemberFromDb(AppGroupMember dbMember) {
    return GroupMemberEntity(
      groupId: dbMember.groupId,
      userId: dbMember.userId,
      joinedAt: dbMember.joinedAt,
    );
  }

  ExpenseShareEntity _expenseShareFromDb(ExpenseShare dbShare) {
    return ExpenseShareEntity(
      expenseId: dbShare.expenseId,
      userId: dbShare.userId,
      shareAmount: dbShare.shareAmount,
    );
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(join(dbFolder.path, 'fairshare.db'));

    if (Platform.isAndroid) {
      await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
    }

    return NativeDatabase.createInBackground(file);
  });
}
