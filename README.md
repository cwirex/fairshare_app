# FairShare

A group expense sharing app built to explore offline-first architecture, real-time sync, and Clean Architecture patterns in Flutter.

## What This Project Demonstrates

This is a working expense tracker with a focus on **engineering over features**. The app handles the common problem of splitting costs among friends (trips, shared apartments, group dinners), but the real value of this repository is in how it's built:

- **Offline-first architecture** with SQLite + Firestore sync
- **Complete dependency inversion** across all critical layers (data access, business logic, sync services, event system)
- **Event-driven reactive UI** via domain events
- **200+ tests** covering repositories, use cases, sync logic, and balance calculations
- **Clean Architecture** with strict layer separation

While the UI is still being built out, the core engine—sync, database, business logic, balance calculations—is production-ready and tested.

## Project Evolution

**Phase 1 (June 2025):** Basic MVP with Firebase sync
- Google authentication, basic expense/group CRUD
- Direct Firestore writes (no offline support)

**Phase 2 (Oct 2025):** Offline-first rewrite
- Migrated to Drift (SQLite) as source of truth
- Implemented upload queue for offline changes
- Added Use Case layer for business logic
- Built real-time sync with hybrid listener strategy

**Phase 2.5 (Oct 2025):** Architectural refactoring
- Identified dependency inversion violations (DAOs, use cases, sync services, event broker)
- Refactored to interface-based design across all layers
- Added comprehensive test coverage for core business logic
- Removed singleton anti-patterns

**Phase 3 (Current):** UI integration
- Building out balance display, group stats, dashboard
- Integrating event-driven providers with UI
- Performance optimization

See [docs/current/PLAN.md](docs/current/PLAN.md) for the full development roadmap.

## Technical Stack

- **Flutter** - Cross-platform mobile framework
- **Riverpod** - State management with code generation
- **Drift** - Type-safe SQLite database for offline storage
- **Firebase** - Authentication (Auth) and cloud sync (Firestore)
- **Go Router** - Declarative routing with deep linking support
- **Material 3** - Modern design with light/dark themes

## Current Features

**Core Functionality (Complete & Tested):**
- Google Sign-In authentication
- Expense CRUD (create, read, update, delete)
- Group management with 6-digit invite codes
- Personal groups for individual expense tracking
- Balance calculations (net balances, optimal settlements)
- Real-time sync with Firestore (hybrid listener strategy)
- Offline-first with automatic sync queue

**Architecture (Complete):**
- Interface abstractions across data access, business logic, sync services, and events
- Event-driven reactive providers (balance calculations, group stats, dashboard)
- 200+ tests covering critical business logic
- Clean Architecture with strict layer separation
- Atomic transactions (DB + Queue + Events)

**UI (In Progress):**
- Basic expense list and group list views
- ⏳ Balance display with settlement suggestions
- ⏳ Group statistics dashboard
- ⏳ Recent activity feed

## Future Ideas

**Near-term (Phase 3+):**
- Advanced split options (unequal splits, percentages, itemized bills)
- Receipt photo attachments
- Expense categories and filtering
- Multi-currency support with live conversion rates
- Export data (CSV, PDF reports)

**Long-term (Exploration):**
- **Bluetooth/Local Network Sync** - P2P sync when devices are nearby, no internet required
- **Auto-payment Integration** - Connect to payment gateways (Stripe, PayPal) for one-tap settlements
- **Smart Expense Recognition** - OCR for receipt scanning, auto-populate expense details
- **Recurring Expenses** - Subscriptions, monthly rent, scheduled bills
- **Debt Graph Visualization** - Interactive network graph showing all balances in a group
- **Smart Notifications** - Remind users when balances exceed thresholds or settlements are due

## Architecture Overview

The app follows Clean Architecture with three distinct layers:

**Presentation Layer (UI)**
- Flutter widgets and Riverpod providers
- Depends only on use case interfaces (`ICreateExpenseUseCase`, etc.)
- Event-driven: Listens to `IEventBroker` for reactive updates

**Domain Layer (Business Logic)**
- 11 use cases with validation (implements use case interfaces)
- Entities (ExpenseEntity, GroupEntity)
- Repository interfaces define contracts

**Data Layer (Persistence & Sync)**
- Repositories implement domain interfaces, coordinate DB + sync queue
- 5 DAO interfaces abstract SQLite operations (Drift)
- 3 sync service interfaces manage Firestore communication
- EventBroker fires domain events on all state changes

All dependencies point inward—the domain layer has zero outward dependencies. This enables:
- Complete unit testing with mocked dependencies
- Swapping implementations without touching business logic
- Clean separation of concerns

For a detailed breakdown of the dependency inversion refactor, see [docs/current/ARCHITECTURE_ANALYSIS.md](docs/current/ARCHITECTURE_ANALYSIS.md).

```
lib/
├── core/              # Shared infrastructure
│   ├── database/      # Drift database, DAOs, DAO interfaces
│   ├── events/        # EventBroker interface + implementation
│   ├── sync/          # Sync service interfaces + implementations
│   └── logging/       # Logging (LoggerMixin + AppLogger)
├── features/          # Feature modules (Clean Architecture)
│   ├── auth/          # Authentication
│   ├── expenses/      # Expense management
│   │   ├── domain/    # Use case interfaces, entities, repository interfaces
│   │   ├── data/      # Repository + Firestore service implementations
│   │   └── presentation/  # Providers, UI widgets
│   ├── groups/        # Group management (same structure)
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

### Key Patterns

- **Clean Architecture** - Strict layer separation (presentation → domain → data)
- **Dependency Inversion** - All cross-layer dependencies use interfaces
- **Repository Pattern** - Data sources abstracted behind interfaces
- **Use Case Pattern** - Single-responsibility business operations
- **Event-Driven Architecture** - Domain events for reactive UI updates
- **Result Types** - Explicit error handling (`Result<T>` from use cases)
- **Immutable Entities** - Freezed data classes throughout

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

## Test Coverage

The core business logic and data layer are tested in isolation:

```
✓ 200+ tests passing
├─ Use Cases: 11 test suites (business logic validation)
├─ Repositories: 137 tests (transactions, events, queue coordination)
├─ Sync Services: 12 tests (upload queue, real-time listeners)
├─ Balance Services: 14 tests (net balances, optimal settlements)
├─ Balance Providers: 10 tests (event-driven reactive updates)
├─ Event System: 8 tests (domain event broadcasting)
└─ Integration: 2 flows (end-to-end expense + group flows)
```

**Test Strategy:**
- Repository tests use mocked DAOs (no database required)
- Use case tests use mocked repositories
- Sync tests use mocked Firestore services
- Focus on critical business logic paths

**Coverage:** ~32% overall, but core business logic (repositories, use cases, sync) has higher coverage. UI layer testing is planned for Phase 3.

## Documentation

- **[PLAN.md](docs/current/PLAN.md)** - Full development roadmap and phase breakdown
- **[ARCHITECTURE_ANALYSIS.md](docs/current/ARCHITECTURE_ANALYSIS.md)** - Technical deep-dive into the dependency inversion refactor
- **[DATA_SCHEMA_COMPLETE.md](docs/current/DATA_SCHEMA_COMPLETE.md)** - Complete SQLite and Firestore schema documentation
- **[CURRENT_ARCHITECTURE.md](docs/current/CURRENT_ARCHITECTURE.md)** - High-level architecture overview

## License

TBD

---

**Built with ❤️ for fair sharing**