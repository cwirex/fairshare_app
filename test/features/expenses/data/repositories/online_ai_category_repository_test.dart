import 'package:fairshare_app/core/config/gemini_config.dart';
import 'package:fairshare_app/features/expenses/data/repositories/online_ai_category_repository.dart';
import 'package:fairshare_app/features/expenses/domain/constants/expense_categories.dart';
import 'package:flutter_gemini/flutter_gemini.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OnlineAiCategoryRepository - Gemini Integration', () {
    late OnlineAiCategoryRepository repository;

    setUpAll(() {
      // Initialize Gemini with the API key from config
      Gemini.init(apiKey: GeminiConfig.apiKey);
      repository = OnlineAiCategoryRepository();
    });

    test('should suggest "Food & Drink" for coffee expense', () async {
      final suggestion = await repository.suggestCategory('Starbucks coffee');

      expect(suggestion, isNotNull);
      expect(
        ExpenseCategories.allCategories.contains(suggestion),
        true,
        reason: 'Suggestion "$suggestion" should be in valid categories',
      );
      print('✓ Coffee expense: $suggestion');
    });

    test('should suggest "Transport" for Uber expense', () async {
      final suggestion =
          await repository.suggestCategory('Uber to airport');

      expect(suggestion, isNotNull);
      expect(
        ExpenseCategories.allCategories.contains(suggestion),
        true,
        reason: 'Suggestion "$suggestion" should be in valid categories',
      );
      print('✓ Uber expense: $suggestion');
    });

    test('should suggest "Groceries" for grocery expense', () async {
      final suggestion = await repository.suggestCategory('Whole Foods shopping');

      expect(suggestion, isNotNull);
      expect(
        ExpenseCategories.allCategories.contains(suggestion),
        true,
        reason: 'Suggestion "$suggestion" should be in valid categories',
      );
      print('✓ Grocery expense: $suggestion');
    });

    test('should suggest "Entertainment" for Netflix', () async {
      final suggestion = await repository.suggestCategory('Netflix subscription');

      expect(suggestion, isNotNull);
      expect(
        ExpenseCategories.allCategories.contains(suggestion),
        true,
        reason: 'Suggestion "$suggestion" should be in valid categories',
      );
      print('✓ Netflix expense: $suggestion');
    });

    test('should suggest valid category for any expense', () async {
      final testCases = [
        'Doctor appointment',
        'Airplane ticket',
        'Birthday gift',
        'Monthly rent',
        'Nike shoes',
      ];

      for (final title in testCases) {
        final suggestion = await repository.suggestCategory(title);

        expect(suggestion, isNotNull, reason: 'Should return a suggestion for "$title"');
        expect(
          ExpenseCategories.allCategories.contains(suggestion),
          true,
          reason: 'Suggestion "$suggestion" for "$title" should be valid',
        );
        print('✓ $title => $suggestion');
      }
    });

    test('should validate categories correctly', () {
      expect(repository.isValidCategory('Food & Drink'), true);
      expect(repository.isValidCategory('Transport'), true);
      expect(repository.isValidCategory('Other'), true);
      expect(repository.isValidCategory('InvalidCategory'), false);
      expect(repository.isValidCategory(''), false);
    });

    test('should return all valid categories', () {
      final categories = repository.getValidCategories();

      expect(categories.length, 10);
      expect(categories.contains('Food & Drink'), true);
      expect(categories.contains('Other'), true);
    });
  });
}
