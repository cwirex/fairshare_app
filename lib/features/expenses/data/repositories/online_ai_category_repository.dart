import 'package:fairshare_app/core/config/gemini_config.dart';
import 'package:fairshare_app/core/logging/app_logger.dart';
import 'package:fairshare_app/features/expenses/domain/constants/expense_categories.dart';
import 'package:fairshare_app/features/expenses/domain/repositories/category_suggestion_repository.dart';
import 'package:flutter_gemini/flutter_gemini.dart';

/// Online AI-powered category suggestion repository using Google Gemini.
///
/// **Phase 1: Validation Phase**
///
/// This implementation uses Google's Gemini API to analyze expense titles
/// and suggest appropriate categories from the predefined list.
///
/// **Important Architecture Notes:**
/// - This is ONLY for initial validation of the feature
/// - It introduces network latency and privacy concerns
/// - In Phase 2, this will be replaced by an offline TFLite model
/// - The interface `ICategorySuggestionRepository` ensures that calling code
///   doesn't need to change when we migrate to offline
///
/// **Configuration:**
/// The Gemini API key must be configured in [GeminiConfig] before use.
/// It should be loaded from environment variables or secure storage,
/// never hardcoded in source code.
///
/// **Error Handling:**
/// - If the network request fails, returns null (no suggestion)
/// - If the response is invalid, returns null
/// - If the returned category is invalid, validates and returns null
/// - Network errors are logged but don't crash the app
class OnlineAiCategoryRepository
    with LoggerMixin
    implements ICategorySuggestionRepository {
  /// Creates an instance.
  /// The Gemini API key is automatically loaded from [GeminiConfig].
  OnlineAiCategoryRepository();

  @override
  Future<String?> suggestCategory(String expenseTitle) async {
    try {
      log.d('Requesting Gemini category suggestion for: "$expenseTitle"');

      // Check if Gemini is properly configured
      if (!GeminiConfig.isAvailable) {
        log.w('Gemini not available: API key not configured');
        return null;
      }

      // Create the prompt for Gemini
      final prompt = _buildPrompt(expenseTitle);

      // Call Gemini API
      final response = await Gemini.instance
          .prompt(parts: [Part.text(prompt)])
          .timeout(
            const Duration(seconds: GeminiConfig.timeoutSeconds),
            onTimeout: () {
              log.w('Gemini API request timed out');
              return null;
            },
          );

      if (response == null) {
        log.w('Gemini returned null response');
        return null;
      }

      // Extract the category from the response
      final suggestion = _parseResponse(response.output);

      if (suggestion != null) {
        log.i('Gemini suggested category: $suggestion for "$expenseTitle"');
      } else {
        log.d('Gemini did not return a valid category');
      }

      return suggestion;
    } catch (e) {
      log.e('Failed to get Gemini category suggestion: $e');
      return null; // Gracefully handle errors
    }
  }

  /// Builds the prompt to send to Gemini
  String _buildPrompt(String expenseTitle) {
    final categoriesList = ExpenseCategories.allCategories.join(', ');

    return '''You are a helpful assistant that categorizes expenses.

Given an expense description, respond with ONLY the best matching category from this list:
$categoriesList

Rules:
1. Respond with ONLY the category name, nothing else
2. Choose from the exact list above
3. If unsure, respond with "Other"
4. Do not include explanations or additional text

Expense: "$expenseTitle"

Category:''';
  }

  /// Parses the Gemini response and extracts the category
  String? _parseResponse(String? output) {
    if (output == null || output.trim().isEmpty) {
      return null;
    }

    // Get the first line and trim whitespace
    final suggestion = output.split('\n').first.trim();

    // Validate that it's a known category
    if (isValidCategory(suggestion)) {
      return suggestion;
    }

    log.w('Invalid category returned: "$suggestion"');
    return null;
  }

  @override
  List<String> getValidCategories() => ExpenseCategories.allCategories;

  @override
  bool isValidCategory(String category) =>
      ExpenseCategories.isValid(category);
}
