import 'package:drift/drift.dart';

/// Table definition for users in the FairShare app.
///
/// Stores user authentication and profile data with offline-first approach.
/// Uses non-nullable fields with default values for cleaner code.
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

  /// When the user first signed up
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  /// Last time user data was updated
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  /// Whether user data is synced with Firebase
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};

  @override
  String get tableName => 'users'; // Keep database table name as 'users'
}
