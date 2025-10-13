/// Entity type constants for sync operations.
/// Used in sync queue to identify the type of entity being synced.
abstract class EntityType {
  /// Translates to 'user'
  static const String user = 'user';

  /// Translates to 'group'
  static const String group = 'group';

  /// Translates to 'group_member'
  static const String groupMember = 'group_member';

  /// Translates to 'group_balance'
  static const String groupBalance = 'group_balance';

  /// Translates to 'expense'
  static const String expense = 'expense';

  /// Translates to 'expense_share'
  static const String expenseShare = 'expense_share';
}
