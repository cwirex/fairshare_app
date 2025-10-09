import 'package:drift/drift.dart';
import 'package:fairshare_app/core/database/tables/groups_table.dart';
import 'package:fairshare_app/core/database/tables/users_table.dart';

/// Table definition for group balances.
///
/// Stores calculated balance for each user in a group.
/// Positive balance means the group owes the user money.
/// Negative balance means the user owes the group money.
class AppGroupBalances extends Table {
  /// Group ID reference
  TextColumn get groupId =>
      text().references(AppGroups, #id, onDelete: KeyAction.cascade)();

  /// User ID reference
  TextColumn get userId =>
      text().references(AppUsers, #id, onDelete: KeyAction.cascade)();

  /// Calculated balance for this user in this group
  RealColumn get balance => real().withDefault(const Constant(0.0))();

  /// When the balance was last updated
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {groupId, userId};

  @override
  String get tableName => 'group_balances';
}
