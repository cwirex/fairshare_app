import 'package:drift/drift.dart';

/// Table definition for sync queue in the FairShare app.
///
/// Stores operations performed offline that need to be synced to Firebase.
class SyncQueue extends Table {
  /// Auto-incrementing ID for sync operations
  IntColumn get id => integer().autoIncrement()();

  /// Type of operation: 'create', 'update', 'delete'
  TextColumn get operation => text()();

  /// Type of entity: 'user', 'group', 'expense', etc.
  TextColumn get entityType => text()();

  /// ID of the entity being synced
  TextColumn get entityId => text()();

  /// JSON data for the operation (nullable for delete operations)
  TextColumn get data => text().nullable()();

  /// When the operation was queued
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  /// Number of retry attempts
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
}
