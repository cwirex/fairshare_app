import 'package:drift/drift.dart';
import 'package:fairshare_app/core/database/tables/users_table.dart';

/// Table definition for groups in the FairShare app.
///
/// Stores group information for expense sharing with timestamp-based sync.
class AppGroups extends Table {
  /// Unique group ID (6-digit code or personal_{userId})
  TextColumn get id => text()();

  /// Group display name
  TextColumn get displayName => text()();

  /// Group avatar URL (empty string if not available)
  TextColumn get avatarUrl => text().withDefault(const Constant(''))();

  /// Whether this is a personal (local-only) group
  BoolColumn get isPersonal => boolean().withDefault(const Constant(false))();

  /// Default currency for the group
  TextColumn get defaultCurrency => text().withDefault(const Constant('USD'))();

  /// When the group was created
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  /// Last time group data was updated
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  /// When the group was soft-deleted (null if active)
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  String get tableName => 'groups';
}

/// Table definition for group memberships.
///
/// Many-to-many relationship between users and groups.
class AppGroupMembers extends Table {
  /// Group ID reference
  TextColumn get groupId => text().references(AppGroups, #id, onDelete: KeyAction.cascade)();

  /// User ID reference
  TextColumn get userId => text().references(AppUsers, #id, onDelete: KeyAction.cascade)();

  /// When the user joined the group
  DateTimeColumn get joinedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {groupId, userId};

  @override
  String get tableName => 'group_members';
}

/// Table definition for group balances.
///
/// Stores calculated balance for each user in a group.
/// Positive balance means the group owes the user money.
/// Negative balance means the user owes the group money.
class AppGroupBalances extends Table {
  /// Group ID reference
  TextColumn get groupId => text().references(AppGroups, #id, onDelete: KeyAction.cascade)();

  /// User ID reference
  TextColumn get userId => text().references(AppUsers, #id, onDelete: KeyAction.cascade)();

  /// Calculated balance for this user in this group
  RealColumn get balance => real().withDefault(const Constant(0.0))();

  /// When the balance was last updated
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {groupId, userId};

  @override
  String get tableName => 'group_balances';
}
