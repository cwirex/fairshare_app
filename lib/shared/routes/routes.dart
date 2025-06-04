/// Static route definitions for FairShare app.
///
/// Centralizes all route paths for better maintainability and type safety.
/// Prevents typos and makes navigation more discoverable.
abstract class Routes {
  // === AUTHENTICATION ===
  static const String auth = '/auth';

  // === HOME & MAIN NAVIGATION ===
  static const String home = '/home';

  // === PROFILE ===
  static const String profile = '/profile';
  static const String editProfile = '/profile/edit';
  static const String settings = '/settings';

  // === GROUPS ===
  static const String groups = '/groups';
  static const String createGroup = '/groups/create';
  static const String joinGroup = '/groups/join';
  static const String groupDetail = '/groups/:groupId';
  static const String groupSettings = '/groups/:groupId/settings';

  // === EXPENSES ===
  static const String expenses = '/expenses';
  static const String createExpense = '/expenses/create';
  static const String expenseDetail = '/expenses/:expenseId';
  static const String editExpense = '/expenses/:expenseId/edit';

  // === BALANCES ===
  static const String balances = '/balances';
  static const String balanceDetail = '/balances/:groupId';

  // === UTILITY METHODS ===

  /// Generate group detail route with actual groupId
  static String groupDetailPath(String groupId) => '/groups/$groupId';

  /// Generate group settings route with actual groupId
  static String groupSettingsPath(String groupId) =>
      '/groups/$groupId/settings';

  /// Generate expense detail route with actual expenseId
  static String expenseDetailPath(String expenseId) => '/expenses/$expenseId';

  /// Generate edit expense route with actual expenseId
  static String editExpensePath(String expenseId) =>
      '/expenses/$expenseId/edit';

  /// Generate balance detail route with actual groupId
  static String balanceDetailPath(String groupId) => '/balances/$groupId';

  /// Check if route requires authentication
  static bool requiresAuth(String route) {
    return route != auth;
  }

  /// Get route name for analytics/logging
  static String getRouteName(String route) {
    // Remove parameters and return clean name
    if (route.contains('/groups/') && route.contains('/settings')) {
      return 'GroupSettings';
    }
    if (route.contains('/groups/') && !route.contains('/')) {
      return 'GroupDetail';
    }
    if (route.contains('/expenses/') && route.contains('/edit')) {
      return 'EditExpense';
    }
    if (route.contains('/expenses/') && !route.contains('/')) {
      return 'ExpenseDetail';
    }
    if (route.contains('/balances/')) return 'BalanceDetail';

    switch (route) {
      case auth:
        return 'Auth';
      case home:
        return 'Home';
      case profile:
        return 'Profile';
      case editProfile:
        return 'EditProfile';
      case settings:
        return 'Settings';
      case groups:
        return 'Groups';
      case createGroup:
        return 'CreateGroup';
      case joinGroup:
        return 'JoinGroup';
      case expenses:
        return 'Expenses';
      case createExpense:
        return 'CreateExpense';
      case balances:
        return 'Balances';
      default:
        return 'Unknown';
    }
  }
}
