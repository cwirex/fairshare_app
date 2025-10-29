import 'package:fairshare_app/core/domain/use_case.dart';
import 'package:fairshare_app/features/expenses/domain/repositories/category_suggestion_repository.dart';

/// Wrapper class for optional category suggestion.
/// Required because UseCase<Input, Output> requires Output extends Object,
/// and String? is not a subclass of Object.
class CategorySuggestionResult {
  final String? category;

  CategorySuggestionResult(this.category);
}

/// Use case for suggesting an expense category based on its title.
///
/// This use case:
/// 1. Validates that the title is not empty
/// 2. Calls the repository to get a category suggestion
/// 3. Validates that the suggestion (if any) is a valid category
/// 4. Returns the result wrapped in [Result<CategorySuggestionResult, Exception>]
///
/// The implementation is agnostic to whether the repository uses
/// an online API or an offline model. This is the power of dependency inversion!
class SuggestCategoryUseCase extends UseCase<String, CategorySuggestionResult> {
  final ICategorySuggestionRepository _repository;

  SuggestCategoryUseCase(this._repository);

  @override
  void validate(String input) {
    if (input.trim().isEmpty) {
      throw Exception('Expense title cannot be empty');
    }

    if (input.trim().length > 500) {
      throw Exception('Expense title cannot exceed 500 characters');
    }
  }

  @override
  Future<CategorySuggestionResult> execute(String input) async {
    // Call the repository to get a category suggestion
    final suggestion = await _repository.suggestCategory(input.trim());

    // Validate the suggestion if one was returned
    if (suggestion != null) {
      if (!_repository.isValidCategory(suggestion)) {
        log.w(
          'Repository returned invalid category: $suggestion. '
          'Ignoring suggestion.',
        );
        return CategorySuggestionResult(null);
      }
    }

    log.d('Category suggestion for "$input": $suggestion');
    return CategorySuggestionResult(suggestion);
  }
}
