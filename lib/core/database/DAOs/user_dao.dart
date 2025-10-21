import 'package:drift/drift.dart';
import 'package:fairshare_app/core/database/app_database.dart';
import 'package:fairshare_app/core/database/tables/users_table.dart';
import 'package:fairshare_app/features/auth/domain/entities/user.dart';

part 'user_dao.g.dart';

@DriftAccessor(tables: [AppUsers])
class UserDao extends DatabaseAccessor<AppDatabase> with _$UserDaoMixin {
  final AppDatabase db;

  UserDao(this.db) : super(db);

  /// Insert or update a user in the database (UPSERT)
  Future<void> insertUser(User user) async {
    await into(appUsers).insert(
      AppUsersCompanion(
        id: Value(user.id),
        displayName: Value(user.displayName),
        email: Value(user.email),
        avatarUrl: Value(user.avatarUrl),
        phone: Value(user.phone),
        lastSyncTimestamp: Value(user.lastSyncTimestamp),
        createdAt: Value(user.createdAt),
        updatedAt: Value(user.updatedAt),
      ),
      mode: InsertMode.insertOrReplace,
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

  /// Convert database user row to domain user entity
  User _userFromDb(AppUser dbUser) {
    return User(
      id: dbUser.id,
      displayName: dbUser.displayName,
      email: dbUser.email,
      avatarUrl: dbUser.avatarUrl,
      phone: dbUser.phone,
      lastSyncTimestamp: dbUser.lastSyncTimestamp,
      createdAt: dbUser.createdAt,
      updatedAt: dbUser.updatedAt,
    );
  }
}
