/// Abstract interface for AI-powered category suggestion.
///
/// This interface follows the dependency inversion principle:
/// - The domain layer defines what category suggestion should do
/// - The data layer implements it (online or offline)
/// - The UI layer doesn't care whether it's online or offline
///
/// This allows seamless migration from online API to offline TFLite model
/// without changing any calling code.
abstract interface class ICategorySuggestionRepository {
  /// Suggests a category based on the expense title.
  ///
  /// Input: A string describing the expense (e.g., "Uber to airport")
  /// Output: A category name from [ExpenseCategories] or null if no
  ///         confident suggestion can be made.
  ///
  /// Implementation details:
  /// - Phase 1: Calls an online AI service (e.g., OpenAI, Gemini)
  /// - Phase 2: Uses an on-device TFLite model (100% offline)
  ///
  /// Both implementations must return the same category names and respect
  /// the offline-first principle where possible.
  Future<String?> suggestCategory(String expenseTitle);

  /// Get a list of valid categories that the model can suggest.
  ///
  /// This is useful for UI validation and filtering.
  /// Returns the categories from [ExpenseCategories.allCategories].
  List<String> getValidCategories();

  /// Check if a category is valid.
  ///
  /// Returns true if the category is in the list of valid categories.
  bool isValidCategory(String category);
}
