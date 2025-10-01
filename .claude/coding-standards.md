# FairShare Coding Standards

This document defines the coding standards for the FairShare project. These rules should be followed by all contributors, including AI assistants.

## Core Principles

### 1. Single Responsibility Principle (SRP)
- **One class per file** - Never combine multiple classes in a single file
- **Files should be 300-500 lines maximum** - Exceeding this indicates SRP violations
- **Separate concerns**: presentation, business logic, data access
- If a file is too large, split it into focused components

### 2. No Useless Comments
- **Comments should explain WHY, not WHAT**
- Well-named variables and methods are self-documenting
- Avoid redundant comments like:
  - ❌ `/// User ID` above `String userId`
  - ❌ `// Theme toggle button` above obvious UI code
  - ❌ `/// Formats date` above `formatDate()` method
- **Only use comments for**:
  - High-level architectural decisions
  - Complex business logic that isn't obvious
  - Non-obvious workarounds or hacks
  - Important warnings or gotchas

### 3. Pure Data Models with Freezed
- **Data models should contain ONLY data** - No methods, no business logic
- Use Freezed for immutable data classes
- **Do NOT add extensions to freezed classes** inside the same file
- **Do NOT use private constructors** like `const ExpenseEntity._()` unless needed for custom methods
- Example of proper Freezed usage:
  ```dart
  @freezed
  class Restaurant with _$Restaurant {
    const factory Restaurant({
      required String id,
      required String name,
      required double rating,
      @Default([]) List<String> cuisine,
    }) = _Restaurant;

    factory Restaurant.fromJson(Map<String, dynamic> json) =>
        _$RestaurantFromJson(json);
  }
  ```
- For formatting/computed properties, create separate helper classes

### 4. Package Imports Over Relative Imports
- **Always use package imports**: `package:fairshare_app/...`
- **Never use relative imports**: `../../../core/...`
- Improves refactoring and maintainability
- Makes dependencies explicit

### 5. Clean Code Structure

#### File Organization
```
lib/
├── core/              # Shared infrastructure
│   ├── database/      # One file per table/operation
│   └── logging/
├── features/          # Feature modules
│   └── expenses/
│       ├── domain/
│       │   ├── entities/     # One entity per file
│       │   ├── repositories/ # Interfaces only
│       │   └── helpers/      # Static utility classes
│       ├── data/
│       │   └── repositories/ # Implementations
│       └── presentation/
│           ├── screens/      # One screen per file
│           ├── widgets/      # One widget per file
│           └── providers/    # Riverpod providers
```

#### Naming Conventions
- Files: `snake_case.dart`
- Classes: `PascalCase`
- Variables/functions: `camelCase`
- Constants: `camelCase` or `SCREAMING_SNAKE_CASE` for compile-time constants
- Private members: `_leadingUnderscore`

### 6. Proper Use of Helper Classes
- For formatting, calculations, or utility functions: **Create static helper classes**
- Example:
  ```dart
  /// Formats expense data for display.
  class ExpenseFormatter {
    const ExpenseFormatter._();

    static String formatAmount(ExpenseEntity expense) {
      return '${expense.currency} ${expense.amount.toStringAsFixed(2)}';
    }

    static String formatDate(ExpenseEntity expense) {
      return expense.expenseDate.toString().split(' ')[0];
    }
  }
  ```

### 7. Type Safety
- Use Drift for type-safe database queries
- Null-safe Dart throughout
- Prefer explicit types over `var` when clarity matters
- Use `final` by default, `const` where possible

### 8. Error Handling
- Use `Result<T, E>` types from `result_dart` package
- Comprehensive error handling in repositories
- User-friendly error messages in UI
- Log errors appropriately

### 9. Code Generation
- Use build_runner for:
  - Freezed (data classes)
  - Riverpod (providers)
  - Drift (database)
  - JSON serialization
- Never modify generated files
- Run `dart run build_runner build --delete-conflicting-outputs` after changes

## Anti-Patterns to Avoid

### ❌ Multiple Classes in One File
```dart
// BAD: Multiple classes in expense.dart
class ExpenseEntity { ... }
class ExpenseShareEntity { ... }  // Should be separate file!
```

### ❌ Extensions on Freezed Classes
```dart
// BAD: Don't mix extensions with entity
@freezed
class ExpenseEntity { ... }

extension ExpenseEntityX on ExpenseEntity {  // Move to helper!
  String get formattedAmount => ...;
}
```

### ❌ Obvious Comments
```dart
// BAD: Comment just repeats the code
// Theme toggle button
IconButton(
  icon: Icon(Icons.dark_mode),
  tooltip: 'Toggle theme',  // Tooltip is enough!
)
```

### ❌ Relative Imports
```dart
// BAD
import '../../../core/database/app_database.dart';

// GOOD
import 'package:fairshare_app/core/database/app_database.dart';
```

### ❌ God Classes / Large Files
```dart
// BAD: 524-line home_screen.dart with all tabs
class HomeScreen { ... }
class ExpensesTab { ... }  // Extract to separate file
class BalancesTab { ... }   // Extract to separate file
class GroupsTab { ... }     // Extract to separate file
```

## Quality Checklist

Before submitting code, verify:
- [ ] Each file contains only ONE class/component
- [ ] No file exceeds 300-500 lines
- [ ] No useless comments (explain WHY, not WHAT)
- [ ] All imports are package imports
- [ ] Freezed classes are pure data models
- [ ] Helper classes used for formatting/utilities
- [ ] Code generated and no errors: `flutter analyze`
- [ ] Meaningful names make code self-documenting

## References

- [Effective Dart Style Guide](https://dart.dev/guides/language/effective-dart/style)
- [Flutter Best Practices](https://docs.flutter.dev/testing/best-practices)
- [Riverpod Documentation](https://riverpod.dev/)
- [Freezed Documentation](https://pub.dev/packages/freezed)

---

**Last Updated**: 2025-09-30
**Version**: 1.0.0

These standards are enforced to maintain code quality, readability, and maintainability across the project.
### 10. Riverpod Provider Management
- **Repository and service providers MUST use `@Riverpod(keepAlive: true)`**
- Auto-dispose providers (default `@riverpod`) get disposed when not watched
- This causes database connections to close and services to be recreated
- **Use `keepAlive: true` for**:
  - Database providers
  - Repository providers
  - Service providers (AuthRepository, etc.)
  - Any stateful service that should persist
- **Use auto-dispose (default) for**:
  - UI state providers
  - Temporary stream providers
  - Notifier providers for user actions

Example:
```dart
// CORRECT - Repository kept alive
@Riverpod(keepAlive: true)
ExpenseRepository expenseRepository(ExpenseRepositoryRef ref) {
  final database = ref.watch(appDatabaseProvider);
  return LocalExpenseRepository(database);
}

// WRONG - Will be disposed and cause errors
@riverpod
ExpenseRepository expenseRepository(ExpenseRepositoryRef ref) {
  return LocalExpenseRepository(ref.watch(appDatabaseProvider));
}
```
