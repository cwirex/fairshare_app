# FairShare Project Context

This file provides context about the FairShare project for AI assistants and new developers.

## Project Overview

**FairShare** is an offline-first group expense sharing mobile app built with Flutter. Users can split expenses with friends, track who owes what, and settle up efficiently.

## Current Status

**Phase**: MVP Phase 2 - Basic Expense Tracking
**Last Updated**: 2025-09-30

### Completed Features
- ✅ Firebase Authentication with Google Sign-In
- ✅ Offline-first local database (Drift/SQLite)
- ✅ Expense creation and listing
- ✅ User profile management
- ✅ Sign-out risk assessment (warns about unsynced data)
- ✅ Modern Material 3 UI with dark mode

### In Progress
- 🚧 Group management (UI ready, logic pending)
- 🚧 Balance calculations (UI ready, logic pending)
- 🚧 Firebase sync mechanism (structure ready, sync pending)

### Not Started
- ❌ Expense splitting logic (equal/custom splits)
- ❌ Multi-currency support
- ❌ Settlement optimization
- ❌ Group invitations

## Architecture

### Tech Stack
- **Flutter** 3.29.0+ with Dart 3.7.0+
- **State Management**: Riverpod 2.6.1 with code generation
- **Database**: Drift 2.26.0 (SQLite) for offline storage
- **Backend**: Firebase (Auth, Firestore)
- **Navigation**: Go Router 15.1.1
- **Data Models**: Freezed 3.0.6 for immutable classes
- **Error Handling**: result_dart 2.1.0

### Project Structure
```
lib/
├── core/
│   ├── database/          # Drift database + tables
│   └── logging/           # App-wide logging
├── features/
│   ├── auth/             # Authentication (Google Sign-In)
│   ├── expenses/         # Expense tracking (ACTIVE)
│   ├── groups/           # Group management (TODO)
│   ├── balances/         # Balance calculations (TODO)
│   ├── home/             # Main navigation
│   └── profile/          # User settings
└── shared/
    ├── routes/           # App routing
    └── theme/            # Material 3 theming
```

## Key Design Decisions

### 1. Offline-First
- Local SQLite database is the source of truth
- All operations work offline
- Changes queued for sync when online
- `isSynced` flag tracks sync status

### 2. Clean Architecture
- **Domain Layer**: Pure data entities, repository interfaces
- **Data Layer**: Repository implementations, Firebase services
- **Presentation Layer**: Screens, widgets, Riverpod providers

### 3. Single Responsibility Principle
- One class per file (strictly enforced)
- Files limited to 300-500 lines
- Helper classes for formatting/utilities
- See `.claude/coding-standards.md` for details

### 4. Type Safety
- Freezed for immutable data models
- Drift for type-safe database queries
- Result types for error handling
- Null-safety throughout

## Database Schema

### Tables
- **AppUsers**: User profiles (id, name, email, avatar)
- **AppGroups**: Groups for expense sharing
- **AppGroupMembers**: Many-to-many relationship
- **Expenses**: Individual expenses
- **ExpenseShares**: Who owes what for each expense
- **SyncQueue**: Tracks pending sync operations

## Development Workflow

### Making Changes
1. Follow coding standards in `.claude/coding-standards.md`
2. Use package imports, not relative imports
3. One class per file, max 300-500 lines
4. Run code generation: `dart run build_runner build --delete-conflicting-outputs`
5. Check for errors: `flutter analyze`
6. Test the change in the app

### Adding a New Feature
1. Create domain entities (pure data models with Freezed)
2. Define repository interface
3. Implement repository (local + Firebase)
4. Create Riverpod providers
5. Build UI (screens + widgets, one per file)
6. Update routing if needed

## Common Tasks

### Run the App
```bash
flutter run
```

### Generate Code
```bash
dart run build_runner build --delete-conflicting-outputs
```

### Analyze Code
```bash
flutter analyze
```

### Clean Build
```bash
flutter clean
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

## Important Files

- **PLAN.md**: Development roadmap and task breakdown
- **README.md**: Project overview and setup instructions
- **.claude/coding-standards.md**: Code quality requirements
- **lib/main.dart**: App entry point
- **lib/core/database/app_database.dart**: Database definition

## Next Steps

See **PLAN.md** for the current development plan. Current focus:
1. Complete Phase 2.1: Basic expense tracking ✅
2. Phase 2.2: Group creation (simple, local-only)
3. Phase 2.3: Balance calculations (simple sum)
4. Phase 2.4: Firebase sync (basic push/pull)

## Notes for AI Assistants

- **Always** check `.claude/coding-standards.md` before writing code
- **Never** put multiple classes in one file
- **Never** add extensions to Freezed classes in the same file
- **Always** use package imports
- **Remove** obvious/useless comments
- **Keep** files under 300-500 lines
- **Prefer** helper classes over extensions for utilities
- When in doubt, follow the patterns in existing code

## Contact & Resources

- **Git Repository**: (TBD)
- **Documentation**: See README.md and PLAN.md
- **Issue Tracker**: GitHub Issues (when set up)

---

This context should be maintained and updated as the project evolves.