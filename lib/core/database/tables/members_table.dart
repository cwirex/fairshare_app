import 'package:drift/drift.dart';
import 'package:fairshare_app/core/database/tables/groups_table.dart';
import 'package:fairshare_app/core/database/tables/users_table.dart';

/// Table definition for group memberships.
///
/// Many-to-many relationship between users and groups.
class AppGroupMembers extends Table {
  /// Group ID reference
  TextColumn get groupId =>
      text().references(AppGroups, #id, onDelete: KeyAction.cascade)();

  /// User ID reference
  TextColumn get userId =>
      text().references(AppUsers, #id, onDelete: KeyAction.cascade)();

  /// When the user joined the group
  DateTimeColumn get joinedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {groupId, userId};

  @override
  String get tableName => 'group_members';
}
