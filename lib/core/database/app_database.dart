import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';

import 'package:fairshare_app/features/auth/domain/entities/user.dart';
import 'package:fairshare_app/features/expenses/domain/entities/expense_entity.dart';
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
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
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
        createdAt: Value(user.createdAt),
        updatedAt: Value(user.updatedAt),
        isSynced: Value(user.isSynced),
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
        createdAt: Value(user.createdAt),
        updatedAt: Value(DateTime.now()),
        isSynced: Value(user.isSynced),
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
        isSynced: Value(expense.isSynced),
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
        isSynced: Value(expense.isSynced),
      ),
    );
  }

  /// Delete expense by ID
  Future<void> deleteExpense(String id) async {
    await (delete(expenses)..where((e) => e.id.equals(id))).go();
  }

  /// Get all unsynced expenses
  Future<List<ExpenseEntity>> getUnsyncedExpenses() async {
    final query = select(expenses)
      ..where((e) => e.isSynced.equals(false));
    final results = await query.get();
    return results.map(_expenseFromDb).toList();
  }

  /// Mark expense as synced
  Future<void> markExpenseAsSynced(String id) async {
    await (update(expenses)..where((e) => e.id.equals(id)))
        .write(const ExpensesCompanion(isSynced: Value(true)));
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
        isSynced: Value(group.isSynced),
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
        isSynced: Value(group.isSynced),
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
        isSynced: Value(member.isSynced),
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

  // === SYNC OPERATIONS ===

  /// Get count of all unsynced items across all tables
  Future<int> getUnsyncedItemsCount() async {
    final userCount =
        await (selectOnly(appUsers)
              ..addColumns([appUsers.id.count()])
              ..where(appUsers.isSynced.equals(false)))
            .getSingle();

    final groupCount =
        await (selectOnly(appGroups)
              ..addColumns([appGroups.id.count()])
              ..where(appGroups.isSynced.equals(false)))
            .getSingle();

    final expenseCount =
        await (selectOnly(expenses)
              ..addColumns([expenses.id.count()])
              ..where(expenses.isSynced.equals(false)))
            .getSingle();

    final userCountInt = (userCount.read(appUsers.id.count()) ?? 0).toInt();
    final groupCountInt = (groupCount.read(appGroups.id.count()) ?? 0).toInt();
    final expenseCountInt =
        (expenseCount.read(expenses.id.count()) ?? 0).toInt();

    return userCountInt + groupCountInt + expenseCountInt;
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
      createdAt: dbUser.createdAt,
      updatedAt: dbUser.updatedAt,
      isSynced: dbUser.isSynced,
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
      isSynced: dbExpense.isSynced,
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
      isSynced: dbGroup.isSynced,
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
