import 'package:drift/drift.dart';

/// Table definition for groups in the FairShare app.
///
/// Stores group information for expense sharing.
class AppGroups extends Table {
  /// Unique group ID (6-digit code)
  TextColumn get id => text()();

  /// Group display name
  TextColumn get displayName => text()();

  /// Group avatar URL (empty string if not available)
  TextColumn get avatarUrl => text().withDefault(const Constant(''))();

  /// Whether to optimize expense sharing (minimize transactions)
  BoolColumn get optimizeSharing =>
      boolean().withDefault(const Constant(true))();

  /// Whether group is open for new members to join
  BoolColumn get isOpen => boolean().withDefault(const Constant(true))();

  /// Whether to auto-convert currencies to default currency
  BoolColumn get autoExchangeCurrency =>
      boolean().withDefault(const Constant(false))();

  /// Default currency for the group
  TextColumn get defaultCurrency => text().withDefault(const Constant('USD'))();

  /// When the group was created
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  /// Last time group data was updated
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  /// Whether group data is synced with Firebase
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};

  @override
  String get tableName => 'groups'; // Keep database table name as 'groups'
}

/// Table definition for group memberships.
///
/// Many-to-many relationship between users and groups.
class AppGroupMembers extends Table {
  /// Group ID reference
  TextColumn get groupId => text()();

  /// User ID reference
  TextColumn get userId => text()();

  /// When the user joined the group
  DateTimeColumn get joinedAt => dateTime().withDefault(currentDateAndTime)();

  /// Whether membership data is synced with Firebase
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {groupId, userId};

  @override
  String get tableName => 'group_members'; // Keep database table name as 'group_members'
}
