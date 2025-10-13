enum EntityType {
  user,
  group,
  groupMember,
  groupBalance,
  expense,
  expenseShare,
}

extension EntityTypeExtension on EntityType {
  String get name {
    switch (this) {
      case EntityType.user:
        return 'user';
      case EntityType.group:
        return 'group';
      case EntityType.groupMember:
        return 'group_member';
      case EntityType.groupBalance:
        return 'group_balance';
      case EntityType.expense:
        return 'expense';
      case EntityType.expenseShare:
        return 'expense_share';
    }
  }
}
