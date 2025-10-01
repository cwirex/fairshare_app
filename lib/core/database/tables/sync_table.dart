import 'package:drift/drift.dart';

/// Table definition for upload queue in the FairShare app.
///
/// Implements Option D: Separate Upload Queue Table strategy.
/// Stores operations performed offline that need to be synced to Firebase.
/// Uses a UNIQUE constraint to ensure only one pending operation per entity.
class SyncQueue extends Table {
  /// Auto-incrementing ID for sync operations
  IntColumn get id => integer().autoIncrement()();

  /// Type of entity: 'expense', 'group', 'user', etc.
  TextColumn get entityType => text()();

  /// ID of the entity being synced
  TextColumn get entityId => text()();

  /// Type of operation: 'create', 'update', 'delete'
  TextColumn get operationType => text()();

  /// Additional context data as JSON (e.g., groupId for expense deletes)
  TextColumn get metadata => text().nullable()();

  /// When the operation was queued
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  /// Number of retry attempts (for failure recovery)
  IntColumn get retryCount => integer().withDefault(const Constant(0))();

  /// Last error message (nullable, for debugging)
  TextColumn get lastError => text().nullable()();

  @override
  List<Set<Column>> get uniqueKeys => [
        {entityType, entityId}
      ];
}
