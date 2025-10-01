# FairShare

An offline-first group expense sharing app for splitting costs and settling up with friends.

## Vision

FairShare makes group expense management effortless by combining the best of modern mobile development with thoughtful offline-first design. Track expenses anywhere, sync when connected, and always know who owes what.

## Core Principles

### 1. Offline-First Architecture
- **Local database as source of truth** - All data stored in SQLite via Drift
- **Work without internet** - Create expenses, groups, and calculate balances offline
- **Automatic sync** - Changes sync to Firebase when connection is available
- **Conflict resolution** - Smart merging of changes from multiple devices

### 2. Simple & Intuitive UX
- **Minimal friction** - Add expenses in 3 taps
- **Clear visibility** - Always know who owes what at a glance
- **Smart defaults** - Equal splits, sensible categories, today's date
- **Progressive complexity** - Advanced features don't clutter basic flows

### 3. Fair & Transparent
- **Clear calculations** - Obvious math, no hidden formulas
- **Minimal settlements** - Optimize transactions to reduce number of payments
- **Audit trail** - Complete history of all expenses and changes
- **No lock-in** - Export your data anytime

### 4. Privacy & Data Ownership
- **Your data, your control** - Firebase only stores what you create
- **No ads, no tracking** - Built for users, not advertisers
- **Secure authentication** - Google Sign-In via Firebase Auth
- **Data portability** - Export to standard formats

## Technical Stack

- **Flutter** - Cross-platform mobile framework
- **Riverpod** - State management with code generation
- **Drift** - Type-safe SQLite database for offline storage
- **Firebase** - Authentication (Auth) and cloud sync (Firestore)
- **Go Router** - Declarative routing with deep linking support
- **Material 3** - Modern design with light/dark themes

## Key Features

### Current (Phase 2.2 - Basic Expense & Group Tracking)
- ✅ Google Sign-In authentication
- ✅ Offline-first local database (SQLite via Drift)
- ✅ Sign-out risk assessment (warns about unsynced data)
- ✅ Modern Material 3 UI with theme switching
- ✅ **Create and save expenses**
- ✅ **View expense list**
- ✅ **Auto-created "Personal" group**
- ✅ **Group list display**
- ✅ Proper provider lifecycle management

### Next (Phase 2.3 - Balance Calculations)
- 🚧 Calculate balances per group
- 🚧 Display who owes whom
- 🚧 Show settlement amounts
- 🚧 Firebase sync for expenses and groups

### Future (Full Feature Set)
- 📋 Advanced split options (percentage, exact amounts, unequal)
- 📋 Group invitations and member management
- 📋 Expense categories and tags
- 📋 Receipt photos
- 📋 Multi-currency support with conversion
- 📋 Settlement suggestions and payment tracking
- 📋 Data export and reports
- 📋 Notifications for new expenses

## Architecture

```
lib/
├── core/              # Shared infrastructure
│   ├── database/      # Drift database, tables, providers
│   └── logging/       # Logging (LoggerMixin + AppLogger)
├── features/          # Feature modules
│   ├── auth/          # Authentication (domain, data, presentation)
│   ├── expenses/      # Expense management
│   ├── groups/        # Group management
│   ├── balances/      # Balance calculations
│   └── profile/       # User profile
└── shared/            # Shared UI components
    ├── routes/        # Navigation and routing
    └── theme/         # App theming
```

### Logging

FairShare uses a simple mixin-based logging approach:

```dart
// Add LoggerMixin to any class that needs logging
class MyClass with LoggerMixin {
  void doSomething() {
    log.i('Info message');        // Info logs
    log.w('Warning message');     // Warning logs
    log.e('Error message', error); // Error logs with optional error/stack
    log.d('Debug message');       // Debug logs (only in debug mode)
  }
}
```

**Key features:**
- No dependency injection required - just mix in `LoggerMixin`
- Automatic class name tracking via `runtimeType`
- Debug logs (`log.d`) automatically disabled in release builds via `kDebugMode`
- Simple implementation using Flutter's `debugPrint` for better IDE integration
- Timestamps and log levels included automatically

### Design Patterns
- **Clean Architecture** - Separation of domain, data, and presentation layers
- **Repository Pattern** - Abstract data sources behind interfaces
- **Provider Pattern** - Riverpod for dependency injection and state
- **Immutable Models** - Freezed for data classes
- **Result Types** - Explicit error handling with result_dart

## Development Philosophy

### Iterative Development
- Start simple, add complexity as needed
- Working software over comprehensive planning
- Test the full stack early and often
- Refactor when patterns emerge, not before

### Quality Standards
- **Single Responsibility Principle (SRP)** - Each file should have one clear purpose
  - Files exceeding 300-500 lines may indicate SRP violations
  - Consider splitting into smaller, focused components
  - Separate concerns: presentation, business logic, data access
- Type-safe database queries
- Null-safe Dart throughout
- Comprehensive error handling
- **Logging via LoggerMixin** - Simple, environment-aware logging throughout the app
  - Use `log.i()` for info, `log.w()` for warnings, `log.e()` for errors
  - `log.d()` for debug (automatically disabled in production/release mode)
  - Mix in `LoggerMixin` to any class that needs logging
- Code generation for boilerplate reduction
- Package imports over relative imports for better maintainability

### User-Centric
- Real-world testing drives feature priority
- Performance matters (fast app startup, smooth animations)
- Accessibility from the start
- Clear error messages and loading states

## Getting Started

### Prerequisites
- Flutter SDK >= 3.29.0
- Dart SDK >= 3.7.0
- Firebase project configured

### Setup
```bash
# Install dependencies
flutter pub get

# Generate code (freezed, riverpod, drift)
dart run build_runner build --delete-conflicting-outputs

# Run the app
flutter run
```

### Firebase Configuration
1. Create a Firebase project
2. Add iOS and Android apps
3. Download and place `google-services.json` (Android) and `GoogleService-Info.plist` (iOS)
4. Enable Google Sign-In in Firebase Console

## Project Status

Currently in **Phase 2.2 Complete** - Basic expense tracking and group management working end-to-end! Users can create expenses, view them in a list, and they're automatically organized in a "Personal" group. Everything persists offline.

**Next**: Phase 2.3 - Balance calculations (who owes whom).

See [PLAN.md](PLAN.md) for detailed development roadmap.

## License

TBD

---

**Built with ❤️ for fair sharing**