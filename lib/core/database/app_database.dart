import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:fairshare_app/core/database/DAOs/expense_shares_dao.dart';
import 'package:fairshare_app/core/database/DAOs/expenses_dao.dart';
import 'package:fairshare_app/core/database/DAOs/groups_dao.dart';
import 'package:fairshare_app/core/database/DAOs/sync_dao.dart';
import 'package:fairshare_app/core/database/DAOs/user_dao.dart';
import 'package:fairshare_app/core/database/tables/balances_table.dart';
import 'package:fairshare_app/core/database/tables/members_table.dart';
import 'package:fairshare_app/core/database/tables/shares_table.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';

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
    AppGroupBalances,
    Expenses,
    ExpenseShares,
    SyncQueue,
  ],
  daos: [UserDao, GroupsDao, ExpensesDao, ExpenseSharesDao, SyncDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 6; // Increment when changing tables

  @override
  MigrationStrategy get migration => _migrationStrategy();

  /// Clear all data from all tables (used during sign-out)
  Future<void> clearAllData() async {
    await transaction(() async {
      await delete(syncQueue).go();
      await delete(expenseShares).go();
      await delete(expenses).go();
      await delete(appGroupBalances).go();
      await delete(appGroupMembers).go();
      await delete(appGroups).go();
      await delete(appUsers).go();
    });
  }

  MigrationStrategy _migrationStrategy() {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 5) {
          // Major schema refactoring - drop and recreate all tables
          // This is acceptable since the user was told all data will be wiped
          await m.deleteTable('expense_shares');
          await m.deleteTable('expenses');
          await m.deleteTable('group_members');
          await m.deleteTable('groups');
          await m.deleteTable('users');
          await m.deleteTable('sync_queue');

          await m.createAll();
        }
        if (from < 6) {
          // Add lastActivityAt column to groups table
          await m.addColumn(appGroups, appGroups.lastActivityAt);

          // Populate lastActivityAt with updatedAt for existing groups
          await customStatement(
            'UPDATE groups SET last_activity_at = updated_at WHERE last_activity_at IS NULL',
          );
        }
      },
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
