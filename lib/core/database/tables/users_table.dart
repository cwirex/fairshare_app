import 'package:drift/drift.dart';

/// Table definition for users in the FairShare app.
///
/// Stores user authentication and profile data with offline-first approach.
/// Uses timestamp-based sync tracking.
class AppUsers extends Table {
  /// Unique user ID from Firebase Auth
  TextColumn get id => text()();

  /// Display name from Google account
  TextColumn get displayName => text()();

  /// Email from Google account
  TextColumn get email => text()();

  /// Avatar URL from Google account (empty string if not available)
  TextColumn get avatarUrl => text().withDefault(const Constant(''))();

  /// Phone number (empty string if not provided)
  TextColumn get phone => text().withDefault(const Constant(''))();

  /// List of group IDs the user is a member of (stored as comma-separated string)
  TextColumn get groupIds => text().withDefault(const Constant(''))();

  /// Last time user synced data with Firestore
  DateTimeColumn get lastSyncTimestamp => dateTime().nullable()();

  /// When the user first signed up
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  /// Last time user data was updated
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};

  @override
  String get tableName => 'users';
}
