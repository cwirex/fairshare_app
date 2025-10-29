/// Available expense categories for categorizing expenses.
///
/// These are the 10 predefined categories that can be suggested by the AI model.
abstract class ExpenseCategories {
  static const String foodAndDrink = 'Food & Drink';
  static const String transport = 'Transport';
  static const String groceries = 'Groceries';
  static const String rentAndUtilities = 'Rent/Utilities';
  static const String shopping = 'Shopping';
  static const String entertainment = 'Entertainment';
  static const String health = 'Health';
  static const String travel = 'Travel';
  static const String gifts = 'Gifts';
  static const String other = 'Other';

  /// All available categories as a list.
  static const List<String> allCategories = [
    foodAndDrink,
    transport,
    groceries,
    rentAndUtilities,
    shopping,
    entertainment,
    health,
    travel,
    gifts,
    other,
  ];

  /// Get a descriptive emoji for a category.
  static String getEmoji(String category) {
    return switch (category) {
      foodAndDrink => '🍽️',
      transport => '🚗',
      groceries => '🛒',
      rentAndUtilities => '🏠',
      shopping => '🛍️',
      entertainment => '🎬',
      health => '🏥',
      travel => '✈️',
      gifts => '🎁',
      _ => '💰',
    };
  }

  /// Validate if a category is valid.
  static bool isValid(String category) {
    return allCategories.contains(category);
  }
}
