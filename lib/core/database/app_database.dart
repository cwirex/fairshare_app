import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';

import '../../features/auth/domain/entities/user.dart';
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
