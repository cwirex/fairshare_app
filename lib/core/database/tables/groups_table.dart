import 'package:drift/drift.dart';

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

  /// Last time there was activity in this group (expense added, member joined, etc.)
  /// Used for smart refresh detection in hybrid listener strategy
  DateTimeColumn get lastActivityAt =>
      dateTime().withDefault(currentDateAndTime)();

  /// When the group was soft-deleted (null if active)
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  String get tableName => 'groups';
}
